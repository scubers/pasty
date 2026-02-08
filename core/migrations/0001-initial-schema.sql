CREATE TABLE IF NOT EXISTS items (
    id TEXT PRIMARY KEY,
    type TEXT NOT NULL,
    content TEXT,
    image_path TEXT,
    image_width INTEGER,
    image_height INTEGER,
    image_format TEXT,
    create_time_ms INTEGER NOT NULL,
    update_time_ms INTEGER NOT NULL,
    last_copy_time_ms INTEGER NOT NULL,
    source_app_id TEXT NOT NULL DEFAULT '',
    content_hash TEXT NOT NULL DEFAULT ''
);

CREATE INDEX IF NOT EXISTS idx_items_last_copy_time ON items(last_copy_time_ms DESC);
CREATE INDEX IF NOT EXISTS idx_items_type ON items(type);
CREATE UNIQUE INDEX IF NOT EXISTS idx_items_type_hash ON items(type, content_hash);

PRAGMA user_version = 1;
