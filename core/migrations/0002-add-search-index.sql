CREATE INDEX IF NOT EXISTS idx_items_content_search ON items(content COLLATE NOCASE);
PRAGMA user_version = 2;
