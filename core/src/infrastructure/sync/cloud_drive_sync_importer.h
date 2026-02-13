// Pasty - Copyright (c) 2026. MIT License.

#pragma once

#include "history/clipboard_history_types.h"
#include "infrastructure/crypto/encryption_manager.h"
#include "infrastructure/sync/cloud_drive_sync_state.h"

#include <cstdint>
#include <memory>
#include <optional>
#include <string>
#include <vector>

namespace pasty {

// Forward declaration to avoid circular dependency
class ClipboardService;

/**
 * CloudDriveSyncImporter - Imports remote clipboard changes from cloud-sync directory
 *
 * This class reads clipboard history changes from sync_root directory as JSONL events
 * following the cloud drive sync protocol. It handles:
 * - Scanning logs/<device_id>/events-*.jsonl for remote devices
 * - Incremental parsing using CloudDriveSyncState (max_applied_seq, file cursors)
 * - Deterministic merge ordering by (ts_ms, device_id, seq)
 * - Upsert text (inline content) to local history
 * - Upsert image (read asset file) to local history
 * - Delete tombstones (delete by type + content_hash)
 * - Robust error handling (skip malformed/truncated lines)
 * - Forward compatibility (ignore unknown fields, skip unknown operations)
 *
 * Thread-safety: Not thread-safe; caller must ensure synchronization.
 */
class CloudDriveSyncImporter {
public:
    CloudDriveSyncImporter(const CloudDriveSyncImporter&) = delete;
    CloudDriveSyncImporter& operator=(const CloudDriveSyncImporter&) = delete;
    CloudDriveSyncImporter(CloudDriveSyncImporter&&) noexcept = default;
    CloudDriveSyncImporter& operator=(CloudDriveSyncImporter&&) noexcept = default;
    ~CloudDriveSyncImporter();

    /**
     * Import result statistics
     */
    struct ImportResult {
        int eventsProcessed = 0;
        int eventsApplied = 0;
        int eventsSkipped = 0;
        int errors = 0;
        bool success = false;
    };

    /**
     * Create a configured importer instance
     *
     * @param syncRootPath Path to cloud sync root directory (e.g., iCloud Drive/Pasty)
     * @param baseDirectory Local base directory for state file (sync_state.json)
     * @return Configured importer instance, or nullopt on failure
     */
    static std::optional<CloudDriveSyncImporter> Create(
        const std::string& syncRootPath,
        const std::string& baseDirectory,
        const std::optional<EncryptionManager::Key>& e2eeMasterKey = std::nullopt,
        const std::string& e2eeKeyId = std::string());

    void setE2eeKey(const EncryptionManager::Key& masterKey, const std::string& keyId);
    void clearE2eeKey();

    /**
     * Import changes from remote devices
     *
     * Scans sync_root/logs/<device_dir>/events-*.jsonl for remote devices (excluding local device),
     * parses new events using state cursors, sorts deterministically, and applies
     * to local history via ClipboardService.
     *
     * Events with seq <= max_applied_seq for a device are skipped.
     * File cursors (last_offset) are used to resume reading partially-read files.
     * State is updated after successful application.
     *
     * @param clipboardService The ClipboardService to apply changes to
     * @return Import result statistics
     */
    ImportResult importChanges(ClipboardService& clipboardService);

    /**
     * Check if sync is configured and enabled
     *
     * @return true if sync_root is configured and readable
     */
    bool isConfigured() const;

private:
    CloudDriveSyncImporter();

    bool initialize(const std::string& syncRootPath, const std::string& baseDirectory);
    
    // Parsed event for sorting and application
    struct ParsedEvent {
        std::string deviceId;
        std::uint64_t seq;
        std::int64_t tsMs;
        std::string eventId;
        std::string op;
        std::string itemType;
        std::string contentHash;
        
        // For upsert_text
        std::string text;
        std::string contentType;
        bool skipDueToMissingKey = false;
        
        // For upsert_image
        std::string assetKey;
        std::int32_t imageWidth = 0;
        std::int32_t imageHeight = 0;
        
        // Optional fields (forward compat)
        std::string sourceAppId;
        
        // Sorting for deterministic merge
        bool operator<(const ParsedEvent& other) const {
            if (tsMs != other.tsMs) return tsMs < other.tsMs;
            if (deviceId != other.deviceId) return deviceId < other.deviceId;
            return seq < other.seq;
        }
    };
    
    // Scanning
    std::vector<std::string> enumerateRemoteDeviceLogDirectories() const;
    std::vector<std::string> enumerateJsonlFiles(const std::string& deviceLogsPath) const;
    
    // Parsing
    bool parseJsonlFile(const std::string& filePath, const std::string& remoteDeviceId, std::vector<ParsedEvent>& events);
    bool parseEvent(const std::string& line, const std::string& filePath, std::uint64_t lineOffset, ParsedEvent& event);
    
    // Asset reading
    std::optional<std::vector<std::uint8_t>> readAssetFile(const std::string& assetKey) const;
    
    // Application
    ImportResult applyEvents(std::vector<ParsedEvent>& events, ClipboardService& clipboardService);
    bool applyUpsertText(const ParsedEvent& event, ClipboardService& clipboardService);
    bool applyUpsertImage(const ParsedEvent& event, ClipboardService& clipboardService);
    bool applyDelete(const ParsedEvent& event, ClipboardService& clipboardService);
    
    // Constants
    static constexpr int kSchemaVersion = 1;
    static constexpr const char* kLoopPrefix = "pasty-sync:";
    static constexpr std::uint64_t kMaxAssetBytes = 26214400; // 25 MiB
    
    std::string m_syncRootPath;
    std::string m_logsPath;
    std::string m_assetsPath;
    
    // State management (holds reference to CloudDriveSyncState)
    class StateManager {
    public:
        std::optional<CloudDriveSyncState> state;

        explicit StateManager(std::optional<CloudDriveSyncState> s)
            : state(std::move(s)) {
        }

        std::string deviceId() const {
            if (state) {
                return state->deviceId();
            }
            return std::string();
        }

        CloudDriveSyncState::RemoteDeviceState getRemoteDeviceState(const std::string& deviceId) const {
            if (state) {
                return state->getRemoteDeviceState(deviceId);
            }
            return CloudDriveSyncState::RemoteDeviceState();
        }

        CloudDriveSyncState::FileCursor getFileCursor(const std::string& filePath) const {
            if (state) {
                return state->getFileCursor(filePath);
            }
            return CloudDriveSyncState::FileCursor();
        }

        bool updateRemoteDeviceMaxSeq(const std::string& remoteDeviceId, std::uint64_t newSeq) {
            if (state) {
                return state->updateRemoteDeviceMaxSeq(remoteDeviceId, newSeq);
            }
            return false;
        }

        bool updateFileCursor(const std::string& filePath, std::uint64_t offset) {
            if (state) {
                return state->updateFileCursor(filePath, offset);
            }
            return false;
        }

        int incrementFileErrorCount(const std::string& filePath) {
            if (state) {
                return state->incrementFileErrorCount(filePath);
            }
            return 0;
        }

        bool recordTombstone(const std::string& itemType, const std::string& contentHash, std::int64_t tsMs) {
            if (state) {
                return state->recordTombstone(itemType, contentHash, tsMs);
            }
            return false;
        }

        bool shouldSkipUpsertDueToTombstone(const std::string& itemType, const std::string& contentHash, std::int64_t eventTsMs) const {
            if (state) {
                return state->shouldSkipUpsertDueToTombstone(itemType, contentHash, eventTsMs);
            }
            return false;
        }

        bool pruneForGc(std::int64_t nowMs, std::int64_t retentionMs, std::size_t maxTombstones) {
            if (state) {
                return state->pruneForGc(nowMs, retentionMs, maxTombstones);
            }
            return false;
        }
    };
    std::unique_ptr<StateManager> m_stateManager;

    bool m_protocolE2eeEnabled;
    std::string m_protocolE2eeKeyId;
    std::optional<EncryptionManager::Key> m_e2eeMasterKey;
    std::string m_e2eeKeyId;
    
    bool m_initialized;
};

} // namespace pasty
