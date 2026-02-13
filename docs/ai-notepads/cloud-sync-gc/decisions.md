
## Cloud Sync GC Decisions

- Sync directory GC uses existing `CloudDriveSyncPruner` (retention window + max events per device) to prune `logs/` and delete orphan `assets/` best-effort.
- Sync state GC prunes `sync_state.json` growth by removing stale file cursor entries for missing log files and capping tombstones (drop oldest) within the same retention window.
- Safety: GC is allowed to delete history beyond retention limits; importer/exporter must tolerate missing logs/assets/state entries without crashing.
- Robustness: importer must recover when `last_offset` becomes invalid (e.g., pruned/rewritten/truncated JSONL) by falling back to a safe offset and continuing line-by-line.
