#pragma once

#include <cstdint>
#include <string>
#include <unordered_map>
#include <vector>
#include <memory>
#include <mutex>
#include <optional>

namespace pasty {

/**
 * CloudDriveSyncState - Local sync state persistence for cloud drive sync
 *
 * This class manages the local sync state file (<baseDirectory>/sync_state.json)
 * which contains device_id, next_seq, per-device max_applied_seq, and per-file cursors.
 *
 * Schema version: 1
 * - Required fields: schema_version, device_id, next_seq
 * - Optional fields: devices (per-device max_applied_seq), files (per-file cursor/error_count)
 *
 * All operations are thread-safe and use atomic writes (temp + rename).
 * Corruption recovery: corrupted state files are backed up and recreated.
 */
class CloudDriveSyncState {
public:
    /**
     * Per-remote-device tracking state
     */
    struct RemoteDeviceState {
        std::uint64_t max_applied_seq = 0;
    };

    /**
     * Per-log-file cursor state
     */
    struct FileCursor {
        std::uint64_t last_offset = 0;
        int error_count = 0;
    };

    /**
     * Tombstone for preventing deletion resurrection
     *
     * Tombstones track items that have been deleted to prevent older
     * upsert events from re-inserting them.
     */
    struct Tombstone {
        std::string item_type;      // "text" or "image"
        std::string content_hash;    // 16-character lowercase hex
        std::int64_t ts_ms = 0;      // Timestamp of the delete event
    };

    /**
     * Load or create sync state from baseDirectory
     *
     * If sync_state.json exists and is valid, loads it.
     * If missing or corrupted, creates a new state with generated device_id.
     *
     * @param baseDirectory The base directory containing sync_state.json
     * @return CloudDriveSyncState instance, or std::nullopt on failure to create directory
     */
    static std::optional<CloudDriveSyncState> LoadOrCreate(const std::string& baseDirectory);

    // Getters
    std::string deviceId() const;
    std::uint64_t nextSeq() const;
    RemoteDeviceState getRemoteDeviceState(const std::string& deviceId) const;
    FileCursor getFileCursor(const std::string& filePath) const;

    // Mutating operations (persist on change)

    /**
     * Reserve next sequence number
     *
     * Increments next_seq atomically and persists to disk.
     *
     * @return The reserved sequence number
     */
    std::uint64_t reserveNextSeq();

    bool regenerateDeviceId();

    /**
     * Update per-remote-device max_applied_seq
     *
     * If newSeq > current max_applied_seq, updates and persists.
     *
     * @param remoteDeviceId The remote device ID
     * @param newSeq The new max applied sequence number
     * @return true if updated, false if no change or persist failed
     */
    bool updateRemoteDeviceMaxSeq(const std::string& remoteDeviceId, std::uint64_t newSeq);

    /**
     * Update per-file cursor
     *
     * Updates last_offset and persists.
     *
     * @param filePath The log file path (relative or absolute)
     * @param offset The new last_offset value
     * @return true if updated and persisted, false on failure
     */
    bool updateFileCursor(const std::string& filePath, std::uint64_t offset);

    /**
     * Increment per-file error count
     *
     * Increments error_count for a file and persists.
     *
     * @param filePath The log file path
     * @return The new error count
     */
    int incrementFileErrorCount(const std::string& filePath);

    /**
     * Force persist current state to disk
     *
     * @return true if persisted successfully, false on failure
     */
    bool persist();

    /**
     * Record a tombstone to prevent resurrection
     *
     * Stores a tombstone entry for (item_type, content_hash) with a cutoff timestamp.
     * Future upsert events older than this tombstone will be skipped.
     *
     * @param itemType The item type ("text" or "image")
     * @param contentHash The 16-character lowercase hex content hash
     * @param tsMs The timestamp of the delete event
     * @return true if recorded and persisted, false on failure
     */
    bool recordTombstone(const std::string& itemType, const std::string& contentHash, std::int64_t tsMs);

    /**
     * Check if an upsert should be skipped due to tombstone
     *
     * Returns true if there exists a tombstone for (itemType, contentHash) with
     * ts_ms >= eventTsMs (tombstone is newer or equal to the upsert).
     *
     * @param itemType The item type ("text" or "image")
     * @param contentHash The 16-character lowercase hex content hash
     * @param eventTsMs The timestamp of the upsert event being considered
     * @return true if upsert should be skipped (tombstone prevents resurrection), false otherwise
     */
    bool shouldSkipUpsertDueToTombstone(const std::string& itemType, const std::string& contentHash, std::int64_t eventTsMs) const;

    /**
     * Prune old state entries (GC)
     *
     * Removes stale file cursors for missing files and caps tombstones.
     *
     * @param nowMs Current timestamp in milliseconds
     * @param retentionMs Retention window in milliseconds
     * @param maxTombstones Maximum number of tombstones to retain
     * @return true if something was pruned and persisted successfully, false if no changes or persist failed
     */
    bool pruneForGc(std::int64_t nowMs, std::int64_t retentionMs, std::size_t maxTombstones);

private:
    CloudDriveSyncState();

    // Implementation details
    static std::string generateDeviceId();
    static std::string stateFilePath(const std::string& baseDirectory);
    static std::string backupCorruptedState(const std::string& stateFilePath);

    bool loadState(const std::string& statePath);
    bool createDefaultState(const std::string& baseDirectory);
    bool saveState() const;
    bool saveStateImpl(const std::string& statePath) const;

    std::string m_baseDirectory;
    std::string m_deviceId;
    std::uint64_t m_nextSeq = 1;

    std::unordered_map<std::string, RemoteDeviceState> m_remoteDevices;
    std::unordered_map<std::string, FileCursor> m_fileCursors;
    std::vector<Tombstone> m_tombstones;

    mutable std::shared_ptr<std::mutex> m_mutex;
};

} // namespace pasty
