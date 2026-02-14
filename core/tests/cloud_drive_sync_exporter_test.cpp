#include <infrastructure/sync/cloud_drive_sync_exporter.h>
#include <store/sqlite_clipboard_history_store.h>
#include <thirdparty/nlohmann/json.hpp>

#include <cassert>
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

std::filesystem::path getSingleDeviceLogsDir(const std::string& syncRoot) {
    const std::filesystem::path logsRoot = std::filesystem::path(syncRoot) / "logs";
    assert(std::filesystem::exists(logsRoot));

    for (const auto& entry : std::filesystem::directory_iterator(logsRoot)) {
        if (entry.is_directory()) {
            return entry.path();
        }
    }

    assert(false && "No device logs directory found");
    return {};
}

std::string readLastLine(const std::filesystem::path& filePath) {
    std::ifstream file(filePath);
    assert(file.is_open());

    std::string line;
    std::string last;
    while (std::getline(file, line)) {
        if (!line.empty()) {
            last = line;
        }
    }

    return last;
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

pasty::ClipboardHistoryItem makeImageItem(const std::string& contentHash,
                                          const std::string& sourceAppId,
                                          const std::string& format = "png") {
    pasty::ClipboardHistoryItem item;
    item.type = pasty::ClipboardItemType::Image;
    item.contentHash = contentHash;
    item.sourceAppId = sourceAppId;
    item.imageFormat = format;
    item.imageWidth = 32;
    item.imageHeight = 32;
    return item;
}

void testLoopPrevention() {
    std::cout << "Running testLoopPrevention..." << std::endl;

    configureMigrationDirectoryForTests();
    const std::string tempDir = createTempDirectory("cloud-sync-export-loop");
    const std::string syncRoot = tempDir + "/sync";
    const std::string baseDir = tempDir + "/base";

    auto exporter = pasty::CloudDriveSyncExporter::Create(syncRoot, baseDir);
    assert(exporter.has_value());

    // Cloud-synced items should not be re-exported (loop prevention via originType)
    const auto textItem = makeTextItem("hello", "hash-loop-text", "com.remote.app");
    const auto imageItem = makeImageItem("hash-loop-image", "com.remote.app");
    const_cast<pasty::ClipboardHistoryItem&>(textItem).originType = pasty::OriginType::CloudSync;
    const_cast<pasty::ClipboardHistoryItem&>(imageItem).originType = pasty::OriginType::CloudSync;
    const std::vector<std::uint8_t> imageBytes = {0x89, 0x50, 0x4E, 0x47, 0x01};

    const auto textResult = exporter->exportTextItem(textItem);
    const auto imageResult = exporter->exportImageItem(imageItem, imageBytes);

    assert(textResult == pasty::CloudDriveSyncExporter::ExportResult::SkippedNonLocalOrigin);
    assert(imageResult == pasty::CloudDriveSyncExporter::ExportResult::SkippedNonLocalOrigin);

    cleanupTempDirectory(tempDir);
}

void testExporterSizeCaps() {
    std::cout << "Running testExporterSizeCaps..." << std::endl;

    configureMigrationDirectoryForTests();
    const std::string tempDir = createTempDirectory("cloud-sync-export-size");
    const std::string syncRoot = tempDir + "/sync";
    const std::string baseDir = tempDir + "/base";

    auto exporter = pasty::CloudDriveSyncExporter::Create(syncRoot, baseDir);
    assert(exporter.has_value());

    const std::vector<std::uint8_t> oversizedImage(26214401U, 0x5A);
    const auto imageItem = makeImageItem("hash-large-image", "com.test.app");
    const auto imageResult = exporter->exportImageItem(imageItem, oversizedImage);
    assert(imageResult == pasty::CloudDriveSyncExporter::ExportResult::SkippedImageTooLarge);

    const std::string oversizedText(1048576U, 'a');
    const auto textItem = makeTextItem(oversizedText, "hash-large-event", "com.test.app");
    const auto textResult = exporter->exportTextItem(textItem);
    assert(textResult == pasty::CloudDriveSyncExporter::ExportResult::SkippedEventTooLarge);

    cleanupTempDirectory(tempDir);
}

void testLogFileRotation() {
    std::cout << "Running testLogFileRotation..." << std::endl;

    configureMigrationDirectoryForTests();
    const std::string tempDir = createTempDirectory("cloud-sync-export-rotate");
    const std::string syncRoot = tempDir + "/sync";
    const std::string baseDir = tempDir + "/base";

    auto exporter = pasty::CloudDriveSyncExporter::Create(syncRoot, baseDir);
    assert(exporter.has_value());

    const std::string largeText(900U * 1024U, 'r');
    for (int i = 0; i < 13; ++i) {
        const auto item = makeTextItem(largeText, "hash-rotate-" + std::to_string(i), "com.test.app");
        const auto result = exporter->exportTextItem(item);
        assert(result == pasty::CloudDriveSyncExporter::ExportResult::Success);
    }

    const std::filesystem::path deviceLogsDir = getSingleDeviceLogsDir(syncRoot);
    const std::filesystem::path log1 = deviceLogsDir / "events-0001.jsonl";
    const std::filesystem::path log2 = deviceLogsDir / "events-0002.jsonl";

    assert(std::filesystem::exists(log1));
    assert(std::filesystem::exists(log2));
    assert(std::filesystem::file_size(log1) > 0);
    assert(std::filesystem::file_size(log2) > 0);

    cleanupTempDirectory(tempDir);
}

void testAtomicWrite() {
    std::cout << "Running testAtomicWrite..." << std::endl;

    configureMigrationDirectoryForTests();
    const std::string tempDir = createTempDirectory("cloud-sync-export-atomic");
    const std::string syncRoot = tempDir + "/sync";
    const std::string baseDir = tempDir + "/base";

    auto exporter = pasty::CloudDriveSyncExporter::Create(syncRoot, baseDir);
    assert(exporter.has_value());

    const auto imageItem = makeImageItem("hash-atomic-image", "com.test.app", "PNG");
    const std::vector<std::uint8_t> imageBytes = {0x01, 0x02, 0x03, 0x04, 0x05};
    const auto result = exporter->exportImageItem(imageItem, imageBytes);
    assert(result == pasty::CloudDriveSyncExporter::ExportResult::Success);

    const std::filesystem::path assetsDir = std::filesystem::path(syncRoot) / "assets";
    const std::filesystem::path assetPath = assetsDir / "hash-atomic-image.png";
    const std::filesystem::path tempPath = assetsDir / "hash-atomic-image.png.tmp";

    assert(std::filesystem::exists(assetPath));
    assert(!std::filesystem::exists(tempPath));

    std::ifstream assetFile(assetPath, std::ios::binary);
    assert(assetFile.is_open());
    const std::vector<std::uint8_t> storedBytes((std::istreambuf_iterator<char>(assetFile)),
                                                std::istreambuf_iterator<char>());
    assert(storedBytes == imageBytes);

    cleanupTempDirectory(tempDir);
}

void testDeleteTombstoneExport() {
    std::cout << "Running testDeleteTombstoneExport..." << std::endl;

    configureMigrationDirectoryForTests();
    const std::string tempDir = createTempDirectory("cloud-sync-export-delete");
    const std::string syncRoot = tempDir + "/sync";
    const std::string baseDir = tempDir + "/base";

    auto exporter = pasty::CloudDriveSyncExporter::Create(syncRoot, baseDir);
    assert(exporter.has_value());

    const std::string contentHash = "deadbeefdeadbeef";
    const auto result = exporter->exportDeleteTombstone(pasty::ClipboardItemType::Image, contentHash);
    assert(result == pasty::CloudDriveSyncExporter::ExportResult::Success);

    const std::filesystem::path deviceLogsDir = getSingleDeviceLogsDir(syncRoot);
    const std::filesystem::path log1 = deviceLogsDir / "events-0001.jsonl";
    assert(std::filesystem::exists(log1));

    const std::string lastLine = readLastLine(log1);
    assert(!lastLine.empty());

    const nlohmann::json eventJson = nlohmann::json::parse(lastLine, nullptr, false);
    assert(!eventJson.is_discarded());
    assert(eventJson.value("op", std::string()) == "delete");
    assert(eventJson.value("item_type", std::string()) == "image");
    assert(eventJson.value("content_hash", std::string()) == contentHash);

    cleanupTempDirectory(tempDir);
}

void testE2eeDeleteExport() {
    std::cout << "Running testE2eeDeleteExport..." << std::endl;

    configureMigrationDirectoryForTests();
    const std::string tempDir = createTempDirectory("cloud-sync-export-e2ee-delete");
    const std::string syncRoot = tempDir + "/sync";
    const std::string baseDir = tempDir + "/base";

    std::vector<std::uint8_t> key(32);
    std::random_device rd;
    std::mt19937 gen(rd());
    std::uniform_int_distribution<int> dist(0, 255);
    for (auto& b : key) b = static_cast<std::uint8_t>(dist(gen));

    pasty::EncryptionManager::Key e2eeKey;
    std::copy(key.begin(), key.end(), e2eeKey.data());

    auto exporter = pasty::CloudDriveSyncExporter::Create(syncRoot, baseDir, e2eeKey, "test-key-id");
    assert(exporter.has_value());

    const std::string contentHash = "e2eedeletehash";
    const auto result = exporter->exportDeleteTombstone(pasty::ClipboardItemType::Text, contentHash);
    assert(result == pasty::CloudDriveSyncExporter::ExportResult::Success);

    const std::filesystem::path deviceLogsDir = getSingleDeviceLogsDir(syncRoot);
    const std::filesystem::path log1 = deviceLogsDir / "events-0001.jsonl";
    const std::string lastLine = readLastLine(log1);
    const nlohmann::json eventJson = nlohmann::json::parse(lastLine, nullptr, false);

    assert(eventJson.value("encryption", std::string()) == "e2ee");
    assert(eventJson.contains("key_id"));
    assert(eventJson.contains("nonce"));
    assert(eventJson.contains("ciphertext"));
    assert(!eventJson.contains("item_type"));
    assert(!eventJson.contains("content_hash"));

    cleanupTempDirectory(tempDir);
}

void testDeviceIdConflictDetection() {
    std::cout << "Running testDeviceIdConflictDetection..." << std::endl;

    configureMigrationDirectoryForTests();
    const std::string tempDir = createTempDirectory("cloud-sync-export-device-conflict");
    const std::string syncRoot = tempDir + "/sync";
    const std::string baseDir = tempDir + "/base";
    std::filesystem::create_directories(syncRoot);
    std::filesystem::create_directories(baseDir);

    std::string deviceA;
    {
        auto state = pasty::CloudDriveSyncState::LoadOrCreate(baseDir);
        deviceA = state->deviceId();
    }

    const std::string logsA = syncRoot + "/logs/" + deviceA;
    std::filesystem::create_directories(logsA);

    const std::string deviceB = "bbbbbbbbbbbbbbbb";
    nlohmann::json event;
    event["schema_version"] = 1;
    event["event_id"] = deviceB + ":1";
    event["device_id"] = deviceB;
    event["seq"] = 1;
    event["ts_ms"] = 1739414406000;
    event["op"] = "upsert_text";
    event["item_type"] = "text";
    event["content_hash"] = "hash-b";
    event["text"] = "stolen-log-dir";

    {
        std::ofstream file(logsA + "/events-0001.jsonl");
        file << event.dump() << "\n";
    }

    auto exporter = pasty::CloudDriveSyncExporter::Create(syncRoot, baseDir);
    assert(exporter.has_value());

    auto item = makeTextItem("new-device-content", "newhash", "com.test.app");
    assert(exporter->exportTextItem(item) == pasty::CloudDriveSyncExporter::ExportResult::Success);

    const std::filesystem::path logsRoot = std::filesystem::path(syncRoot) / "logs";
    int dirCount = 0;
    std::string finalDeviceId;
    for (const auto& entry : std::filesystem::directory_iterator(logsRoot)) {
        if (entry.is_directory()) {
            dirCount++;
            if (entry.path().filename().string() != deviceA) {
                finalDeviceId = entry.path().filename().string();
            }
        }
    }

    assert(dirCount >= 2);
    assert(!finalDeviceId.empty());
    assert(finalDeviceId != deviceA);
    assert(finalDeviceId != deviceB);

    cleanupTempDirectory(tempDir);
}

void testIncludeSourceAppIdDisabled() {
    std::cout << "Running testIncludeSourceAppIdDisabled..." << std::endl;

    configureMigrationDirectoryForTests();
    const std::string tempDir = createTempDirectory("cloud-sync-export-source-app-id");
    const std::string syncRoot = tempDir + "/sync";
    const std::string baseDir = tempDir + "/base";

    auto exporter = pasty::CloudDriveSyncExporter::Create(syncRoot, baseDir);
    assert(exporter.has_value());

    exporter->setIncludeSourceAppId(false);

    const auto textItem = makeTextItem("hello world", "hash-source-app-text", "com.test.app");
    const auto textResult = exporter->exportTextItem(textItem);
    assert(textResult == pasty::CloudDriveSyncExporter::ExportResult::Success);

    const auto imageItem = makeImageItem("hash-source-app-image", "com.test.app");
    const std::vector<std::uint8_t> imageBytes = {0x89, 0x50, 0x4E, 0x47, 0x01};
    const auto imageResult = exporter->exportImageItem(imageItem, imageBytes);
    assert(imageResult == pasty::CloudDriveSyncExporter::ExportResult::Success);

    const std::filesystem::path deviceLogsDir = getSingleDeviceLogsDir(syncRoot);
    const std::filesystem::path log1 = deviceLogsDir / "events-0001.jsonl";
    assert(std::filesystem::exists(log1));

    std::ifstream file(log1);
    std::string line;
    while (std::getline(file, line)) {
        if (!line.empty()) {
            const nlohmann::json eventJson = nlohmann::json::parse(line, nullptr, false);
            assert(!eventJson.is_discarded());
            assert(eventJson.value("source_app_id", std::string("__MISSING__")) == "");
        }
    }

    cleanupTempDirectory(tempDir);
}

}

int main() {
    std::cout << "=== Cloud Drive Sync Exporter Test Suite ===" << std::endl;

    try {
        testLoopPrevention();
        testExporterSizeCaps();
        testLogFileRotation();
        testAtomicWrite();
        testDeleteTombstoneExport();
        testE2eeDeleteExport();
        testDeviceIdConflictDetection();
        testIncludeSourceAppIdDisabled();
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
