// Pasty - Copyright (c) 2026. MIT License.

#pragma once

#include <cstdint>
#include <string>
#include <vector>
#include <set>

namespace pasty {

/**
 * CloudDriveSyncPruner - Prunes cloud-sync directory based on retention policy
 *
 * This class manages cleanup of old events and unreferenced assets from the cloud-sync
 * directory following the cloud drive sync protocol. It handles:
 * - Pruning log files older than retention window (default: 180 days)
 * - Enforcing maximum event count per device (default: 5000 events)
 * - Safe deletion of oldest rotated log files first
 * - Removing orphaned assets not referenced by retained events
 * - Conservative, error-resilient operation (logs errors, continues)
 *
 * Thread-safety: Not thread-safe; caller must ensure synchronization.
 */
class CloudDriveSyncPruner {
public:
    /**
     * Prune result statistics
     */
    struct PruneResult {
        int logFilesDeleted = 0;
        int assetsDeleted = 0;
        int eventsRetained = 0;
        int eventsPruned = 0;
        int devicesProcessed = 0;
        bool success = false;
        std::string errorMessage;
    };

    /**
     * Default retention window: 180 days in milliseconds
     */
    static constexpr std::int64_t kDefaultRetentionMs = 180LL * 24 * 60 * 60 * 1000;

    /**
     * Default maximum events per device
     */
    static constexpr int kDefaultMaxEventsPerDevice = 5000;

    /**
     * Prune the sync directory based on retention policy
     *
     * This method:
     * 1. Scans logs/<device_id>/ directories
     * 2. For each device, counts events across all jsonl files
     * 3. Determines which log files to delete to meet retention policy
     * 4. Deletes oldest rotated files (events-0001, events-0002...) first
     * 5. Collects all asset_key references from retained events
     * 6. Deletes unreferenced assets in assets/ directory
     *
     * Safety guarantees:
     * - Failures are logged but don't crash
     * - Pruning is conservative: only deletes whole log files
     * - Assets are only deleted if unreferenced by ANY retained event
     * - Tombstones are retained within window (prevents delete resurrection)
     *
     * @param syncRootPath Path to cloud sync root directory
     * @param nowMs Current timestamp in milliseconds (for retention calculation)
     * @param retentionMs Retention window in milliseconds (default: 180 days)
     * @param maxEventsPerDevice Maximum events to keep per device (default: 5000)
     * @return Prune result statistics
     */
    PruneResult prune(const std::string& syncRootPath, std::int64_t nowMs,
                      std::int64_t retentionMs = kDefaultRetentionMs,
                      int maxEventsPerDevice = kDefaultMaxEventsPerDevice);

private:
    /**
     * Event metadata for retention calculation
     */
    struct EventInfo {
        std::string filePath;
        std::uint64_t seq;
        std::int64_t tsMs;
        std::string assetKey;  // Non-empty only for upsert_image
        int lineNumber;        // For rewriting boundary files if needed
    };

    /**
     * Device event summary for pruning decisions
     */
    struct DeviceEventSummary {
        std::string deviceId;
        std::vector<EventInfo> events;  // Sorted by (tsMs, seq) for chronological order
        std::vector<std::string> logFiles;  // All log files in sorted order

        int countEventsOlderThan(std::int64_t cutoffMs) const;
    };

    /**
     * Collect all events for a device
     */
    bool collectDeviceEvents(const std::string& deviceLogsPath, DeviceEventSummary& summary,
                             std::int64_t cutoffMs, std::set<std::string>& allReferencedAssets);

    /**
     * Pruning action for a log file
     */
    struct FileAction {
        std::string filePath;
        std::set<int> lineNumbersToKeep;
        std::set<std::string> assetKeysToKeep;
    };

    /**
     * Determine pruning actions for a device
     *
     * Returns list of actions: delete or rewrite with line numbers to keep
     */
    std::vector<FileAction> determinePruningActions(const DeviceEventSummary& summary,
                                                      std::int64_t cutoffMs,
                                                      int maxEvents,
                                                      int& eventsRetained,
                                                      int& eventsPruned);

    /**
     * Parse a JSONL file and extract event metadata
     *
     * Reuses parsing patterns from CloudDriveSyncImporter (parse with nullptr, false)
     * Skips invalid/malformed lines but continues processing
     */
    bool parseJsonlFileForMetadata(const std::string& filePath,
                                     std::vector<EventInfo>& events);

    /**
     * Rewrite boundary file keeping only retained lines
     *
     * Uses atomic write pattern: write to .tmp then rename
     */
    bool rewriteBoundaryFile(const std::string& filePath, const std::set<int>& lineNumbersToKeep, int& linesWritten);

    /**
     * Delete unreferenced assets from assets/ directory
     *
     * Assets are deleted only if:
     * - Not in allReferencedAssets
     * - File exists
     * - Deletion succeeds (logged on failure)
     */
    int pruneUnreferencedAssets(const std::string& assetsPath,
                                 const std::set<std::string>& allReferencedAssets,
                                 std::int64_t cutoffMs);

    /**
     * Enumerate log files for a device directory
     *
     * Returns sorted list of events-####.jsonl files
     */
    std::vector<std::string> enumerateDeviceLogFiles(const std::string& deviceLogsPath) const;

    /**
     * Check if a file path matches the events-####.jsonl pattern
     */
    bool isEventsJsonlFile(const std::string& filename) const;

    /**
     * Validate content hash (16 hex characters)
     */
    bool validateContentHash(const std::string& hash) const;
};

} // namespace pasty
