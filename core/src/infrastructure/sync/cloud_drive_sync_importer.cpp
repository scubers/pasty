// Pasty - Copyright (c) 2026. MIT License.

#include "infrastructure/sync/cloud_drive_sync_importer.h"
#include "application/history/clipboard_service.h"
#include <common/logger.h>

#include <algorithm>
#include <cctype>
#include <fstream>
#include <filesystem>
#include <sstream>
#include <utility>
#include <map>
#include <set>

#include <nlohmann/json.hpp>

namespace pasty {

namespace {

constexpr int kSchemaVersion = 1;
constexpr const char* kLoopPrefix = "pasty-sync:";
constexpr std::uint64_t kMaxAssetBytes = 26214400;

// Tombstone key for anti-resurrection
struct TombstoneKey {
    ClipboardItemType type;
    std::string contentHash;
    
    bool operator<(const TombstoneKey& other) const {
        if (type != other.type) return type < other.type;
        return contentHash < other.contentHash;
    }
};

bool validateContentHash(const std::string& hash) {
    if (hash.size() != 16) {
        return false;
    }
    for (char c : hash) {
        if (!((c >= '0' && c <= '9') || (c >= 'a' && c <= 'f'))) {
            return false;
        }
    }
    return true;
}

std::string extractExtensionFromAssetKey(const std::string& assetKey) {
    const std::size_t lastDot = assetKey.rfind('.');
    if (lastDot == std::string::npos || lastDot == assetKey.size() - 1) {
        return std::string("png");
    }
    std::string ext = assetKey.substr(lastDot + 1);
    
    if (ext == "jpg" || ext == "jpeg") {
        return std::string("jpeg");
    }
    return ext;
}

} // namespace

CloudDriveSyncImporter::CloudDriveSyncImporter()
    : m_initialized(false) {
}

std::optional<CloudDriveSyncImporter> CloudDriveSyncImporter::Create(const std::string& syncRootPath, const std::string& baseDirectory) {
    CloudDriveSyncImporter importer;
    if (!importer.initialize(syncRootPath, baseDirectory)) {
        return std::nullopt;
    }
    return std::make_optional<CloudDriveSyncImporter>(std::move(importer));
}

bool CloudDriveSyncImporter::initialize(const std::string& syncRootPath, const std::string& baseDirectory) {
    m_syncRootPath = syncRootPath;
    m_logsPath = syncRootPath + "/logs";
    m_assetsPath = syncRootPath + "/assets";

    auto state = CloudDriveSyncState::LoadOrCreate(baseDirectory);
    if (!state) {
        PASTY_LOG_ERROR("Core.SyncImporter", "Failed to load or create sync state from: %s", baseDirectory.c_str());
        return false;
    }

    m_stateManager = std::make_unique<StateManager>(std::move(*state));
    m_initialized = true;

    PASTY_LOG_INFO("Core.SyncImporter", "Importer initialized. Local device: %s, sync_root: %s",
                   m_stateManager->deviceId().c_str(), m_syncRootPath.c_str());
    return true;
}

bool CloudDriveSyncImporter::isConfigured() const {
    return m_initialized && m_stateManager && m_stateManager->state.has_value();
}

CloudDriveSyncImporter::ImportResult CloudDriveSyncImporter::importChanges(ClipboardService& clipboardService) {
    ImportResult result;

    if (!isConfigured()) {
        PASTY_LOG_ERROR("Core.SyncImporter", "Cannot import: importer not configured");
        return result;
    }

    const std::string localDeviceId = m_stateManager->deviceId();
    if (localDeviceId.empty()) {
        PASTY_LOG_ERROR("Core.SyncImporter", "Cannot import: local device ID is empty");
        return result;
    }

    std::vector<std::string> remoteDeviceDirs = enumerateRemoteDeviceLogDirectories();
    PASTY_LOG_INFO("Core.SyncImporter", "Found %zu remote device directories", remoteDeviceDirs.size());

    std::vector<ParsedEvent> allEvents;
    for (const auto& remoteDeviceDir : remoteDeviceDirs) {
        const std::string remoteDeviceId = std::filesystem::path(remoteDeviceDir).filename().string();
        
        CloudDriveSyncState::RemoteDeviceState deviceState = m_stateManager->getRemoteDeviceState(remoteDeviceId);
        PASTY_LOG_DEBUG("Core.SyncImporter", "Processing remote device: %s, max_applied_seq: %lu",
                        remoteDeviceId.c_str(), static_cast<unsigned long>(deviceState.max_applied_seq));

        std::vector<std::string> jsonlFiles = enumerateJsonlFiles(remoteDeviceDir);
        
        for (const auto& filePath : jsonlFiles) {
            if (!parseJsonlFile(filePath, remoteDeviceId, allEvents)) {
                PASTY_LOG_WARN("Core.SyncImporter", "Failed to parse file: %s", filePath.c_str());
            }
        }
    }

    result.eventsProcessed = static_cast<int>(allEvents.size());
    
    if (allEvents.empty()) {
        PASTY_LOG_INFO("Core.SyncImporter", "No new events to import");
        result.success = true;
        return result;
    }

    std::sort(allEvents.begin(), allEvents.end());
    
    PASTY_LOG_INFO("Core.SyncImporter", "Applying %zu events in deterministic order", allEvents.size());
    result = applyEvents(allEvents, clipboardService);

    return result;
}

std::vector<std::string> CloudDriveSyncImporter::enumerateRemoteDeviceLogDirectories() const {
    std::vector<std::string> directories;

    std::error_code ec;
    if (!std::filesystem::exists(m_logsPath, ec) || ec) {
        return directories;
    }

    const std::string localDeviceId = m_stateManager->deviceId();

    for (const auto& entry : std::filesystem::directory_iterator(m_logsPath, ec)) {
        if (ec) {
            break;
        }

        if (entry.is_directory(ec) && !ec) {
            const std::string deviceDir = entry.path().string();
            const std::string deviceId = entry.path().filename().string();
            
            if (deviceId != localDeviceId) {
                directories.push_back(deviceDir);
            }
        }
    }

    return directories;
}

std::vector<std::string> CloudDriveSyncImporter::enumerateJsonlFiles(const std::string& deviceLogsPath) const {
    std::vector<std::string> files;

    std::error_code ec;
    if (!std::filesystem::exists(deviceLogsPath, ec) || ec) {
        return files;
    }

    for (const auto& entry : std::filesystem::directory_iterator(deviceLogsPath, ec)) {
        if (ec) {
            break;
        }

        if (entry.is_regular_file(ec) && !ec) {
            const std::string filename = entry.path().filename().string();
            if (filename.size() >= 6 && filename.substr(filename.size() - 6) == ".jsonl") {
                files.push_back(entry.path().string());
            }
        }
    }

    std::sort(files.begin(), files.end());
    return files;
}

bool CloudDriveSyncImporter::parseJsonlFile(const std::string& filePath, const std::string& remoteDeviceId,
                                           std::vector<ParsedEvent>& events) {
    std::ifstream file(filePath, std::ios::binary);
    if (!file.is_open()) {
        PASTY_LOG_ERROR("Core.SyncImporter", "Cannot open file: %s", filePath.c_str());
        return false;
    }

    CloudDriveSyncState::FileCursor cursor = m_stateManager->getFileCursor(filePath);
    file.seekg(cursor.last_offset);

    if (!file.good()) {
        PASTY_LOG_ERROR("Core.SyncImporter", "Cannot seek to offset %lu in file: %s",
                        static_cast<unsigned long>(cursor.last_offset), filePath.c_str());
        return false;
    }

    CloudDriveSyncState::RemoteDeviceState deviceState = m_stateManager->getRemoteDeviceState(remoteDeviceId);
    const std::uint64_t maxAppliedSeq = deviceState.max_applied_seq;

    std::string line;
    std::uint64_t currentOffset = cursor.last_offset;
    bool anyNewEvent = false;

    while (std::getline(file, line)) {
        const std::uint64_t lineStartOffset = currentOffset;
        currentOffset = file.tellg();

        if (line.empty()) {
            continue;
        }

        ParsedEvent event;
        if (!parseEvent(line, filePath, lineStartOffset, event)) {
            m_stateManager->incrementFileErrorCount(filePath);
            continue;
        }

        if (event.deviceId != remoteDeviceId) {
            PASTY_LOG_WARN("Core.SyncImporter", "Event device_id mismatch in %s: event says %s, directory is %s",
                            filePath.c_str(), event.deviceId.c_str(), remoteDeviceId.c_str());
            continue;
        }

        if (event.seq <= maxAppliedSeq) {
            continue;
        }

        events.push_back(event);
        anyNewEvent = true;
    }

    std::uint64_t endOffset = currentOffset;
    if (file.tellg() == static_cast<std::streampos>(-1)) {
        file.clear();
        file.seekg(0, std::ios::end);
        endOffset = static_cast<std::uint64_t>(file.tellg());
    }

    m_stateManager->updateFileCursor(filePath, endOffset);

    return true;
}

bool CloudDriveSyncImporter::parseEvent(const std::string& line, const std::string& filePath,
                                     std::uint64_t lineOffset, ParsedEvent& event) {
    using Json = nlohmann::json;
    Json json;
    
    try {
        json = Json::parse(line, nullptr, false);
        if (json.is_discarded()) {
            PASTY_LOG_ERROR("Core.SyncImporter", "Invalid JSON at offset %lu in %s",
                            static_cast<unsigned long>(lineOffset), filePath.c_str());
            return false;
        }
    } catch (...) {
        PASTY_LOG_ERROR("Core.SyncImporter", "JSON parse exception at offset %lu in %s",
                        static_cast<unsigned long>(lineOffset), filePath.c_str());
        return false;
    }

    if (!json.is_object()) {
        return false;
    }

    const int schemaVersion = json.value("schema_version", 0);
    if (schemaVersion != kSchemaVersion) {
        PASTY_LOG_WARN("Core.SyncImporter", "Unsupported schema_version %d in %s", schemaVersion, filePath.c_str());
        return false;
    }

    if (!json.contains("event_id") || !json.contains("device_id") || !json.contains("seq") ||
        !json.contains("ts_ms") || !json.contains("op") || !json.contains("item_type") ||
        !json.contains("content_hash")) {
        PASTY_LOG_ERROR("Core.SyncImporter", "Missing required fields at offset %lu in %s",
                        static_cast<unsigned long>(lineOffset), filePath.c_str());
        return false;
    }

    event.deviceId = json["device_id"].get<std::string>();
    event.seq = json["seq"].get<std::uint64_t>();
    event.tsMs = json["ts_ms"].get<std::int64_t>();
    event.eventId = json["event_id"].get<std::string>();
    event.op = json["op"].get<std::string>();
    event.itemType = json["item_type"].get<std::string>();
    event.contentHash = json["content_hash"].get<std::string>();

    if (!validateContentHash(event.contentHash)) {
        PASTY_LOG_WARN("Core.SyncImporter", "Invalid content_hash in event %s at offset %lu",
                       event.eventId.c_str(), static_cast<unsigned long>(lineOffset));
        return false;
    }

    if (event.op == "upsert_text") {
        if (!json.contains("text")) {
            PASTY_LOG_ERROR("Core.SyncImporter", "Missing 'text' field for upsert_text at offset %lu",
                            static_cast<unsigned long>(lineOffset));
            return false;
        }
        event.text = json["text"].get<std::string>();
        event.contentType = json.value("content_type", std::string());
    } else if (event.op == "upsert_image") {
        if (!json.contains("asset_key")) {
            PASTY_LOG_ERROR("Core.SyncImporter", "Missing 'asset_key' field for upsert_image at offset %lu",
                            static_cast<unsigned long>(lineOffset));
            return false;
        }
        event.assetKey = json["asset_key"].get<std::string>();
        event.imageWidth = json.value("width", 0);
        event.imageHeight = json.value("height", 0);
        event.contentType = json.value("content_type", std::string());
    } else if (event.op != "delete") {
        PASTY_LOG_WARN("Core.SyncImporter", "Unknown op '%s' in event %s, skipping (forward compatibility)",
                       event.op.c_str(), event.eventId.c_str());
        return false;
    }

    event.sourceAppId = json.value("source_app_id", std::string());

    return true;
}

std::optional<std::vector<std::uint8_t>> CloudDriveSyncImporter::readAssetFile(const std::string& assetKey) const {
    const std::string assetPath = m_assetsPath + "/" + assetKey;

    std::ifstream file(assetPath, std::ios::binary);
    if (!file.is_open()) {
        PASTY_LOG_ERROR("Core.SyncImporter", "Cannot open asset file: %s", assetPath.c_str());
        return std::nullopt;
    }

    file.seekg(0, std::ios::end);
    const std::streamsize fileSize = file.tellg();
    file.seekg(0, std::ios::beg);

    if (fileSize > static_cast<std::streamsize>(kMaxAssetBytes)) {
        PASTY_LOG_ERROR("Core.SyncImporter", "Asset file too large: %s (%ld bytes)",
                        assetPath.c_str(), static_cast<long>(fileSize));
        return std::nullopt;
    }

    std::vector<std::uint8_t> bytes(fileSize);
    if (!file.read(reinterpret_cast<char*>(bytes.data()), fileSize)) {
        PASTY_LOG_ERROR("Core.SyncImporter", "Failed to read asset file: %s", assetPath.c_str());
        return std::nullopt;
    }

    return bytes;
}

CloudDriveSyncImporter::ImportResult CloudDriveSyncImporter::applyEvents(std::vector<ParsedEvent>& events,
                                                                      ClipboardService& clipboardService) {
    ImportResult result;
    result.eventsProcessed = static_cast<int>(events.size());

    std::map<TombstoneKey, std::int64_t> batchTombstoneMaxTs;
    
    for (const auto& event : events) {
        if (event.op == "delete") {
            ClipboardItemType type = (event.itemType == "image") ? ClipboardItemType::Image : ClipboardItemType::Text;
            TombstoneKey key{type, event.contentHash};
            auto it = batchTombstoneMaxTs.find(key);
            if (it == batchTombstoneMaxTs.end() || event.tsMs > it->second) {
                batchTombstoneMaxTs[key] = event.tsMs;
            }
        }
    }

    std::string lastDeviceId;
    std::uint64_t lastSeq = 0;

    for (const auto& event : events) {
        bool applied = false;

        if (event.op == "delete") {
            m_stateManager->recordTombstone(event.itemType, event.contentHash, event.tsMs);
            applied = applyDelete(event, clipboardService);
        } else if (event.op == "upsert_text") {
            TombstoneKey key{ClipboardItemType::Text, event.contentHash};
            auto it = batchTombstoneMaxTs.find(key);
            if (it != batchTombstoneMaxTs.end() && event.tsMs <= it->second) {
                PASTY_LOG_DEBUG("Core.SyncImporter", "Skipping upsert due to persisted or batch tombstone: type=%s, hash=%s, event_ts=%lld, tombstone_ts=%lld",
                                 event.itemType.c_str(), event.contentHash.c_str(), static_cast<long long>(event.tsMs), static_cast<long long>(it->second));
                result.eventsSkipped++;
                continue;
            }
            if (m_stateManager->shouldSkipUpsertDueToTombstone(event.itemType, event.contentHash, event.tsMs)) {
                PASTY_LOG_DEBUG("Core.SyncImporter", "Skipping upsert due to persisted tombstone: type=%s, hash=%s, event_ts=%lld",
                                 event.itemType.c_str(), event.contentHash.c_str(), static_cast<long long>(event.tsMs));
                result.eventsSkipped++;
                continue;
            }
            applied = applyUpsertText(event, clipboardService);
        } else if (event.op == "upsert_image") {
            TombstoneKey key{ClipboardItemType::Image, event.contentHash};
            auto it = batchTombstoneMaxTs.find(key);
            if (it != batchTombstoneMaxTs.end() && event.tsMs <= it->second) {
                PASTY_LOG_DEBUG("Core.SyncImporter", "Skipping upsert for tombstoned item in batch: type=%s, hash=%s",
                                event.itemType.c_str(), event.contentHash.c_str());
                result.eventsSkipped++;
                continue;
            }
            if (m_stateManager->shouldSkipUpsertDueToTombstone(event.itemType, event.contentHash, event.tsMs)) {
                PASTY_LOG_DEBUG("Core.SyncImporter", "Skipping upsert due to persisted tombstone: type=%s, hash=%s, event_ts=%lld",
                                event.itemType.c_str(), event.contentHash.c_str(), static_cast<long long>(event.tsMs));
                result.eventsSkipped++;
                continue;
            }
            applied = applyUpsertImage(event, clipboardService);
        } else {
            PASTY_LOG_WARN("Core.SyncImporter", "Skipping unknown op '%s' in apply", event.op.c_str());
            result.eventsSkipped++;
            continue;
        }

        if (applied) {
            result.eventsApplied++;

            if (event.deviceId != lastDeviceId) {
                lastDeviceId = event.deviceId;
                lastSeq = 0;
            }
            if (event.seq > lastSeq) {
                lastSeq = event.seq;
                m_stateManager->updateRemoteDeviceMaxSeq(event.deviceId, event.seq);
            }
        } else {
            result.eventsSkipped++;
        }
    }

    result.success = true;
    PASTY_LOG_INFO("Core.SyncImporter", "Import complete: applied=%d, skipped=%d, errors=%d",
                    result.eventsApplied, result.eventsSkipped, result.errors);
    return result;
}

bool CloudDriveSyncImporter::applyUpsertText(const ParsedEvent& event, ClipboardService& clipboardService) {
    ClipboardHistoryIngestEvent ingestEvent;
    ingestEvent.timestampMs = event.tsMs;
    ingestEvent.sourceAppId = kLoopPrefix + event.deviceId;
    ingestEvent.itemType = (event.itemType == "image") ? ClipboardItemType::Image : ClipboardItemType::Text;
    ingestEvent.text = event.text;

    ClipboardIngestResult result = clipboardService.ingestWithResult(ingestEvent);
    if (!result.ok) {
        PASTY_LOG_ERROR("Core.SyncImporter", "Failed to ingest text from event %s", event.eventId.c_str());
        return false;
    }

    return true;
}

bool CloudDriveSyncImporter::applyUpsertImage(const ParsedEvent& event, ClipboardService& clipboardService) {
    auto imageBytes = readAssetFile(event.assetKey);
    if (!imageBytes) {
        PASTY_LOG_ERROR("Core.SyncImporter", "Failed to read asset %s for event %s",
                        event.assetKey.c_str(), event.eventId.c_str());
        return false;
    }

    ClipboardHistoryIngestEvent ingestEvent;
    ingestEvent.timestampMs = event.tsMs;
    ingestEvent.sourceAppId = kLoopPrefix + event.deviceId;
    ingestEvent.itemType = ClipboardItemType::Image;
    ingestEvent.image.bytes = *imageBytes;
    ingestEvent.image.width = event.imageWidth;
    ingestEvent.image.height = event.imageHeight;
    ingestEvent.image.formatHint = extractExtensionFromAssetKey(event.assetKey);

    ClipboardIngestResult result = clipboardService.ingestWithResult(ingestEvent);
    if (!result.ok) {
        PASTY_LOG_ERROR("Core.SyncImporter", "Failed to ingest image from event %s", event.eventId.c_str());
        return false;
    }

    return true;
}

bool CloudDriveSyncImporter::applyDelete(const ParsedEvent& event, ClipboardService& clipboardService) {
    ClipboardItemType type = (event.itemType == "image") ? ClipboardItemType::Image : ClipboardItemType::Text;
    
    const int deletedCount = clipboardService.deleteByTypeAndContentHash(type, event.contentHash);
    
    if (deletedCount > 0) {
        PASTY_LOG_INFO("Core.SyncImporter", "Deleted %d item(s) with type=%s, hash=%s",
                       deletedCount, event.itemType.c_str(), event.contentHash.c_str());
        return true;
    } else {
        PASTY_LOG_DEBUG("Core.SyncImporter", "No items found to delete with type=%s, hash=%s",
                        event.itemType.c_str(), event.contentHash.c_str());
        return true;
    }
}

} // namespace pasty
