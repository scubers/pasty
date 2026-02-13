// Pasty - Copyright (c) 2026. MIT License.

#include "infrastructure/sync/cloud_drive_sync_exporter.h"
#include <common/logger.h>

#include <chrono>
#include <cstring>
#include <filesystem>
#include <fstream>
#include <iomanip>
#include <sstream>
#include <utility>

#include <nlohmann/json.hpp>
#include <sodium.h>

namespace pasty {

namespace {

bool ensureSodiumInitialized() {
    static const bool initialized = []() {
        return sodium_init() >= 0;
    }();
    return initialized;
}

bool encodeBase64(const std::vector<unsigned char>& input, std::string& output) {
    if (!ensureSodiumInitialized()) {
        return false;
    }

    if (input.empty()) {
        output.clear();
        return true;
    }

    const std::size_t encodedLength = sodium_base64_ENCODED_LEN(input.size(), sodium_base64_VARIANT_ORIGINAL);
    std::vector<char> dynamicBuffer(encodedLength, 0);
    sodium_bin2base64(dynamicBuffer.data(),
                      dynamicBuffer.size(),
                      input.data(),
                      input.size(),
                      sodium_base64_VARIANT_ORIGINAL);
    output.assign(dynamicBuffer.data());
    return true;
}

}

CloudDriveSyncExporter::CloudDriveSyncExporter()
    : m_currentLogFileIndex(1)
    , m_initialized(false) {
}

CloudDriveSyncExporter::~CloudDriveSyncExporter() {
    clearE2eeKey();
}

std::optional<CloudDriveSyncExporter> CloudDriveSyncExporter::Create(const std::string& syncRootPath,
                                                                     const std::string& baseDirectory,
                                                                     const std::optional<EncryptionManager::Key>& e2eeMasterKey,
                                                                     const std::string& e2eeKeyId) {
    CloudDriveSyncExporter exporter;
    if (exporter.initialize(syncRootPath, baseDirectory)) {
        if (e2eeMasterKey.has_value() && !e2eeKeyId.empty()) {
            exporter.setE2eeKey(*e2eeMasterKey, e2eeKeyId);
        }
        return std::make_optional<CloudDriveSyncExporter>(std::move(exporter));
    }
    return std::nullopt;
}

void CloudDriveSyncExporter::setE2eeKey(const EncryptionManager::Key& masterKey, const std::string& keyId) {
    clearE2eeKey();
    m_e2eeMasterKey = masterKey;
    m_e2eeKeyId = keyId;
}

void CloudDriveSyncExporter::clearE2eeKey() {
    if (m_e2eeMasterKey.has_value()) {
        sodium_memzero(m_e2eeMasterKey->data(), m_e2eeMasterKey->size());
        m_e2eeMasterKey.reset();
    }
    m_e2eeKeyId.clear();
}

bool CloudDriveSyncExporter::initialize(const std::string& syncRootPath, const std::string& baseDirectory) {
    if (syncRootPath.empty() || baseDirectory.empty()) {
        return false;
    }

    m_syncRootPath = syncRootPath;
    m_logsPath = syncRootPath + "/logs";
    m_metaPath = syncRootPath + "/meta";
    m_assetsPath = syncRootPath + "/assets";

    auto state = CloudDriveSyncState::LoadOrCreate(baseDirectory);
    if (!state) {
        PASTY_LOG_ERROR("Core.SyncExporter", "Failed to load or create sync state");
        return false;
    }

    m_stateManager = std::make_unique<StateManager>(std::move(state));
    m_deviceLogsPath = m_logsPath + "/" + m_stateManager->deviceId();

    if (!ensureDirectoryStructure()) {
        PASTY_LOG_ERROR("Core.SyncExporter", "Failed to create directory structure");
        return false;
    }

    m_initialized = true;
    PASTY_LOG_INFO("Core.SyncExporter", "Initialized with sync_root=%s, device_id=%s", 
                   syncRootPath.c_str(), m_stateManager->deviceId().c_str());
    return true;
}

bool CloudDriveSyncExporter::ensureDirectoryStructure() {
    std::error_code ec;
    
    std::filesystem::create_directories(m_metaPath, ec);
    if (ec) {
        PASTY_LOG_ERROR("Core.SyncExporter", "Failed to create meta directory: %s", m_metaPath.c_str());
        return false;
    }
    
    std::filesystem::create_directories(m_logsPath, ec);
    if (ec) {
        PASTY_LOG_ERROR("Core.SyncExporter", "Failed to create logs directory: %s", m_logsPath.c_str());
        return false;
    }

    std::filesystem::create_directories(m_assetsPath, ec);
    if (ec) {
        PASTY_LOG_ERROR("Core.SyncExporter", "Failed to create assets directory: %s", m_assetsPath.c_str());
        return false;
    }

    std::filesystem::create_directories(m_deviceLogsPath, ec);
    if (ec) {
        PASTY_LOG_ERROR("Core.SyncExporter", "Failed to create device logs directory: %s", m_deviceLogsPath.c_str());
        return false;
    }

    // Find the highest existing log file index
    m_currentLogFileIndex = 1;
    for (int i = 1; i <= 9999; ++i) {
        std::ostringstream oss;
        oss << std::setw(4) << std::setfill('0') << i;
        const std::string path = m_deviceLogsPath + "/events-" + oss.str() + ".jsonl";
        if (std::filesystem::exists(path, ec)) {
            m_currentLogFileIndex = i;
        }
    }

    return true;
}

std::string CloudDriveSyncExporter::getCurrentLogFilePath() const {
    std::ostringstream oss;
    oss << std::setw(4) << std::setfill('0') << m_currentLogFileIndex;
    return m_deviceLogsPath + "/events-" + oss.str() + ".jsonl";
}

bool CloudDriveSyncExporter::rotateLogFileIfNeeded(std::size_t lineLength) {
    const std::string currentPath = getCurrentLogFilePath();
    std::error_code ec;
    
    if (!std::filesystem::exists(currentPath, ec)) {
        return true;
    }

    const std::uintmax_t currentSize = std::filesystem::file_size(currentPath, ec);
    if (ec) {
        PASTY_LOG_ERROR("Core.SyncExporter", "Failed to get file size: %s", currentPath.c_str());
        return false;
    }

    if (currentSize + lineLength > kLogFileRotationBytes) {
        // Increment index to create new file
        if (m_currentLogFileIndex >= 9999) {
            PASTY_LOG_ERROR("Core.SyncExporter", "No available log file names for rotation");
            return false;
        }
        
        ++m_currentLogFileIndex;
        
        PASTY_LOG_INFO("Core.SyncExporter", "Rotated to new log file: events-%04d.jsonl", m_currentLogFileIndex);
    }

    return true;
}

bool CloudDriveSyncExporter::writeAssetAtomically(const std::string& assetKey, const std::vector<std::uint8_t>& bytes) {
    const std::string targetPath = m_assetsPath + "/" + assetKey;
    const std::string tempPath = targetPath + ".tmp";

    std::ofstream output(tempPath, std::ios::binary | std::ios::trunc);
    if (!output.is_open()) {
        PASTY_LOG_ERROR("Core.SyncExporter", "Failed to open temp asset file: %s", tempPath.c_str());
        return false;
    }

    output.write(reinterpret_cast<const char*>(bytes.data()), static_cast<std::streamsize>(bytes.size()));
    output.flush();
    output.close();

    if (std::rename(tempPath.c_str(), targetPath.c_str()) != 0) {
        PASTY_LOG_ERROR("Core.SyncExporter", "Failed to rename temp asset to: %s", targetPath.c_str());
        std::remove(tempPath.c_str());
        return false;
    }

    PASTY_LOG_DEBUG("Core.SyncExporter", "Asset written: %s (%zu bytes)", assetKey.c_str(), bytes.size());
    return true;
}

CloudDriveSyncExporter::ExportResult CloudDriveSyncExporter::writeJsonlEvent(const std::string& jsonLine) {
    if (!m_initialized) {
        return ExportResult::ExportFailed;
    }

    const std::size_t lineLength = jsonLine.size();
    if (lineLength > kMaxEventLineBytes) {
        PASTY_LOG_ERROR("Core.SyncExporter", "Event line too large: %zu bytes (max: %lu)", 
                        lineLength, static_cast<unsigned long>(kMaxEventLineBytes));
        const std::string logPath = getCurrentLogFilePath();
        m_stateManager->incrementFileErrorCount(logPath);
        return ExportResult::SkippedEventTooLarge;
    }

    if (!rotateLogFileIfNeeded(lineLength + 1)) {
        return ExportResult::ExportFailed;
    }

    const std::string logPath = getCurrentLogFilePath();
    std::ofstream output(logPath, std::ios::app);
    if (!output.is_open()) {
        PASTY_LOG_ERROR("Core.SyncExporter", "Failed to open log file: %s", logPath.c_str());
        m_stateManager->incrementFileErrorCount(logPath);
        return ExportResult::ExportFailed;
    }

    output << jsonLine << "\n";
    output.flush();
    output.close();

    PASTY_LOG_DEBUG("Core.SyncExporter", "Event written to: %s", logPath.c_str());
    return ExportResult::Success;
}

CloudDriveSyncExporter::ExportResult CloudDriveSyncExporter::exportTextItem(const ClipboardHistoryItem& item) {
    if (!m_initialized) {
        return ExportResult::SyncNotConfigured;
    }

    if (item.sourceAppId.compare(0, strlen(kLoopPrefix), kLoopPrefix) == 0) {
        PASTY_LOG_DEBUG("Core.SyncExporter", "Skipping loop prevention: sourceAppId=%s", item.sourceAppId.c_str());
        return ExportResult::SkippedLoopPrevention;
    }

    const std::uint64_t seq = m_stateManager->reserveNextSeq();
    if (seq == 0) {
        return ExportResult::ExportFailed;
    }

    const std::string deviceId = m_stateManager->deviceId();
    const std::string eventId = deviceId + ":" + std::to_string(seq);

    const std::int64_t nowMs = std::chrono::duration_cast<std::chrono::milliseconds>(
        std::chrono::system_clock::now().time_since_epoch()).count();

    using Json = nlohmann::json;
    Json json;
    json["schema_version"] = kSchemaVersion;
    json["event_id"] = eventId;
    json["device_id"] = deviceId;
    json["seq"] = seq;
    json["ts_ms"] = nowMs;
    json["op"] = "upsert_text";
    json["item_type"] = "text";
    json["content_hash"] = item.contentHash;
    json["content_type"] = "text/plain";
    json["size_bytes"] = item.content.size();
    json["source_app_id"] = item.sourceAppId;
    json["is_concealed"] = false;
    json["is_transient"] = false;

    if (m_e2eeMasterKey.has_value() && !m_e2eeKeyId.empty()) {
        EncryptionManager::Bytes plaintext(item.content.begin(), item.content.end());
        EncryptionManager::Bytes aad(eventId.begin(), eventId.end());
        EncryptionManager::EncryptedPayload encryptedPayload;

        const bool encrypted = EncryptionManager::encrypt(*m_e2eeMasterKey, plaintext, aad, encryptedPayload);
        if (!plaintext.empty()) {
            sodium_memzero(plaintext.data(), plaintext.size());
        }
        if (!aad.empty()) {
            sodium_memzero(aad.data(), aad.size());
        }

        if (!encrypted) {
            PASTY_LOG_ERROR("Core.SyncExporter", "Failed to encrypt text event: %s", eventId.c_str());
            return ExportResult::ExportFailed;
        }

        std::string nonceB64;
        std::string ciphertextB64;
        const bool nonceEncoded = encodeBase64(encryptedPayload.nonce, nonceB64);
        const bool ciphertextEncoded = encodeBase64(encryptedPayload.ciphertext, ciphertextB64);

        if (!encryptedPayload.nonce.empty()) {
            sodium_memzero(encryptedPayload.nonce.data(), encryptedPayload.nonce.size());
        }
        if (!encryptedPayload.ciphertext.empty()) {
            sodium_memzero(encryptedPayload.ciphertext.data(), encryptedPayload.ciphertext.size());
        }

        if (!nonceEncoded || !ciphertextEncoded) {
            PASTY_LOG_ERROR("Core.SyncExporter", "Failed to encode encrypted payload for event: %s", eventId.c_str());
            return ExportResult::ExportFailed;
        }

        json["encryption"] = "e2ee";
        json["key_id"] = m_e2eeKeyId;
        json["nonce"] = nonceB64;
        json["ciphertext"] = ciphertextB64;
    } else {
        json["text"] = item.content;
        json["encryption"] = "none";
    }

    const std::string jsonLine = json.dump();
    return writeJsonlEvent(jsonLine);
}

CloudDriveSyncExporter::ExportResult CloudDriveSyncExporter::exportImageItem(const ClipboardHistoryItem& item, const std::vector<std::uint8_t>& imageBytes) {
    if (!m_initialized) {
        return ExportResult::SyncNotConfigured;
    }

    if (item.sourceAppId.compare(0, strlen(kLoopPrefix), kLoopPrefix) == 0) {
        PASTY_LOG_DEBUG("Core.SyncExporter", "Skipping loop prevention: sourceAppId=%s", item.sourceAppId.c_str());
        return ExportResult::SkippedLoopPrevention;
    }

    if (imageBytes.size() > kMaxImageBytes) {
        PASTY_LOG_ERROR("Core.SyncExporter", "Image too large: %zu bytes (max: %lu), hash=%s", 
                        imageBytes.size(), static_cast<unsigned long>(kMaxImageBytes), item.contentHash.c_str());
        const std::string logPath = getCurrentLogFilePath();
        m_stateManager->incrementFileErrorCount(logPath);
        return ExportResult::SkippedImageTooLarge;
    }

    const std::uint64_t seq = m_stateManager->reserveNextSeq();
    if (seq == 0) {
        return ExportResult::ExportFailed;
    }

    const std::string deviceId = m_stateManager->deviceId();
    const std::string eventId = deviceId + ":" + std::to_string(seq);

    const std::int64_t nowMs = std::chrono::duration_cast<std::chrono::milliseconds>(
        std::chrono::system_clock::now().time_since_epoch()).count();

    std::string extension = item.imageFormat;
    if (extension.empty()) {
        extension = "png";
    }
    for (char& c : extension) {
        if (c >= 'A' && c <= 'Z') {
            c = static_cast<char>(c - 'A' + 'a');
        }
    }
    if (extension == "jpg") {
        extension = "jpeg";
    }

    const std::string assetKey = item.contentHash + "." + extension;

    std::vector<std::uint8_t> assetBytesToWrite;
    std::string nonceB64;
    bool encryptedAsset = false;

    if (m_e2eeMasterKey.has_value() && !m_e2eeKeyId.empty()) {
        EncryptionManager::Bytes plaintext(imageBytes.begin(), imageBytes.end());
        EncryptionManager::Bytes aad(eventId.begin(), eventId.end());
        EncryptionManager::EncryptedPayload encryptedPayload;

        const bool encrypted = EncryptionManager::encrypt(*m_e2eeMasterKey, plaintext, aad, encryptedPayload);
        if (!plaintext.empty()) {
            sodium_memzero(plaintext.data(), plaintext.size());
        }
        if (!aad.empty()) {
            sodium_memzero(aad.data(), aad.size());
        }

        if (!encrypted) {
            PASTY_LOG_ERROR("Core.SyncExporter", "Failed to encrypt image asset for event: %s", eventId.c_str());
            return ExportResult::ExportFailed;
        }

        if (!encodeBase64(encryptedPayload.nonce, nonceB64)) {
            if (!encryptedPayload.nonce.empty()) {
                sodium_memzero(encryptedPayload.nonce.data(), encryptedPayload.nonce.size());
            }
            if (!encryptedPayload.ciphertext.empty()) {
                sodium_memzero(encryptedPayload.ciphertext.data(), encryptedPayload.ciphertext.size());
            }
            PASTY_LOG_ERROR("Core.SyncExporter", "Failed to encode image nonce for event: %s", eventId.c_str());
            return ExportResult::ExportFailed;
        }

        assetBytesToWrite.assign(encryptedPayload.ciphertext.begin(), encryptedPayload.ciphertext.end());

        if (!encryptedPayload.nonce.empty()) {
            sodium_memzero(encryptedPayload.nonce.data(), encryptedPayload.nonce.size());
        }
        if (!encryptedPayload.ciphertext.empty()) {
            sodium_memzero(encryptedPayload.ciphertext.data(), encryptedPayload.ciphertext.size());
        }

        encryptedAsset = true;
    } else {
        assetBytesToWrite = imageBytes;
    }

    if (!writeAssetAtomically(assetKey, assetBytesToWrite)) {
        if (!assetBytesToWrite.empty()) {
            sodium_memzero(assetBytesToWrite.data(), assetBytesToWrite.size());
        }
        return ExportResult::ExportFailed;
    }

    if (!assetBytesToWrite.empty()) {
        sodium_memzero(assetBytesToWrite.data(), assetBytesToWrite.size());
    }

    using Json = nlohmann::json;
    Json json;
    json["schema_version"] = kSchemaVersion;
    json["event_id"] = eventId;
    json["device_id"] = deviceId;
    json["seq"] = seq;
    json["ts_ms"] = nowMs;
    json["op"] = "upsert_image";
    json["item_type"] = "image";
    json["content_hash"] = item.contentHash;
    json["asset_key"] = assetKey;
    json["width"] = item.imageWidth;
    json["height"] = item.imageHeight;
    json["content_type"] = "image/" + extension;
    json["size_bytes"] = imageBytes.size();
    json["source_app_id"] = item.sourceAppId;
    json["is_concealed"] = false;
    json["is_transient"] = false;
    if (encryptedAsset) {
        json["encryption"] = "e2ee";
        json["key_id"] = m_e2eeKeyId;
        json["nonce"] = nonceB64;
    } else {
        json["encryption"] = "none";
    }

    const std::string jsonLine = json.dump();
    return writeJsonlEvent(jsonLine);
}

CloudDriveSyncExporter::ExportResult CloudDriveSyncExporter::exportDeleteTombstone(ClipboardItemType itemType, const std::string& contentHash) {
    if (!m_initialized) {
        return ExportResult::SyncNotConfigured;
    }

    const std::uint64_t seq = m_stateManager->reserveNextSeq();
    if (seq == 0) {
        return ExportResult::ExportFailed;
    }

    const std::string deviceId = m_stateManager->deviceId();
    const std::string eventId = deviceId + ":" + std::to_string(seq);

    const std::int64_t nowMs = std::chrono::duration_cast<std::chrono::milliseconds>(
        std::chrono::system_clock::now().time_since_epoch()).count();

    const std::string itemTypeStr = (itemType == ClipboardItemType::Image) ? "image" : "text";

    using Json = nlohmann::json;
    Json json;
    json["schema_version"] = kSchemaVersion;
    json["event_id"] = eventId;
    json["device_id"] = deviceId;
    json["seq"] = seq;
    json["ts_ms"] = nowMs;
    json["op"] = "delete";
    json["item_type"] = itemTypeStr;
    json["content_hash"] = contentHash;

    const std::string jsonLine = json.dump();
    return writeJsonlEvent(jsonLine);
}

bool CloudDriveSyncExporter::isConfigured() const {
    return m_initialized;
}

} // namespace pasty
