#include <infrastructure/sync/cloud_drive_sync_state.h>
#include <thirdparty/nlohmann/json.hpp>

#include <cassert>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <random>
#include <string>

namespace {

std::string createTempDirectory(const std::string& name) {
    std::error_code ec;
    const auto baseTemp = std::filesystem::temp_directory_path() / "pasty-test";
    std::filesystem::create_directories(baseTemp, ec);
    const auto tempDir = baseTemp / (name + "-" + std::to_string(std::random_device{}()));
    std::filesystem::create_directories(tempDir, ec);
    return tempDir.string();
}

void cleanupTempDirectory(const std::string& path) {
    std::error_code ec;
    std::filesystem::remove_all(std::filesystem::path(path), ec);
}

void testStatePersistence() {
    std::cout << "Running testStatePersistence..." << std::endl;

    const std::string tempDir = createTempDirectory("cloud-sync-state-persistence");
    const std::string baseDir = tempDir + "/base";
    std::filesystem::create_directories(baseDir);
    const std::string statePath = baseDir + "/sync_state.json";

    auto state = pasty::CloudDriveSyncState::LoadOrCreate(baseDir);
    assert(state.has_value());

    const std::string initialDeviceId = state->deviceId();
    const std::uint64_t initialNextSeq = state->nextSeq();
    const std::uint64_t reservedSeq = state->reserveNextSeq();
    assert(reservedSeq == initialNextSeq);

    assert(state->updateRemoteDeviceMaxSeq("remote-a", 42));

    const std::string cursorFile = std::filesystem::absolute(baseDir + "/events-0001.jsonl").string();
    assert(state->updateFileCursor(cursorFile, 1024));
    const int errorCount = state->incrementFileErrorCount(cursorFile);
    assert(errorCount == 1);

    auto reloaded = pasty::CloudDriveSyncState::LoadOrCreate(baseDir);
    assert(reloaded.has_value());
    assert(reloaded->deviceId() == initialDeviceId);
    assert(reloaded->nextSeq() == initialNextSeq + 1);

    const auto remoteState = reloaded->getRemoteDeviceState("remote-a");
    assert(remoteState.max_applied_seq == 42);

    const auto cursor = reloaded->getFileCursor(cursorFile);
    assert(cursor.last_offset == 1024);
    assert(cursor.error_count == 1);

    std::ifstream stateFile(statePath);
    assert(stateFile.is_open());
    nlohmann::json stateJson = nlohmann::json::parse(stateFile, nullptr, false);
    assert(!stateJson.is_discarded());
    assert(stateJson.value("device_id", std::string()) == initialDeviceId);
    assert(stateJson.value("next_seq", std::uint64_t(0)) == initialNextSeq + 1);
    assert(stateJson["devices"]["remote-a"].value("max_applied_seq", std::uint64_t(0)) == 42);
    assert(stateJson["files"][cursorFile].value("last_offset", std::uint64_t(0)) == 1024);
    assert(stateJson["files"][cursorFile].value("error_count", 0) == 1);

    cleanupTempDirectory(tempDir);
}

void testStateCorruptionRecovery() {
    std::cout << "Running testStateCorruptionRecovery..." << std::endl;

    const std::string tempDir = createTempDirectory("cloud-sync-state-corruption");
    const std::string baseDir = tempDir + "/base";
    std::filesystem::create_directories(baseDir);
    const std::string statePath = baseDir + "/sync_state.json";

    auto initial = pasty::CloudDriveSyncState::LoadOrCreate(baseDir);
    assert(initial.has_value());
    const std::string oldDeviceId = initial->deviceId();

    {
        std::ofstream corrupted(statePath, std::ios::trunc);
        assert(corrupted.is_open());
        corrupted << "{ invalid-json";
    }

    auto recovered = pasty::CloudDriveSyncState::LoadOrCreate(baseDir);
    assert(recovered.has_value());
    assert(!recovered->deviceId().empty());
    assert(recovered->deviceId() != oldDeviceId);

    bool backupFound = false;
    const std::string backupPrefix = "sync_state.json.corrupted.";
    for (const auto& entry : std::filesystem::directory_iterator(baseDir)) {
        if (!entry.is_regular_file()) {
            continue;
        }
        const std::string name = entry.path().filename().string();
        if (name.rfind(backupPrefix, 0) == 0) {
            backupFound = true;
            break;
        }
    }
    assert(backupFound);

    std::ifstream newStateFile(statePath);
    assert(newStateFile.is_open());
    nlohmann::json newStateJson = nlohmann::json::parse(newStateFile, nullptr, false);
    assert(!newStateJson.is_discarded());
    assert(newStateJson.value("device_id", std::string()) == recovered->deviceId());

    cleanupTempDirectory(tempDir);
}

void testTombstoneGc() {
    std::cout << "Running testTombstoneGc..." << std::endl;

    const std::string tempDir = createTempDirectory("cloud-sync-state-tombstone-gc");
    const std::string baseDir = tempDir + "/base";
    std::filesystem::create_directories(baseDir);
    const std::string statePath = baseDir + "/sync_state.json";

    auto state = pasty::CloudDriveSyncState::LoadOrCreate(baseDir);
    assert(state.has_value());

    const std::int64_t nowMs = 10'000;
    const std::int64_t retentionMs = 1'000;
    const std::int64_t expiredTs = nowMs - retentionMs - 1;
    const std::int64_t keptTsA = nowMs - 10;
    const std::int64_t keptTsB = nowMs - 20;

    assert(state->recordTombstone("text", "old-old-old-old", expiredTs));
    assert(state->recordTombstone("text", "keep-aaa-aaa-1", keptTsA));
    assert(state->recordTombstone("image", "keep-bbb-bbb-2", keptTsB));

    const bool pruned = state->pruneForGc(nowMs, retentionMs, 100);
    assert(pruned);

    assert(!state->shouldSkipUpsertDueToTombstone("text", "old-old-old-old", expiredTs));
    assert(state->shouldSkipUpsertDueToTombstone("text", "keep-aaa-aaa-1", keptTsA));
    assert(state->shouldSkipUpsertDueToTombstone("image", "keep-bbb-bbb-2", keptTsB));

    std::ifstream stateFile(statePath);
    assert(stateFile.is_open());
    nlohmann::json stateJson = nlohmann::json::parse(stateFile, nullptr, false);
    assert(!stateJson.is_discarded());
    assert(stateJson.contains("tombstones"));
    assert(stateJson["tombstones"].is_array());
    assert(stateJson["tombstones"].size() == 2);

    bool foundKeepA = false;
    bool foundKeepB = false;
    for (const auto& tombstone : stateJson["tombstones"]) {
        const std::string hash = tombstone.value("content_hash", std::string());
        if (hash == "keep-aaa-aaa-1") {
            foundKeepA = true;
        }
        if (hash == "keep-bbb-bbb-2") {
            foundKeepB = true;
        }
        assert(hash != "old-old-old-old");
    }
    assert(foundKeepA);
    assert(foundKeepB);

    cleanupTempDirectory(tempDir);
}

}

int main() {
    std::cout << "=== Cloud Drive Sync State Test Suite ===" << std::endl;

    try {
        testStatePersistence();
        testStateCorruptionRecovery();
        testTombstoneGc();
        std::cout << "=== All tests PASSED ===" << std::endl;
        return 0;
    } catch (const std::exception& e) {
        std::cerr << "Test failed with exception: " << e.what() << std::endl;
        return 1;
    } catch (...) {
        std::cerr << "Test failed with unknown exception" << std::endl;
        return 1;
    }
}
