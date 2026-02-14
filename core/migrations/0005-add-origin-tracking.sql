-- Add origin tracking fields for cloud sync support
-- origin_type: 'local_copy' (default) or 'cloud_sync'
-- origin_device_id: device ID for cloud-synced items, null for local

ALTER TABLE items ADD COLUMN origin_type TEXT NOT NULL DEFAULT 'local_copy';
ALTER TABLE items ADD COLUMN origin_device_id TEXT;

PRAGMA user_version = 5;
