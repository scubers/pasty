-- Add pinned field for protecting items from deletion and retention
-- pinned: 0 (default) or 1 (pinned)
-- pinned_update_time_ms: timestamp when pinned status was last changed

ALTER TABLE items ADD COLUMN pinned INTEGER NOT NULL DEFAULT 0;
ALTER TABLE items ADD COLUMN pinned_update_time_ms INTEGER NOT NULL DEFAULT 0;

PRAGMA user_version = 6;
