// Pasty - Copyright (c) 2026. MIT License.

#include "infrastructure/sync/cloud_drive_sync_state.h"
#include <common/logger.h>

#include <cctype>
#include <chrono>
#include <cstdio>
#include <ctime>
#include <fstream>
#include <filesystem>
#include <random>
#include <sstream>
#include <iomanip>
#include <vector>
#include <optional>

#include <nlohmann/json.hpp>

namespace pasty {

namespace {

constexpr int SCHEMA_VERSION = 1;
constexpr int DEVICE_ID_BYTES = 16;

bool ensureDirectoryExists(const std::string& path) {
    if (path.empty()) {
        return false;
    }
    std::error_code ec;
    std::filesystem::create_directories(path, ec);
    return !ec;
}

std::string hexEncode(const std::vector<std::uint8_t>& bytes) {
    std::ostringstream oss;
    oss << std::hex << std::setfill('0');
    for (std::uint8_t byte : bytes) {
        oss << std::setw(2) << static_cast<int>(byte);
    }
    return oss.str();
}

std::vector<std::uint8_t> generateRandomBytes(std::size_t count) {
    std::random_device rd;
    std::mt19937_64 gen(rd());
    std::uniform_int_distribution<std::uint8_t> dist(0, 255);

    std::vector<std::uint8_t> bytes(count);
    for (std::size_t i = 0; i < count; ++i) {
        bytes[i] = dist(gen);
    }
    return bytes;
}

std::int64_t nowMs() {
    const auto now = std::chrono::system_clock::now();
    return static_cast<std::int64_t>(std::chrono::duration_cast<std::chrono::milliseconds>(now.time_since_epoch()).count());
}

} // namespace

CloudDriveSyncState::CloudDriveSyncState()
    : m_mutex(std::make_shared<std::mutex>()) {
}

std::string CloudDriveSyncState::generateDeviceId() {
    const auto bytes = generateRandomBytes(DEVICE_ID_BYTES);
    return hexEncode(bytes);
}

std::string CloudDriveSyncState::stateFilePath(const std::string& baseDirectory) {
    return baseDirectory + "/sync_state.json";
}

std::string CloudDriveSyncState::backupCorruptedState(const std::string& stateFilePath) {
    const std::int64_t timestampMs = nowMs();
    const std::string backupPath = stateFilePath + ".corrupted." + std::to_string(timestampMs);

    PASTY_LOG_WARN("Core.SyncState", "Corrupted state detected, backing up to: %s", backupPath.c_str());
    std::rename(stateFilePath.c_str(), backupPath.c_str());

    return backupPath;
}

bool CloudDriveSyncState::loadState(const std::string& statePath) {
    std::ifstream file(statePath);
    if (!file.is_open()) {
        return false;
    }

    std::string content((std::istreambuf_iterator<char>(file)), std::istreambuf_iterator<char>());

    using Json = nlohmann::json;
    Json json;
    try {
        json = Json::parse(content, nullptr, false);
        if (json.is_discarded()) {
            return false;
        }
    } catch (...) {
        return false;
    }

    if (!json.is_object()) {
        return false;
    }

    const int schemaVersion = json.value("schema_version", 0);
    if (schemaVersion != SCHEMA_VERSION) {
        PASTY_LOG_ERROR("Core.SyncState", "Unsupported schema version: %d (expected: %d)", schemaVersion, SCHEMA_VERSION);
        return false;
    }

    m_deviceId = json.value("device_id", std::string());
    if (m_deviceId.empty()) {
        PASTY_LOG_ERROR("Core.SyncState", "Missing device_id in state file");
        return false;
    }

    m_nextSeq = json.value("next_seq", std::uint64_t(1));

    if (json.contains("devices") && json["devices"].is_object()) {
        for (const auto& [key, value] : json["devices"].items()) {
            if (value.is_object()) {
                RemoteDeviceState deviceState;
                deviceState.max_applied_seq = value.value("max_applied_seq", std::uint64_t(0));
                m_remoteDevices[key] = deviceState;
            }
        }
    }

    if (json.contains("files") && json["files"].is_object()) {
        for (const auto& [key, value] : json["files"].items()) {
            if (value.is_object()) {
                FileCursor cursor;
                cursor.last_offset = value.value("last_offset", std::uint64_t(0));
                cursor.error_count = value.value("error_count", 0);
                m_fileCursors[key] = cursor;
            }
        }
    }

    if (json.contains("tombstones") && json["tombstones"].is_array()) {
        for (const auto& value : json["tombstones"]) {
            if (value.is_object()) {
                Tombstone t;
                t.item_type = value.value("item_type", std::string());
                t.content_hash = value.value("content_hash", std::string());
                t.ts_ms = value.value("ts_ms", std::int64_t(0));
                if (!t.item_type.empty() && !t.content_hash.empty()) {
                    m_tombstones.push_back(t);
                }
            }
        }
    }

    PASTY_LOG_INFO("Core.SyncState", "State loaded successfully: device_id=%s, next_seq=%lu",
                   m_deviceId.c_str(), static_cast<unsigned long>(m_nextSeq));
    return true;
}

bool CloudDriveSyncState::createDefaultState(const std::string& baseDirectory) {
    m_baseDirectory = baseDirectory;
    m_deviceId = generateDeviceId();
    m_nextSeq = 1;
    m_remoteDevices.clear();
    m_fileCursors.clear();

    PASTY_LOG_INFO("Core.SyncState", "Created new default state: device_id=%s", m_deviceId.c_str());

    return saveState();
}

bool CloudDriveSyncState::saveState() const {
    return saveStateImpl(stateFilePath(m_baseDirectory));
}

bool CloudDriveSyncState::saveStateImpl(const std::string& statePath) const {
    const std::string tempPath = statePath + ".tmp";

    using Json = nlohmann::json;
    Json json;
    json["schema_version"] = SCHEMA_VERSION;
    json["device_id"] = m_deviceId;
    json["next_seq"] = m_nextSeq;

    Json devicesJson = Json::object();
    for (const auto& [deviceId, deviceState] : m_remoteDevices) {
        Json deviceJson;
        deviceJson["max_applied_seq"] = deviceState.max_applied_seq;
        devicesJson[deviceId] = deviceJson;
    }
    json["devices"] = devicesJson;

    Json filesJson = Json::object();
    for (const auto& [filePath, cursor] : m_fileCursors) {
        Json fileJson;
        fileJson["last_offset"] = cursor.last_offset;
        fileJson["error_count"] = cursor.error_count;
        filesJson[filePath] = fileJson;
    }
    json["files"] = filesJson;

    Json tombstonesJson = Json::array();
    for (const auto& t : m_tombstones) {
        Json tombstoneJson;
        tombstoneJson["item_type"] = t.item_type;
        tombstoneJson["content_hash"] = t.content_hash;
        tombstoneJson["ts_ms"] = t.ts_ms;
        tombstonesJson.push_back(tombstoneJson);
    }
    json["tombstones"] = tombstonesJson;

    const std::string content = json.dump(2);

    std::ofstream output(tempPath, std::ios::trunc);
    if (!output.is_open()) {
        PASTY_LOG_ERROR("Core.SyncState", "Failed to open temp state file: %s", tempPath.c_str());
        return false;
    }

    output << content;
    output.flush();
    output.close();

    if (std::rename(tempPath.c_str(), statePath.c_str()) != 0) {
        PASTY_LOG_ERROR("Core.SyncState", "Failed to rename temp state file to: %s", statePath.c_str());
        std::remove(tempPath.c_str());
        return false;
    }

    PASTY_LOG_DEBUG("Core.SyncState", "State saved successfully to: %s", statePath.c_str());
    return true;
}

std::optional<CloudDriveSyncState> CloudDriveSyncState::LoadOrCreate(const std::string& baseDirectory) {
    if (!ensureDirectoryExists(baseDirectory)) {
        PASTY_LOG_ERROR("Core.SyncState", "Failed to ensure base directory: %s", baseDirectory.c_str());
        return std::nullopt;
    }

    CloudDriveSyncState state;
    state.m_baseDirectory = baseDirectory;

    const std::string statePath = stateFilePath(baseDirectory);
    std::ifstream testFile(statePath);
    const bool fileExists = testFile.good();
    testFile.close();

    if (fileExists) {
        if (state.loadState(statePath)) {
            return std::make_optional<CloudDriveSyncState>(std::move(state));
        }

        backupCorruptedState(statePath);
    }

    if (state.createDefaultState(baseDirectory)) {
        return std::make_optional<CloudDriveSyncState>(std::move(state));
    }

    PASTY_LOG_ERROR("Core.SyncState", "Failed to create default state");
    return std::nullopt;
}

std::string CloudDriveSyncState::deviceId() const {
    std::lock_guard<std::mutex> lock(*m_mutex);
    return m_deviceId;
}

std::uint64_t CloudDriveSyncState::nextSeq() const {
    std::lock_guard<std::mutex> lock(*m_mutex);
    return m_nextSeq;
}

CloudDriveSyncState::RemoteDeviceState CloudDriveSyncState::getRemoteDeviceState(const std::string& deviceId) const {
    std::lock_guard<std::mutex> lock(*m_mutex);

    const RemoteDeviceState kEmptyState;
    auto it = m_remoteDevices.find(deviceId);
    if (it != m_remoteDevices.end()) {
        return it->second;
    }
    return kEmptyState;
}

CloudDriveSyncState::FileCursor CloudDriveSyncState::getFileCursor(const std::string& filePath) const {
    std::lock_guard<std::mutex> lock(*m_mutex);

    const FileCursor kEmptyCursor;
    auto it = m_fileCursors.find(filePath);
    if (it != m_fileCursors.end()) {
        return it->second;
    }
    return kEmptyCursor;
}

std::uint64_t CloudDriveSyncState::reserveNextSeq() {
    std::lock_guard<std::mutex> lock(*m_mutex);

    const std::uint64_t seq = m_nextSeq;
    ++m_nextSeq;

    if (!saveState()) {
        PASTY_LOG_WARN("Core.SyncState", "Failed to persist state after reserving seq %lu", static_cast<unsigned long>(seq));
    }

    return seq;
}

bool CloudDriveSyncState::updateRemoteDeviceMaxSeq(const std::string& remoteDeviceId, std::uint64_t newSeq) {
    std::lock_guard<std::mutex> lock(*m_mutex);

    auto& deviceState = m_remoteDevices[remoteDeviceId];
    if (newSeq <= deviceState.max_applied_seq) {
        return false;
    }

    deviceState.max_applied_seq = newSeq;

    return saveState();
}

bool CloudDriveSyncState::updateFileCursor(const std::string& filePath, std::uint64_t offset) {
    std::lock_guard<std::mutex> lock(*m_mutex);

    auto& cursor = m_fileCursors[filePath];
    if (cursor.last_offset == offset) {
        return true;
    }

    cursor.last_offset = offset;

    return saveState();
}

int CloudDriveSyncState::incrementFileErrorCount(const std::string& filePath) {
    std::lock_guard<std::mutex> lock(*m_mutex);

    auto& cursor = m_fileCursors[filePath];
    ++cursor.error_count;

    saveState();

    return cursor.error_count;
}

bool CloudDriveSyncState::persist() {
    std::lock_guard<std::mutex> lock(*m_mutex);
    return saveState();
}

bool CloudDriveSyncState::recordTombstone(const std::string& itemType, const std::string& contentHash, std::int64_t tsMs) {
    std::lock_guard<std::mutex> lock(*m_mutex);

    for (const auto& t : m_tombstones) {
        if (t.item_type == itemType && t.content_hash == contentHash) {
            if (tsMs <= t.ts_ms) {
                return true;
            }
        }
    }

    Tombstone t;
    t.item_type = itemType;
    t.content_hash = contentHash;
    t.ts_ms = tsMs;
    m_tombstones.push_back(t);

    return saveState();
}

bool CloudDriveSyncState::shouldSkipUpsertDueToTombstone(const std::string& itemType,
                                                         const std::string& contentHash,
                                                         std::int64_t eventTsMs) const {
    std::lock_guard<std::mutex> lock(*m_mutex);

    for (const auto& t : m_tombstones) {
        if (t.item_type == itemType && t.content_hash == contentHash) {
            if (t.ts_ms >= eventTsMs) {
                return true;
            }
        }
    }

    return false;
}

bool CloudDriveSyncState::pruneForGc(std::int64_t nowMs, std::int64_t retentionMs, std::size_t maxTombstones) {
    std::lock_guard<std::mutex> lock(*m_mutex);
    bool changed = false;

    // 1. Prune tombstones by time
    const std::int64_t cutoffMs = nowMs - retentionMs;
    auto it = std::remove_if(m_tombstones.begin(), m_tombstones.end(), [cutoffMs](const Tombstone& t) {
        return t.ts_ms < cutoffMs;
    });
    if (it != m_tombstones.end()) {
        m_tombstones.erase(it, m_tombstones.end());
        changed = true;
    }

    // 2. Prune tombstones by count (keep newest)
    if (m_tombstones.size() > maxTombstones) {
        std::sort(m_tombstones.begin(), m_tombstones.end(), [](const Tombstone& a, const Tombstone& b) {
            return a.ts_ms > b.ts_ms; // Newest first
        });
        m_tombstones.erase(m_tombstones.begin() + maxTombstones, m_tombstones.end());
        changed = true;
    }

    // 3. Prune file cursors for missing files
    for (auto fileIt = m_fileCursors.begin(); fileIt != m_fileCursors.end(); ) {
        const std::string& path = fileIt->first;
        std::error_code ec;
        if (!std::filesystem::exists(path, ec) || ec) {
            fileIt = m_fileCursors.erase(fileIt);
            changed = true;
        } else {
            ++fileIt;
        }
    }

    if (changed) {
        PASTY_LOG_INFO("Core.SyncState", "State GC performed: %zu tombstones remaining", m_tombstones.size());
        return saveState();
    }

    return false;
}

} // namespace pasty
