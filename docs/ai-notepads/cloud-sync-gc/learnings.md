
- Cloud Sync GC is hooked into `CoreRuntime::runCloudSyncImport()`.
- GC cadence is set to 24 hours (86,400,000 ms).
- It uses `CloudDriveSyncPruner` to prune logs and assets.
- State GC is implemented in `CloudDriveSyncState::pruneForGc` and called during every import run.
- State GC prunes tombstones by time (180 days) and count (capped at 5000), and removes cursors for missing log files.
