-- Rollback migration 001
DROP INDEX IF EXISTS idx_clipboard_entries_type_timestamp;
DROP INDEX IF EXISTS idx_clipboard_entries_content_type;
DROP INDEX IF EXISTS idx_clipboard_entries_content_hash;
DROP INDEX IF EXISTS idx_clipboard_entries_timestamp;
DROP TABLE IF EXISTS clipboard_entries;
DROP TABLE IF EXISTS schema_version;
PRAGMA user_version = 0;
