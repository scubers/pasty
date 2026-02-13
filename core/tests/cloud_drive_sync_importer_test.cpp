#include "../src/application/history/clipboard_service.h"
#include "../src/infrastructure/settings/in_memory_settings_store.h"
#include "../src/infrastructure/sync/cloud_drive_sync_importer.h"
#include "../src/infrastructure/sync/cloud_drive_sync_exporter.h"
#include "../src/store/sqlite_clipboard_history_store.h"
#include "../src/thirdparty/nlohmann/json.hpp"

#include <cassert>
#include <cstdint>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <random>
#include <string>
#include <vector>

namespace {

void configureMigrationDirectoryForTests() {
    const std::filesystem::path current = std::filesystem::current_path();
    const std::vector<std::filesystem::path> candidates = {
        current / "../migrations",
        current / "core/migrations",
        current / "../core/migrations",
        current / "../../core/migrations",
        current / "../../../core/migrations",
    };

    for (const auto& candidate : candidates) {
        if (std::filesystem::exists(candidate / "0001-initial-schema.sql")) {
            pasty::setClipboardHistoryMigrationDirectory(std::filesystem::absolute(candidate).string());
            return;
        }
    }

    assert(false && "Could not locate migration directory for tests");
}

pasty::ClipboardService makeService(pasty::SettingsStore& settings) {
    return pasty::ClipboardService(pasty::createClipboardHistoryStore(), settings);
}

std::string createTempDirectory(const std::string& name) {
    std::error_code ec;
    auto baseTemp = std::filesystem::temp_directory_path() / "pasty-test";
    std::filesystem::create_directories(baseTemp, ec);
    auto tempDir = baseTemp / (name + "-" + std::to_string(std::random_device{}()));
    std::filesystem::create_directories(tempDir, ec);
    return tempDir.string();
}

void cleanupTempDirectory(const std::string& path) {
    std::error_code ec;
    std::filesystem::remove_all(std::filesystem::path(path), ec);
}

void writeJsonlFile(const std::string& path, const std::string& content) {
    std::ofstream file(path, std::ios::app);
    file << content << "\n";
    file.flush();
    file.close();
}

nlohmann::json makeBaseEvent(const std::string& deviceId,
                             std::uint64_t seq,
                             std::int64_t tsMs,
                             const std::string& op,
                             const std::string& itemType,
                             const std::string& contentHash) {
    nlohmann::json event;
    event["schema_version"] = 1;
    event["event_id"] = deviceId + ":" + std::to_string(seq);
    event["device_id"] = deviceId;
    event["seq"] = seq;
    event["ts_ms"] = tsMs;
    event["op"] = op;
    event["item_type"] = itemType;
    event["content_hash"] = contentHash;
    return event;
}

pasty::ClipboardHistoryItem makeTextItem(const std::string& content,
                                         const std::string& contentHash,
                                         const std::string& sourceAppId) {
    pasty::ClipboardHistoryItem item;
    item.type = pasty::ClipboardItemType::Text;
    item.content = content;
    item.contentHash = contentHash;
    item.sourceAppId = sourceAppId;
    return item;
}

void testDeterministicMerge() {
    std::cout << "Running testDeterministicMerge..." << std::endl;

    configureMigrationDirectoryForTests();
    const std::string tempDir = createTempDirectory("cloud-sync-import-order");
    const std::string syncRoot = tempDir + "/sync";
    const std::string baseDir = tempDir + "/base";
    std::filesystem::create_directories(syncRoot);
    std::filesystem::create_directories(baseDir);

    const std::string remoteA = "cccccccccccccccc";
    const std::string remoteB = "dddddddddddddddd";
    const std::string logsA = syncRoot + "/logs/" + remoteA;
    const std::string logsB = syncRoot + "/logs/" + remoteB;
    std::filesystem::create_directories(logsA);
    std::filesystem::create_directories(logsB);

    const std::int64_t ts = 1739414400000;
    const std::string samePayload = "deterministic-merge";

    auto cSeq2 = makeBaseEvent(remoteA, 2, ts, "upsert_text", "text", "aaaaaaaaaaaaaaaa");
    cSeq2["text"] = samePayload;

    auto cSeq1 = makeBaseEvent(remoteA, 1, ts, "upsert_text", "text", "aaaaaaaaaaaaaaaa");
    cSeq1["text"] = samePayload;

    auto dSeq1 = makeBaseEvent(remoteB, 1, ts, "upsert_text", "text", "aaaaaaaaaaaaaaaa");
    dSeq1["text"] = samePayload;

    writeJsonlFile(logsA + "/events-0001.jsonl", cSeq2.dump());
    writeJsonlFile(logsA + "/events-0001.jsonl", cSeq1.dump());
    writeJsonlFile(logsB + "/events-0001.jsonl", dSeq1.dump());

    pasty::InMemorySettingsStore settings(1000);
    auto service = makeService(settings);
    assert(service.initialize(baseDir + "/history"));

    auto importer = pasty::CloudDriveSyncImporter::Create(syncRoot, baseDir);
    assert(importer.has_value());

    const auto result = importer->importChanges(service);
    assert(result.success);
    assert(result.eventsProcessed == 3);
    assert(result.eventsApplied == 3);

    const auto items = service.list(10, "").items;
    assert(items.size() == 1);
    assert(items[0].content == samePayload);
    assert(items[0].sourceAppId == "pasty-sync:" + remoteB);

    service.shutdown();
    cleanupTempDirectory(tempDir);
}

void testForwardCompatibility() {
    std::cout << "Running testForwardCompatibility..." << std::endl;

    configureMigrationDirectoryForTests();
    const std::string tempDir = createTempDirectory("cloud-sync-import-forward-compat");
    const std::string syncRoot = tempDir + "/sync";
    const std::string baseDir = tempDir + "/base";
    std::filesystem::create_directories(syncRoot);
    std::filesystem::create_directories(baseDir);

    const std::string remote = "abababababababab";
    const std::string logs = syncRoot + "/logs/" + remote;
    std::filesystem::create_directories(logs);

    auto wrongSchema = makeBaseEvent(remote, 1, 1739414400001, "upsert_text", "text", "bbbbbbbbbbbbbbbb");
    wrongSchema["schema_version"] = 2;
    wrongSchema["text"] = "should-skip-schema";

    auto unknownOp = makeBaseEvent(remote, 2, 1739414400002, "future_op", "text", "cccccccccccccccc");
    unknownOp["text"] = "should-skip-op";

    auto validWithUnknownFields = makeBaseEvent(remote, 3, 1739414400003, "upsert_text", "text", "dddddddddddddddd");
    validWithUnknownFields["text"] = "forward-compatible";
    validWithUnknownFields["unknown_top_level"] = "ignored";
    validWithUnknownFields["unknown_object"] = nlohmann::json::object({{"nested", true}});

    writeJsonlFile(logs + "/events-0001.jsonl", wrongSchema.dump());
    writeJsonlFile(logs + "/events-0001.jsonl", unknownOp.dump());
    writeJsonlFile(logs + "/events-0001.jsonl", "{invalid-json-line");
    writeJsonlFile(logs + "/events-0001.jsonl", validWithUnknownFields.dump());

    pasty::InMemorySettingsStore settings(1000);
    auto service = makeService(settings);
    assert(service.initialize(baseDir + "/history"));

    auto importer = pasty::CloudDriveSyncImporter::Create(syncRoot, baseDir);
    assert(importer.has_value());

    const auto result = importer->importChanges(service);
    assert(result.success);
    assert(result.eventsProcessed == 1);
    assert(result.eventsApplied == 1);

    const auto items = service.list(10, "").items;
    assert(items.size() == 1);
    assert(items[0].content == "forward-compatible");

    service.shutdown();
    cleanupTempDirectory(tempDir);
}

void testEventIdIdempotency() {
    std::cout << "Running testEventIdIdempotency..." << std::endl;

    configureMigrationDirectoryForTests();
    const std::string tempDir = createTempDirectory("cloud-sync-import-event-id");
    const std::string syncRoot = tempDir + "/sync";
    const std::string baseDir = tempDir + "/base";
    std::filesystem::create_directories(syncRoot);
    std::filesystem::create_directories(baseDir);

    const std::string remote = "efefefefefefefef";
    const std::string logs = syncRoot + "/logs/" + remote;
    std::filesystem::create_directories(logs);

    auto event = makeBaseEvent(remote, 1, 1739414400100, "upsert_text", "text", "eeeeeeeeeeeeeeee");
    event["text"] = "idempotent-text";

    writeJsonlFile(logs + "/events-0001.jsonl", event.dump());
    writeJsonlFile(logs + "/events-0001.jsonl", event.dump());

    pasty::InMemorySettingsStore settings(1000);
    auto service = makeService(settings);
    assert(service.initialize(baseDir + "/history"));

    auto importer = pasty::CloudDriveSyncImporter::Create(syncRoot, baseDir);
    assert(importer.has_value());

    const auto firstImport = importer->importChanges(service);
    assert(firstImport.success);
    assert(firstImport.eventsProcessed == 2);

    const auto itemsAfterFirst = service.list(10, "").items;
    assert(itemsAfterFirst.size() == 1);
    assert(itemsAfterFirst[0].content == "idempotent-text");

    auto importerAgain = pasty::CloudDriveSyncImporter::Create(syncRoot, baseDir);
    assert(importerAgain.has_value());
    const auto secondImport = importerAgain->importChanges(service);
    assert(secondImport.success);
    assert(secondImport.eventsProcessed == 0);

    const auto itemsAfterSecond = service.list(10, "").items;
    assert(itemsAfterSecond.size() == 1);

    service.shutdown();
    cleanupTempDirectory(tempDir);
}

void testConcurrentDeviceWrite() {
    std::cout << "Running testConcurrentDeviceWrite..." << std::endl;

    configureMigrationDirectoryForTests();
    const std::string tempDir = createTempDirectory("cloud-sync-import-concurrent-devices");
    const std::string syncRoot = tempDir + "/sync";
    const std::string baseDir = tempDir + "/base";
    std::filesystem::create_directories(syncRoot);
    std::filesystem::create_directories(baseDir);

    const std::string olderDevice = "1111111111111111";
    const std::string newerDevice = "2222222222222222";
    const std::string olderLogs = syncRoot + "/logs/" + olderDevice;
    const std::string newerLogs = syncRoot + "/logs/" + newerDevice;
    std::filesystem::create_directories(olderLogs);
    std::filesystem::create_directories(newerLogs);

    auto older = makeBaseEvent(olderDevice, 1, 1739414401000, "upsert_text", "text", "abababababababab");
    older["text"] = "shared-content";

    auto newer = makeBaseEvent(newerDevice, 1, 1739414402000, "upsert_text", "text", "abababababababab");
    newer["text"] = "shared-content";

    writeJsonlFile(olderLogs + "/events-0001.jsonl", older.dump());
    writeJsonlFile(newerLogs + "/events-0001.jsonl", newer.dump());

    pasty::InMemorySettingsStore settings(1000);
    auto service = makeService(settings);
    assert(service.initialize(baseDir + "/history"));

    auto importer = pasty::CloudDriveSyncImporter::Create(syncRoot, baseDir);
    assert(importer.has_value());

    const auto result = importer->importChanges(service);
    assert(result.success);
    assert(result.eventsProcessed == 2);
    assert(result.eventsApplied == 2);

    const auto items = service.list(10, "").items;
    assert(items.size() == 1);
    assert(items[0].content == "shared-content");
    assert(items[0].sourceAppId == "pasty-sync:" + newerDevice);
    assert(items[0].lastCopyTimeMs == 1739414402000);

    service.shutdown();
    cleanupTempDirectory(tempDir);
}

void testConflictFileHandling() {
    std::cout << "Running testConflictFileHandling..." << std::endl;

    configureMigrationDirectoryForTests();
    const std::string tempDir = createTempDirectory("cloud-sync-import-conflict-file");
    const std::string syncRoot = tempDir + "/sync";
    const std::string baseDir = tempDir + "/base";
    std::filesystem::create_directories(syncRoot);
    std::filesystem::create_directories(baseDir);

    const std::string remote = "9999999999999999";
    const std::string logs = syncRoot + "/logs/" + remote;
    std::filesystem::create_directories(logs);

    auto validEvent = makeBaseEvent(remote, 1, 1739414403000, "upsert_text", "text", "cdcdcdcdcdcdcdcd");
    validEvent["text"] = "valid-event";
    writeJsonlFile(logs + "/events-0001.jsonl", validEvent.dump());

    auto conflictEvent = makeBaseEvent(remote, 2, 1739414403001, "upsert_text", "text", "efefefefefefefef");
    conflictEvent["text"] = "conflict-file-event";
    const std::string conflictFile = logs + "/events-0001 (conflicted copy 2026-02-13).jsonl";
    writeJsonlFile(conflictFile, conflictEvent.dump());

    pasty::InMemorySettingsStore settings(1000);
    auto service = makeService(settings);
    assert(service.initialize(baseDir + "/history"));

    auto importer = pasty::CloudDriveSyncImporter::Create(syncRoot, baseDir);
    assert(importer.has_value());

    const auto result = importer->importChanges(service);
    assert(result.success);
    assert(result.eventsProcessed == 1);
    assert(result.eventsApplied == 1);

    const auto items = service.list(10, "").items;
    assert(items.size() == 1);
    assert(items[0].content == "valid-event");

    service.shutdown();
    cleanupTempDirectory(tempDir);
}

void testEventIdPrefixValidation() {
    std::cout << "Running testEventIdPrefixValidation..." << std::endl;

    configureMigrationDirectoryForTests();
    const std::string tempDir = createTempDirectory("cloud-sync-import-prefix-val");
    const std::string syncRoot = tempDir + "/sync";
    const std::string baseDir = tempDir + "/base";
    std::filesystem::create_directories(syncRoot);
    std::filesystem::create_directories(baseDir);

    const std::string remote = "aaaaaaaaaaaaaaaa";
    const std::string logs = syncRoot + "/logs/" + remote;
    std::filesystem::create_directories(logs);

    auto badPrefixEvent = makeBaseEvent(remote, 1, 1739414405000, "upsert_text", "text", "1111111111111111");
    badPrefixEvent["event_id"] = "wrong-prefix:1";
    badPrefixEvent["text"] = "should-be-rejected";

    writeJsonlFile(logs + "/events-0001.jsonl", badPrefixEvent.dump());

    pasty::InMemorySettingsStore settings(1000);
    auto service = makeService(settings);
    assert(service.initialize(baseDir + "/history"));

    auto importer = pasty::CloudDriveSyncImporter::Create(syncRoot, baseDir);
    assert(importer.has_value());

    const auto result = importer->importChanges(service);
    assert(result.success);
    assert(result.eventsProcessed == 0);
    assert(result.eventsApplied == 0);

    const auto items = service.list(10, "").items;
    assert(items.empty());

    service.shutdown();
    cleanupTempDirectory(tempDir);
}

void testE2eeDeleteImport() {
    std::cout << "Running testE2eeDeleteImport..." << std::endl;

    configureMigrationDirectoryForTests();
    const std::string tempDir = createTempDirectory("cloud-sync-import-e2ee-delete");
    const std::string syncRoot = tempDir + "/sync";
    const std::string baseDirExp = tempDir + "/base-exp";
    const std::string baseDirImp = tempDir + "/base-imp";
    std::filesystem::create_directories(syncRoot);
    std::filesystem::create_directories(baseDirExp);
    std::filesystem::create_directories(baseDirImp);

    std::vector<std::uint8_t> keyBytes(32);
    std::random_device rd;
    std::mt19937 gen(rd());
    std::uniform_int_distribution<int> dist(0, 255);
    for (auto& b : keyBytes) b = static_cast<std::uint8_t>(dist(gen));

    pasty::EncryptionManager::Key e2eeKey;
    std::copy(keyBytes.begin(), keyBytes.end(), e2eeKey.data());
    const std::string keyId = "test-key-id";

    {
        auto exporter = pasty::CloudDriveSyncExporter::Create(syncRoot, baseDirExp, e2eeKey, keyId);
        assert(exporter.has_value());

        const auto item = makeTextItem("secret-content", "secrethash", "com.test.app");
        assert(exporter->exportTextItem(item) == pasty::CloudDriveSyncExporter::ExportResult::Success);
        assert(exporter->exportDeleteTombstone(pasty::ClipboardItemType::Text, "secrethash") == pasty::CloudDriveSyncExporter::ExportResult::Success);
    }

    pasty::InMemorySettingsStore settings(1000);
    auto service = makeService(settings);
    assert(service.initialize(baseDirImp + "/history"));

    auto importer = pasty::CloudDriveSyncImporter::Create(syncRoot, baseDirImp, e2eeKey, keyId);
    assert(importer.has_value());

    const auto result = importer->importChanges(service);
    assert(result.success);
    
    const auto items = service.list(10, "").items;
    assert(items.empty());

    service.shutdown();
    cleanupTempDirectory(tempDir);
}

void testAssetReadFailure() {
    std::cout << "Running testAssetReadFailure..." << std::endl;

    configureMigrationDirectoryForTests();
    const std::string tempDir = createTempDirectory("cloud-sync-import-missing-asset");
    const std::string syncRoot = tempDir + "/sync";
    const std::string baseDir = tempDir + "/base";
    std::filesystem::create_directories(syncRoot);
    std::filesystem::create_directories(baseDir);

    const std::string remote = "1234123412341234";
    const std::string logs = syncRoot + "/logs/" + remote;
    std::filesystem::create_directories(logs);

    auto missingAssetEvent = makeBaseEvent(remote, 1, 1739414404000, "upsert_image", "image", "1212121212121212");
    missingAssetEvent["asset_key"] = "missing-image.png";
    missingAssetEvent["width"] = 32;
    missingAssetEvent["height"] = 32;

    writeJsonlFile(logs + "/events-0001.jsonl", missingAssetEvent.dump());

    pasty::InMemorySettingsStore settings(1000);
    auto service = makeService(settings);
    assert(service.initialize(baseDir + "/history"));

    auto importer = pasty::CloudDriveSyncImporter::Create(syncRoot, baseDir);
    assert(importer.has_value());

    const auto result = importer->importChanges(service);
    assert(result.success);
    assert(result.eventsProcessed == 1);
    assert(result.eventsApplied == 0);
    assert(result.eventsSkipped == 1);

    const auto items = service.list(10, "").items;
    assert(items.empty());

    service.shutdown();
    cleanupTempDirectory(tempDir);
}

}

int main() {
    std::cout << "=== Cloud Drive Sync Importer Test Suite ===" << std::endl;

    try {
        testDeterministicMerge();
        testForwardCompatibility();
        testEventIdIdempotency();
        testConcurrentDeviceWrite();
        testConflictFileHandling();
        testAssetReadFailure();
        testEventIdPrefixValidation();
        testE2eeDeleteImport();
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
