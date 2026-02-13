#pragma once

#include "history/clipboard_history_types.h"
#include "infrastructure/crypto/encryption_manager.h"
#include "infrastructure/sync/cloud_drive_sync_state.h"

#include <cstdint>
#include <string>
#include <vector>
#include <memory>
#include <optional>

namespace pasty {

/**
 * CloudDriveSyncExporter - Exports local clipboard changes to cloud-sync directory
 *
 * This class writes clipboard history changes to the sync_root directory as JSONL events
 * following the cloud drive sync protocol. It handles:
 * - Text upsert events with inline content
 * - Image upsert events with separate asset files
 * - Delete tombstone events
 * - Log file rotation at 10 MiB
 * - Atomic asset writes (temp + rename)
 * - Loop prevention (skips events from pasty-sync: sourceAppId)
 * - Size caps (25 MiB images, 1 MiB event lines)
 *
 * Thread-safety: Not thread-safe; caller must ensure synchronization.
 */
class CloudDriveSyncExporter {
public:
    CloudDriveSyncExporter(const CloudDriveSyncExporter&) = delete;
    CloudDriveSyncExporter& operator=(const CloudDriveSyncExporter&) = delete;
    CloudDriveSyncExporter(CloudDriveSyncExporter&&) noexcept = default;
    CloudDriveSyncExporter& operator=(CloudDriveSyncExporter&&) noexcept = default;
    ~CloudDriveSyncExporter();

    /**
     * Export result status
     */
    enum class ExportResult {
        Success,
        SkippedLoopPrevention,
        SkippedImageTooLarge,
        SkippedEventTooLarge,
        SyncNotConfigured,
        ExportFailed
    };

    /**
     * Create a configured exporter instance
     *
     * @param syncRootPath Path to cloud sync root directory (e.g., iCloud Drive/Pasty)
     * @param baseDirectory Local base directory for state file (sync_state.json)
     * @return Configured exporter instance, or nullopt on failure
     */
    static std::optional<CloudDriveSyncExporter> Create(
        const std::string& syncRootPath,
        const std::string& baseDirectory,
        const std::optional<EncryptionManager::Key>& e2eeMasterKey = std::nullopt,
        const std::string& e2eeKeyId = std::string());

    void setE2eeKey(const EncryptionManager::Key& masterKey, const std::string& keyId);
    void clearE2eeKey();

    /**
     * Export a text clipboard item
     *
     * Writes a JSONL upsert_text event to the log file.
     * Skips if sourceAppId starts with "pasty-sync:".
     * Skips if JSONL line would exceed 1 MiB.
     *
     * @param item The clipboard history item to export
     * @return Export result status
     */
    ExportResult exportTextItem(const ClipboardHistoryItem& item);

    /**
     * Export an image clipboard item
     *
     * Writes a JSONL upsert_image event and asset file.
     * Skips if sourceAppId starts with "pasty-sync:".
     * Skips if image bytes > 25 MiB.
     * Skips if JSONL line would exceed 1 MiB.
     * Asset written atomically as <content_hash>.<ext>
     *
     * @param item The clipboard history item to export
     * @param imageBytes The image binary data
     * @return Export result status
     */
    ExportResult exportImageItem(const ClipboardHistoryItem& item, const std::vector<std::uint8_t>& imageBytes);

    /**
     * Export a delete tombstone
     *
     * Writes a JSONL delete event targeting (item_type, content_hash).
     *
     * @param itemType The item type being deleted ("text" or "image")
     * @param contentHash The content hash of the deleted item
     * @return Export result status
     */
    ExportResult exportDeleteTombstone(ClipboardItemType itemType, const std::string& contentHash);

    /**
     * Check if sync is configured and enabled
     *
     * @return true if sync_root is configured and writable
     */
    bool isConfigured() const;

private:
    CloudDriveSyncExporter();
    
    // Internal helpers
    bool initialize(const std::string& syncRootPath, const std::string& baseDirectory);
    ExportResult writeJsonlEvent(const std::string& jsonLine);
    bool ensureDirectoryStructure();
    std::string getCurrentLogFilePath() const;
    std::string getNextLogFilePath() const;
    bool rotateLogFileIfNeeded(std::size_t lineLength);
    bool writeAssetAtomically(const std::string& assetKey, const std::vector<std::uint8_t>& bytes);
    
    // Constants
    static constexpr std::uint64_t kMaxImageBytes = 26214400;       // 25 MiB
    static constexpr std::uint64_t kMaxEventLineBytes = 1048576;    // 1 MiB
    static constexpr std::uint64_t kLogFileRotationBytes = 10485760; // 10 MiB
    static constexpr int kSchemaVersion = 1;
    static constexpr const char* kLoopPrefix = "pasty-sync:";

    std::string m_syncRootPath;
    std::string m_logsPath;
    std::string m_metaPath;
    std::string m_assetsPath;
    std::string m_deviceLogsPath;
    std::uint32_t m_currentLogFileIndex;
    
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

        std::uint64_t reserveNextSeq() {
            if (state) {
                return state->reserveNextSeq();
            }
            return 0;
        }

        bool incrementFileErrorCount(const std::string& filePath) {
            if (state) {
                state->incrementFileErrorCount(filePath);
                return true;
            }
            return false;
        }
    };
    std::unique_ptr<StateManager> m_stateManager;

    std::optional<EncryptionManager::Key> m_e2eeMasterKey;
    std::string m_e2eeKeyId;
    
    bool m_initialized;
};

} // namespace pasty
