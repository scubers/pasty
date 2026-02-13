// Pasty - Copyright (c) 2026. MIT License.

#include "infrastructure/sync/cloud_drive_sync_importer.h"
#include "application/history/clipboard_service.h"
#include "infrastructure/sync/cloud_drive_sync_protocol_info.h"
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
#include <sodium.h>

namespace pasty {

namespace {

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

bool ensureSodiumInitialized() {
    static const bool initialized = []() {
        return sodium_init() >= 0;
    }();
    return initialized;
}

bool decodeBase64(const std::string& encoded, EncryptionManager::Bytes& outBytes) {
    if (!ensureSodiumInitialized()) {
        return false;
    }

    outBytes.assign(encoded.size(), 0);
    std::size_t decodedLength = 0;
    const int rc = sodium_base642bin(outBytes.data(),
                                     outBytes.size(),
                                     encoded.c_str(),
                                     encoded.size(),
                                     nullptr,
                                     &decodedLength,
                                     nullptr,
                                     sodium_base64_VARIANT_ORIGINAL);
    if (rc != 0) {
        if (!outBytes.empty()) {
            sodium_memzero(outBytes.data(), outBytes.size());
        }
        outBytes.clear();
        return false;
    }

    outBytes.resize(decodedLength);
    return true;
}

} // namespace

CloudDriveSyncImporter::CloudDriveSyncImporter()
    : m_protocolE2eeEnabled(false)
    , m_initialized(false) {
}

CloudDriveSyncImporter::~CloudDriveSyncImporter() {
    clearE2eeKey();
}

std::optional<CloudDriveSyncImporter> CloudDriveSyncImporter::Create(const std::string& syncRootPath,
                                                                     const std::string& baseDirectory,
                                                                     const std::optional<EncryptionManager::Key>& e2eeMasterKey,
                                                                     const std::string& e2eeKeyId) {
    CloudDriveSyncImporter importer;
    if (!importer.initialize(syncRootPath, baseDirectory)) {
        return std::nullopt;
    }
    if (e2eeMasterKey.has_value() && !e2eeKeyId.empty()) {
        importer.setE2eeKey(*e2eeMasterKey, e2eeKeyId);
    }
    return std::make_optional<CloudDriveSyncImporter>(std::move(importer));
}

void CloudDriveSyncImporter::setE2eeKey(const EncryptionManager::Key& masterKey, const std::string& keyId) {
    clearE2eeKey();
    m_e2eeMasterKey = masterKey;
    m_e2eeKeyId = keyId;
}

void CloudDriveSyncImporter::clearE2eeKey() {
    if (m_e2eeMasterKey.has_value()) {
        sodium_memzero(m_e2eeMasterKey->data(), m_e2eeMasterKey->size());
        m_e2eeMasterKey.reset();
    }
    m_e2eeKeyId.clear();
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

    auto protocolInfo = CloudDriveSyncProtocolInfo::Load(syncRootPath);
    m_protocolE2eeEnabled = protocolInfo.has_value();
    m_protocolE2eeKeyId = protocolInfo.has_value() ? protocolInfo->keyId : std::string();

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
        const std::string encryptionMode = json.value("encryption", std::string("none"));
        if (encryptionMode == "none") {
            if (!json.contains("text")) {
                PASTY_LOG_ERROR("Core.SyncImporter", "Missing 'text' field for upsert_text at offset %lu",
                                static_cast<unsigned long>(lineOffset));
                return false;
            }
            event.text = json["text"].get<std::string>();
        } else if (encryptionMode == "e2ee") {
            if (!json.contains("key_id") || !json["key_id"].is_string() ||
                !json.contains("nonce") || !json["nonce"].is_string() ||
                !json.contains("ciphertext") || !json["ciphertext"].is_string()) {
                PASTY_LOG_ERROR("Core.SyncImporter", "Missing e2ee fields for upsert_text at offset %lu",
                                static_cast<unsigned long>(lineOffset));
                return false;
            }

            const std::string keyId = json["key_id"].get<std::string>();
            if ((m_protocolE2eeEnabled && !m_e2eeMasterKey.has_value()) ||
                m_e2eeKeyId.empty() ||
                keyId != m_e2eeKeyId ||
                (!m_protocolE2eeKeyId.empty() && keyId != m_protocolE2eeKeyId)) {
                event.skipDueToMissingKey = true;
                event.contentType = json.value("content_type", std::string());
                event.sourceAppId = json.value("source_app_id", std::string());
                return true;
            }

            EncryptionManager::Bytes nonce;
            EncryptionManager::Bytes ciphertext;
            if (!decodeBase64(json["nonce"].get<std::string>(), nonce) ||
                !decodeBase64(json["ciphertext"].get<std::string>(), ciphertext)) {
                PASTY_LOG_ERROR("Core.SyncImporter", "Invalid e2ee base64 payload at offset %lu in %s",
                                static_cast<unsigned long>(lineOffset), filePath.c_str());
                return false;
            }

            EncryptionManager::Bytes aad(event.eventId.begin(), event.eventId.end());
            EncryptionManager::Bytes plaintext;
            const bool decrypted = EncryptionManager::decrypt(*m_e2eeMasterKey, nonce, ciphertext, aad, plaintext);

            if (!nonce.empty()) {
                sodium_memzero(nonce.data(), nonce.size());
            }
            if (!ciphertext.empty()) {
                sodium_memzero(ciphertext.data(), ciphertext.size());
            }
            if (!aad.empty()) {
                sodium_memzero(aad.data(), aad.size());
            }

            if (!decrypted) {
                PASTY_LOG_ERROR("Core.SyncImporter", "Failed to decrypt e2ee text event: %s", event.eventId.c_str());
                return false;
            }

            event.text.assign(reinterpret_cast<const char*>(plaintext.data()), plaintext.size());
            if (!plaintext.empty()) {
                sodium_memzero(plaintext.data(), plaintext.size());
            }
        } else {
            PASTY_LOG_WARN("Core.SyncImporter", "Unsupported encryption mode '%s' for event %s",
                           encryptionMode.c_str(), event.eventId.c_str());
            return false;
        }
        event.contentType = json.value("content_type", std::string());
    } else if (event.op == "upsert_image") {
        if (!json.contains("asset_key")) {
            PASTY_LOG_ERROR("Core.SyncImporter", "Missing 'asset_key' field for upsert_image at offset %lu",
                            static_cast<unsigned long>(lineOffset));
            return false;
        }

        const std::string encryptionMode = json.value("encryption", std::string("none"));
        if (encryptionMode == "none") {
            event.text.clear();
        } else if (encryptionMode == "e2ee") {
            if (!json.contains("key_id") || !json["key_id"].is_string() ||
                !json.contains("nonce") || !json["nonce"].is_string()) {
                PASTY_LOG_ERROR("Core.SyncImporter", "Missing e2ee fields for upsert_image at offset %lu",
                                static_cast<unsigned long>(lineOffset));
                return false;
            }

            const std::string keyId = json["key_id"].get<std::string>();
            if ((m_protocolE2eeEnabled && !m_e2eeMasterKey.has_value()) ||
                m_e2eeKeyId.empty() ||
                keyId != m_e2eeKeyId ||
                (!m_protocolE2eeKeyId.empty() && keyId != m_protocolE2eeKeyId)) {
                event.skipDueToMissingKey = true;
                event.contentType = json.value("content_type", std::string());
                event.sourceAppId = json.value("source_app_id", std::string());
                return true;
            }

            event.text = json["nonce"].get<std::string>();
            if (event.text.empty()) {
                PASTY_LOG_ERROR("Core.SyncImporter", "Empty nonce for encrypted image event at offset %lu",
                                static_cast<unsigned long>(lineOffset));
                return false;
            }
        } else {
            PASTY_LOG_WARN("Core.SyncImporter", "Unsupported encryption mode '%s' for image event %s",
                           encryptionMode.c_str(), event.eventId.c_str());
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
        if (event.skipDueToMissingKey) {
            result.eventsSkipped++;
            result.errors++;
            PASTY_LOG_WARN("Core.SyncImporter", "Skipping encrypted event due to unavailable key: %s", event.eventId.c_str());
            continue;
        }

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

    EncryptionManager::Bytes decryptedBytes;
    bool encryptedAsset = !event.text.empty();
    if (encryptedAsset) {
        if (!m_e2eeMasterKey.has_value()) {
            if (!imageBytes->empty()) {
                sodium_memzero(imageBytes->data(), imageBytes->size());
            }
            PASTY_LOG_WARN("Core.SyncImporter", "Missing key for encrypted image event: %s", event.eventId.c_str());
            return false;
        }

        EncryptionManager::Bytes nonce;
        if (!decodeBase64(event.text, nonce)) {
            if (!imageBytes->empty()) {
                sodium_memzero(imageBytes->data(), imageBytes->size());
            }
            PASTY_LOG_ERROR("Core.SyncImporter", "Invalid nonce for encrypted image event: %s", event.eventId.c_str());
            return false;
        }

        EncryptionManager::Bytes ciphertext(imageBytes->begin(), imageBytes->end());
        EncryptionManager::Bytes aad(event.eventId.begin(), event.eventId.end());
        const bool decrypted = EncryptionManager::decrypt(*m_e2eeMasterKey, nonce, ciphertext, aad, decryptedBytes);

        if (!nonce.empty()) {
            sodium_memzero(nonce.data(), nonce.size());
        }
        if (!ciphertext.empty()) {
            sodium_memzero(ciphertext.data(), ciphertext.size());
        }
        if (!aad.empty()) {
            sodium_memzero(aad.data(), aad.size());
        }
        if (!imageBytes->empty()) {
            sodium_memzero(imageBytes->data(), imageBytes->size());
        }

        if (!decrypted) {
            PASTY_LOG_ERROR("Core.SyncImporter", "Failed to decrypt image event: %s", event.eventId.c_str());
            return false;
        }
    }

    ClipboardHistoryIngestEvent ingestEvent;
    ingestEvent.timestampMs = event.tsMs;
    ingestEvent.sourceAppId = kLoopPrefix + event.deviceId;
    ingestEvent.itemType = ClipboardItemType::Image;
    if (encryptedAsset) {
        ingestEvent.image.bytes.assign(decryptedBytes.begin(), decryptedBytes.end());
    } else {
        ingestEvent.image.bytes = *imageBytes;
    }
    ingestEvent.image.width = event.imageWidth;
    ingestEvent.image.height = event.imageHeight;
    ingestEvent.image.formatHint = extractExtensionFromAssetKey(event.assetKey);

    ClipboardIngestResult result = clipboardService.ingestWithResult(ingestEvent);

    if (!ingestEvent.image.bytes.empty()) {
        sodium_memzero(ingestEvent.image.bytes.data(), ingestEvent.image.bytes.size());
    }
    if (!decryptedBytes.empty()) {
        sodium_memzero(decryptedBytes.data(), decryptedBytes.size());
    }
    if (imageBytes.has_value() && !imageBytes->empty()) {
        sodium_memzero(imageBytes->data(), imageBytes->size());
    }

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
