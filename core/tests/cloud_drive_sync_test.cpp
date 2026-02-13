#include <application/history/clipboard_service.h>
#include <history/clipboard_history_store.h>
#include <infrastructure/settings/in_memory_settings_store.h>
#include <infrastructure/sync/cloud_drive_sync_exporter.h>
#include <infrastructure/sync/cloud_drive_sync_importer.h>
#include <runtime/core_runtime.h>
#include <store/sqlite_clipboard_history_store.h>
#include <thirdparty/nlohmann/json.hpp>

#include <cassert>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <random>
#include <string>

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

void testTombstoneAntiResurrection() {
    std::cout << "Running testTombstoneAntiResurrection..." << std::endl;

    configureMigrationDirectoryForTests();
    const std::string tempDir = createTempDirectory("cloud-sync-tombstone");
    std::string syncRoot = tempDir + "/sync";
    std::string baseDir = tempDir + "/base";
    std::filesystem::create_directories(syncRoot);
    std::filesystem::create_directories(baseDir);

    const std::string localDeviceId = "1111111111111111";
    const std::string remoteDeviceId = "cccccccccccccccc";

    // 1. Create local sync_state.json with deterministic local device_id
    {
        std::ofstream stateFile(baseDir + "/sync_state.json");
        stateFile << R"({"schema_version": 1, "device_id": ")" << localDeviceId << R"(", "next_seq": 1, "devices": {}, "files": {}, "tombstones": []})" << std::endl;
    }

    // 2. Initialize ClipboardService
    pasty::InMemorySettingsStore settings(1000);
    auto service = makeService(settings);
    assert(service.initialize(baseDir + "/history"));

    // 3. Ingest local text to get actual content hash
    pasty::ClipboardHistoryIngestEvent ingest;
    ingest.itemType = pasty::ClipboardItemType::Text;
    ingest.text = "Hello world";
    ingest.sourceAppId = "test";
    ingest.timestampMs = 500;
    auto ingestResult = service.ingestWithResult(ingest);
    assert(ingestResult.ok);

    // 4. Get actual content hash
    auto localItems = service.list(10, "").items;
    assert(localItems.size() == 1);
    std::string contentHash = localItems[0].contentHash;
    assert(!contentHash.empty());

    // 5. Set up remote device logs directory
    const std::string remoteLogsDir = syncRoot + "/logs/" + remoteDeviceId;
    std::filesystem::create_directories(remoteLogsDir);

    // 6. PASS 1: Import upsert then delete events
    // Event 1: Upsert text at t=1000 (will fail if hash doesn't match)
    std::string upsertEvent1 = R"({"schema_version": 1, "event_id": "cccccccccccccccc:1", "device_id": "cccccccccccccccc", "seq": 1, "ts_ms": 1000, "op": "upsert_text", "item_type": "text", "content_hash": ")" + contentHash + R"(", "text": "Hello world", "content_type": "text/plain"})";
    // Event 2: Delete text at t=2000
    std::string deleteEvent = R"({"schema_version": 1, "event_id": "cccccccccccccccc:2", "device_id": "cccccccccccccccc", "seq": 2, "ts_ms": 2000, "op": "delete", "item_type": "text", "content_hash": ")" + contentHash + R"("})";

    writeJsonlFile(remoteLogsDir + "/events-0001.jsonl", upsertEvent1);
    writeJsonlFile(remoteLogsDir + "/events-0001.jsonl", deleteEvent);

    // 7. Run importer once (PASS 1)
    auto importer = pasty::CloudDriveSyncImporter::Create(syncRoot, baseDir);
    assert(importer.has_value());

    auto result1 = importer->importChanges(service);
    assert(result1.success);
    std::cout << "  PASS 1: eventsApplied=" << result1.eventsApplied << ", eventsSkipped=" << result1.eventsSkipped << ", eventsProcessed=" << result1.eventsProcessed << std::endl;

    // 8. Verify item list is empty (deleted)
    auto itemsAfterPass1 = service.list(10, "").items;
    assert(itemsAfterPass1.empty());

    // 9. Verify tombstone was persisted in sync_state.json
    {
        std::ifstream stateFile(baseDir + "/sync_state.json");
        std::string stateContent((std::istreambuf_iterator<char>(stateFile)), std::istreambuf_iterator<char>());
        assert(stateContent.find("\"tombstones\"") != std::string::npos);
        assert(stateContent.find("\"content_hash\"") != std::string::npos);
    }

    // 10. PASS 2: Present an older upsert (t=500) for same key
    std::string olderUpsertEvent = R"({"schema_version": 1, "event_id": "cccccccccccccccc:3", "device_id": "cccccccccccccccc", "seq": 3, "ts_ms": 500, "op": "upsert_text", "item_type": "text", "content_hash": ")" + contentHash + R"(", "text": "Hello world", "content_type": "text/plain"})";

    writeJsonlFile(remoteLogsDir + "/events-0001.jsonl", olderUpsertEvent);

    // 11. Run importer again (PASS 2)
    auto importer2 = pasty::CloudDriveSyncImporter::Create(syncRoot, baseDir);
    assert(importer2.has_value());

    auto result2 = importer2->importChanges(service);
    assert(result2.success);
    std::cout << "  PASS 2: eventsApplied=" << result2.eventsApplied << ", eventsSkipped=" << result2.eventsSkipped << ", eventsProcessed=" << result2.eventsProcessed << std::endl;
    assert(result2.eventsProcessed == 1);
    assert(result2.eventsApplied == 0);
    assert(result2.eventsSkipped == 1);

    // 12. Verify item list is STILL empty (no resurrection)
    auto itemsAfterPass2 = service.list(10, "").items;
    assert(itemsAfterPass2.empty());

    service.shutdown();
    cleanupTempDirectory(tempDir);
}

void testE2eeTextRoundTrip() {
    std::cout << "Running testE2eeTextRoundTrip..." << std::endl;

    configureMigrationDirectoryForTests();
    const std::string tempDir = createTempDirectory("cloud-sync-e2ee-text");
    const std::string syncRoot = tempDir + "/sync";
    const std::string senderBase = tempDir + "/sender";
    const std::string receiverBase = tempDir + "/receiver";
    std::filesystem::create_directories(syncRoot);
    std::filesystem::create_directories(senderBase);
    std::filesystem::create_directories(receiverBase);

    const std::string passphrase = "correct horse battery staple";
    const std::string secretText = "Top secret text payload";

    pasty::CoreRuntimeConfig senderConfig;
    senderConfig.storageDirectory = senderBase;
    senderConfig.cloudSyncEnabled = true;
    senderConfig.cloudSyncRootPath = syncRoot;

    pasty::CoreRuntime senderRuntime(senderConfig);
    assert(senderRuntime.start());
    assert(senderRuntime.initializeCloudSyncE2ee(passphrase));

    pasty::ClipboardHistoryIngestEvent ingestEvent;
    ingestEvent.timestampMs = 1000;
    ingestEvent.sourceAppId = "com.test.sender";
    ingestEvent.itemType = pasty::ClipboardItemType::Text;
    ingestEvent.text = secretText;

    auto ingestResult = senderRuntime.clipboardService()->ingestWithResult(ingestEvent);
    assert(ingestResult.ok);
    assert(senderRuntime.exportLocalTextIngest(ingestEvent, ingestResult.inserted));
    senderRuntime.stop();

    const std::filesystem::path logsRoot(syncRoot + "/logs");
    assert(std::filesystem::exists(logsRoot));

    std::filesystem::path eventFilePath;
    for (const auto& deviceDir : std::filesystem::directory_iterator(logsRoot)) {
        if (!deviceDir.is_directory()) {
            continue;
        }
        for (const auto& entry : std::filesystem::directory_iterator(deviceDir.path())) {
            if (entry.is_regular_file() && entry.path().extension() == ".jsonl") {
                eventFilePath = entry.path();
                break;
            }
        }
        if (!eventFilePath.empty()) {
            break;
        }
    }
    assert(!eventFilePath.empty());

    std::ifstream eventFile(eventFilePath);
    assert(eventFile.is_open());
    std::string eventLine;
    std::getline(eventFile, eventLine);
    assert(!eventLine.empty());
    assert(eventLine.find(secretText) == std::string::npos);

    nlohmann::json eventJson = nlohmann::json::parse(eventLine, nullptr, false);
    assert(!eventJson.is_discarded());
    assert(eventJson.value("encryption", std::string()) == "e2ee");
    assert(eventJson.contains("key_id"));
    assert(eventJson.contains("nonce"));
    assert(eventJson.contains("ciphertext"));
    assert(!eventJson.contains("text"));

    pasty::CoreRuntimeConfig receiverConfig;
    receiverConfig.storageDirectory = receiverBase;
    receiverConfig.cloudSyncEnabled = true;
    receiverConfig.cloudSyncRootPath = syncRoot;

    pasty::CoreRuntime receiverRuntime(receiverConfig);
    assert(receiverRuntime.start());
    assert(receiverRuntime.initializeCloudSyncE2ee(passphrase));
    assert(receiverRuntime.runCloudSyncImport());

    auto importedItems = receiverRuntime.clipboardService()->list(10, "").items;
    assert(!importedItems.empty());
    assert(importedItems[0].type == pasty::ClipboardItemType::Text);
    assert(importedItems[0].content == secretText);

    receiverRuntime.stop();
    cleanupTempDirectory(tempDir);
}

void testE2eeImageRoundTrip() {
    std::cout << "Running testE2eeImageRoundTrip..." << std::endl;

    configureMigrationDirectoryForTests();
    const std::string tempDir = createTempDirectory("cloud-sync-e2ee-image");
    const std::string syncRoot = tempDir + "/sync";
    const std::string senderBase = tempDir + "/sender";
    const std::string receiverBase = tempDir + "/receiver";
    std::filesystem::create_directories(syncRoot);
    std::filesystem::create_directories(senderBase);
    std::filesystem::create_directories(receiverBase);

    const std::string passphrase = "correct horse battery staple";
    const std::vector<std::uint8_t> originalImageBytes = {
        0x89, 0x50, 0x4E, 0x47, 0x42, 0x59, 0x54, 0x45, 0x53, 0x01, 0x02, 0x03, 0x04
    };

    pasty::CoreRuntimeConfig senderConfig;
    senderConfig.storageDirectory = senderBase;
    senderConfig.cloudSyncEnabled = true;
    senderConfig.cloudSyncRootPath = syncRoot;

    pasty::CoreRuntime senderRuntime(senderConfig);
    assert(senderRuntime.start());
    assert(senderRuntime.initializeCloudSyncE2ee(passphrase));

    pasty::ClipboardHistoryIngestEvent ingestEvent;
    ingestEvent.timestampMs = 1000;
    ingestEvent.sourceAppId = "com.test.sender";
    ingestEvent.itemType = pasty::ClipboardItemType::Image;
    ingestEvent.image.bytes = originalImageBytes;
    ingestEvent.image.width = 2;
    ingestEvent.image.height = 2;
    ingestEvent.image.formatHint = "png";

    auto ingestResult = senderRuntime.clipboardService()->ingestWithResult(ingestEvent);
    assert(ingestResult.ok);
    assert(senderRuntime.exportLocalImageIngest(ingestEvent, ingestResult.inserted));
    senderRuntime.stop();

    const std::filesystem::path logsRoot(syncRoot + "/logs");
    assert(std::filesystem::exists(logsRoot));

    std::filesystem::path eventFilePath;
    for (const auto& deviceDir : std::filesystem::directory_iterator(logsRoot)) {
        if (!deviceDir.is_directory()) {
            continue;
        }
        for (const auto& entry : std::filesystem::directory_iterator(deviceDir.path())) {
            if (entry.is_regular_file() && entry.path().extension() == ".jsonl") {
                eventFilePath = entry.path();
                break;
            }
        }
        if (!eventFilePath.empty()) {
            break;
        }
    }
    assert(!eventFilePath.empty());

    std::ifstream eventFile(eventFilePath);
    assert(eventFile.is_open());
    std::string eventLine;
    std::getline(eventFile, eventLine);
    assert(!eventLine.empty());

    nlohmann::json eventJson = nlohmann::json::parse(eventLine, nullptr, false);
    assert(!eventJson.is_discarded());
    assert(eventJson.value("op", std::string()) == "upsert_image");
    assert(eventJson.value("encryption", std::string()) == "e2ee");
    assert(eventJson.contains("key_id"));
    assert(eventJson.contains("nonce"));
    assert(eventJson.contains("asset_key"));

    const std::string assetKey = eventJson["asset_key"].get<std::string>();
    const std::filesystem::path assetPath = std::filesystem::path(syncRoot) / "assets" / assetKey;
    assert(std::filesystem::exists(assetPath));

    std::ifstream assetFile(assetPath, std::ios::binary);
    assert(assetFile.is_open());
    const std::vector<std::uint8_t> assetBytes((std::istreambuf_iterator<char>(assetFile)), std::istreambuf_iterator<char>());
    assert(!assetBytes.empty());
    assert(assetBytes != originalImageBytes);

    pasty::CoreRuntimeConfig receiverConfig;
    receiverConfig.storageDirectory = receiverBase;
    receiverConfig.cloudSyncEnabled = true;
    receiverConfig.cloudSyncRootPath = syncRoot;

    pasty::CoreRuntime receiverRuntime(receiverConfig);
    assert(receiverRuntime.start());
    assert(receiverRuntime.initializeCloudSyncE2ee(passphrase));
    assert(receiverRuntime.runCloudSyncImport());

    auto importedItems = receiverRuntime.clipboardService()->list(10, "").items;
    assert(!importedItems.empty());
    assert(importedItems[0].type == pasty::ClipboardItemType::Image);
    assert(importedItems[0].contentHash == eventJson.value("content_hash", std::string()));

    receiverRuntime.stop();
    cleanupTempDirectory(tempDir);
}

}

int main() {
    std::cout << "=== Cloud Drive Sync Test Suite ===" << std::endl;

    try {
        testTombstoneAntiResurrection();
        testE2eeTextRoundTrip();
        testE2eeImageRoundTrip();
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
