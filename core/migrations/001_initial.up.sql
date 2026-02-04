-- Clipboard entries table
CREATE TABLE IF NOT EXISTS clipboard_entries (
    id TEXT PRIMARY KEY NOT NULL,
    content_hash TEXT NOT NULL UNIQUE,
    content_type TEXT NOT NULL CHECK(content_type IN ('text', 'image')),
    timestamp INTEGER NOT NULL,
    latest_copy_time_ms INTEGER NOT NULL,
    text_content TEXT,
    image_path TEXT,
    source_bundle_id TEXT NOT NULL,
    source_app_name TEXT NOT NULL,
    source_pid INTEGER NOT NULL,
    created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now') * 1000),
    updated_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now') * 1000),
    CHECK(
        (content_type = 'text' AND text_content IS NOT NULL AND image_path IS NULL) OR
        (content_type = 'image' AND image_path IS NOT NULL AND text_content IS NULL)
    )
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_clipboard_entries_timestamp ON clipboard_entries(timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_clipboard_entries_content_hash ON clipboard_entries(content_hash);
CREATE INDEX IF NOT EXISTS idx_clipboard_entries_content_type ON clipboard_entries(content_type);
CREATE INDEX IF NOT EXISTS idx_clipboard_entries_type_timestamp ON clipboard_entries(content_type, timestamp DESC);

-- Schema version tracking
CREATE TABLE IF NOT EXISTS schema_version (
    version INTEGER PRIMARY KEY NOT NULL,
    migration_date INTEGER NOT NULL,
    applied_migrations TEXT NOT NULL
);

INSERT INTO schema_version (version, migration_date, applied_migrations)
VALUES (1, strftime('%s', 'now') * 1000, '["initial_schema"]');

-- Set user_version pragma for quick version checks
PRAGMA user_version = 1;
