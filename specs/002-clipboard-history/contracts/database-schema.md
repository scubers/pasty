# Database Schema Contract

**Feature**: 002-clipboard-history
**Date**: 2026-02-04
**Version**: 1.0

## Overview

This document defines the database schema contract for the clipboard history feature. It specifies the SQL schema, constraints, indexes, and expected behavior for database operations.

## Database Engine

- **Engine**: SQLite 3
- **File Location**: `~/Library/Application Support/Pasty/clipboard.db`
- **Journal Mode**: WAL (Write-Ahead Logging) for concurrent read/write
- **Synchronous**: NORMAL (balance between safety and performance)

## Schema Definition

### Table: clipboard_entries

Stores all clipboard history records with metadata.

```sql
CREATE TABLE IF NOT EXISTS clipboard_entries (
    -- Primary Key
    id TEXT PRIMARY KEY NOT NULL,

    -- Content identification
    content_hash TEXT NOT NULL UNIQUE,

    -- Content type classification
    content_type TEXT NOT NULL CHECK(content_type IN ('text', 'image')),

    -- Timestamps
    timestamp INTEGER NOT NULL,  -- Initial copy time
    latest_copy_time_ms INTEGER NOT NULL,  -- Most recent copy time

    -- Content storage (mutually exclusive based on content_type)
    text_content TEXT,
    image_path TEXT,

    -- Source application metadata
    source_bundle_id TEXT NOT NULL,
    source_app_name TEXT NOT NULL,
    source_pid INTEGER NOT NULL,

    -- Audit fields
    created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now') * 1000),
    updated_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now') * 1000),

    -- Constraints
    CHECK(
        (content_type = 'text' AND text_content IS NOT NULL AND image_path IS NULL) OR
        (content_type = 'image' AND image_path IS NOT NULL AND text_content IS NULL)
    )
);
```

#### Column Specifications

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | TEXT | PRIMARY KEY, NOT NULL | UUID v4 as 36-character string (e.g., "550e8400-e29b-41d4-a716-446655440000") |
| `content_hash` | TEXT | UNIQUE, NOT NULL | SHA-256 hash as 64-character hex string (e.g., "a1b2c3d4e5f6...") |
| `content_type` | TEXT | NOT NULL, CHECK IN ('text', 'image') | Type of clipboard content |
| `timestamp` | INTEGER | NOT NULL | Initial copy time - Unix timestamp in milliseconds (64-bit) |
| `latest_copy_time_ms` | INTEGER | NOT NULL | Most recent copy time - Unix timestamp in milliseconds (64-bit) |
| `text_content` | TEXT | NULL | Actual text content (UTF-8), NULL for image type |
| `image_path` | TEXT | NULL | Relative path to image file, NULL for text type |
| `source_bundle_id` | TEXT | NOT NULL | Bundle identifier of source app |
| `source_app_name` | TEXT | NOT NULL | Display name of source app |
| `source_pid` | INTEGER | NOT NULL | Process ID of source app |
| `created_at` | INTEGER | NOT NULL | Entry creation timestamp (ms) |
| `updated_at` | INTEGER | NOT NULL | Last update timestamp (ms) |

#### Indexes

```sql
-- Index for most-recent-first queries
CREATE INDEX IF NOT EXISTS idx_clipboard_entries_timestamp
ON clipboard_entries(timestamp DESC);

-- Index for duplicate detection (hash lookups)
CREATE INDEX IF NOT EXISTS idx_clipboard_entries_content_hash
ON clipboard_entries(content_hash);

-- Index for content type filtering
CREATE INDEX IF NOT EXISTS idx_clipboard_entries_content_type
ON clipboard_entries(content_type);

-- Composite index for filtered history queries
CREATE INDEX IF NOT EXISTS idx_clipboard_entries_type_timestamp
ON clipboard_entries(content_type, timestamp DESC);
```

**Index Rationale**:
- `idx_clipboard_entries_timestamp`: Supports `ORDER BY timestamp DESC` queries (history retrieval)
- `idx_clipboard_entries_content_hash`: Fast duplicate detection via hash lookup
- `idx_clipboard_entries_content_type`: Supports `WHERE content_type = ?` filtering
- `idx_clipboard_entries_type_timestamp`: Optimizes queries with both type filter and ordering

---

### Table: schema_version (Required)

Tracks database schema version and migration history.

```sql
CREATE TABLE IF NOT EXISTS schema_version (
    version INTEGER PRIMARY KEY NOT NULL,
    migration_date INTEGER NOT NULL,
    applied_migrations TEXT NOT NULL  -- JSON array: ["migration1", "migration2"]
);

-- Initialize with version 1 on first run
INSERT OR IGNORE INTO schema_version (version, migration_date, applied_migrations)
VALUES (1, strftime('%s', 'now') * 1000, '["initial_schema"]');

-- Set SQLite user_version pragma for quick version checks
PRAGMA user_version = 1;
```

**Column Specifications**:

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `version` | INTEGER | PRIMARY KEY, NOT NULL | Schema version number |
| `migration_date` | INTEGER | NOT NULL | Unix timestamp in milliseconds |
| `applied_migrations` | TEXT | NOT NULL | JSON array of migration names |

**Purpose**:
- Track current schema version for migration system
- Maintain audit trail of applied migrations
- Support rollback and upgrade scenarios

**Query - Get Current Version**:
```sql
-- Fast check via pragma
PRAGMA user_version;

-- Detailed check via table
SELECT version, migration_date, applied_migrations
FROM schema_version
ORDER BY version DESC
LIMIT 1;
```

**Query - Record Migration**:
```sql
INSERT INTO schema_version (version, migration_date, applied_migrations)
VALUES (?, ?, ?);
```

---

### Table: content_hashes (Optional)

Tracks unique content hashes for analytics and optimization.

```sql
CREATE TABLE IF NOT EXISTS content_hashes (
    hash_value TEXT PRIMARY KEY NOT NULL,
    algorithm TEXT NOT NULL DEFAULT 'sha256',
    first_seen INTEGER NOT NULL,
    reference_count INTEGER NOT NULL DEFAULT 1
);

CREATE INDEX IF NOT EXISTS idx_content_hashes_first_seen
ON content_hashes(first_seen DESC);
```

**Note**: This table is optional for initial implementation. Useful for:
- Analytics (most frequently copied content)
- Performance optimization (pre-check hash before full processing)
- Storage optimization (track duplicate frequency)

---

## Schema Versioning

### 1. Insert New Entry

```sql
INSERT INTO clipboard_entries (
    id,
    content_hash,
    content_type,
    timestamp,
    latest_copy_time_ms,
    text_content,
    image_path,
    source_bundle_id,
    source_app_name,
    source_pid,
    created_at,
    updated_at
) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
```

**Parameters** (in order):
1. `id`: UUID (TEXT)
2. `content_hash`: SHA-256 hex (TEXT)
3. `content_type`: 'text' or 'image' (TEXT)
4. `timestamp`: initial copy time in milliseconds (INTEGER)
5. `latest_copy_time_ms`: most recent copy time in milliseconds (INTEGER)
6. `text_content`: NULL for image (TEXT)
7. `image_path`: NULL for text (TEXT)
8. `source_bundle_id`: bundle identifier (TEXT)
9. `source_app_name`: app name (TEXT)
10. `source_pid`: process ID (INTEGER)
11. `created_at`: milliseconds (INTEGER)
12. `updated_at`: milliseconds (INTEGER)

**Error Handling**:
- UNIQUE constraint violation on `content_hash` → Entry already exists (duplicate)
- CHECK constraint violation → Invalid content_type or missing content field

---

### 2. Check for Duplicate by Hash

```sql
SELECT id, timestamp FROM clipboard_entries
WHERE content_hash = ?;
```

**Returns**:
- Empty result set → No duplicate (safe to insert)
- Single row → Duplicate exists (update timestamp instead)

---

### 3. Update Duplicate Timestamp

```sql
UPDATE clipboard_entries
SET latest_copy_time_ms = ?, updated_at = ?
WHERE content_hash = ?;
```

**Behavior**:
- Updates `latest_copy_time_ms` to most recent copy time
- Updates `updated_at` for audit trail
- Preserves original `timestamp` (initial copy time)

---

### 4. Retrieve Clipboard History (All Types)

```sql
SELECT
    id,
    content_hash,
    content_type,
    timestamp,
    text_content,
    image_path,
    source_bundle_id,
    source_app_name,
    source_pid
FROM clipboard_entries
ORDER BY timestamp DESC
LIMIT ? OFFSET ?;
```

**Parameters**:
1. `limit`: Maximum number of entries (INTEGER)
2. `offset`: Number of entries to skip (INTEGER)

**Use Case**: Retrieve recent clipboard history (most recent first)

---

### 5. Retrieve Clipboard History (Filtered by Type)

```sql
SELECT
    id,
    content_hash,
    content_type,
    timestamp,
    text_content,
    image_path,
    source_bundle_id,
    source_app_name,
    source_pid
FROM clipboard_entries
WHERE content_type = ?
ORDER BY timestamp DESC
LIMIT ? OFFSET ?;
```

**Parameters**:
1. `content_type`: 'text' or 'image' (TEXT)
2. `limit`: Maximum number of entries (INTEGER)
3. `offset`: Number of entries to skip (INTEGER)

**Use Case**: Retrieve only text or only image entries

---

### 6. Get Entry by ID

```sql
SELECT
    id,
    content_hash,
    content_type,
    timestamp,
    text_content,
    image_path,
    source_bundle_id,
    source_app_name,
    source_pid
FROM clipboard_entries
WHERE id = ?;
```

**Parameters**:
1. `id`: UUID (TEXT)

**Returns**:
- Single row if found
- Empty result set if not found

---

### 7. Delete Entry by ID

```sql
DELETE FROM clipboard_entries
WHERE id = ?;
```

**Parameters**:
1. `id`: UUID (TEXT)

**Returns**:
- Number of rows deleted (0 or 1)

**Note**: For image entries, caller must also delete the image file from disk.

---

### 8. Get Entry Count

```sql
SELECT COUNT(*) FROM clipboard_entries;
```

**Returns**:
- Total number of entries in database

**Variants**:
```sql
-- Count by type
SELECT COUNT(*) FROM clipboard_entries WHERE content_type = ?;

-- Count since timestamp
SELECT COUNT(*) FROM clipboard_entries WHERE timestamp > ?;
```

---

### 9. Clear All Entries

```sql
DELETE FROM clipboard_entries;
```

**Note**: For production use, consider:
1. Truncating table instead of deleting (faster): `DELETE FROM clipboard_entries;`
2. Resetting auto-increment (if using): `DELETE FROM sqlite_sequence WHERE name='clipboard_entries';`
3. Also deleting all image files from disk

---

### 10. Search Text Content (Future Feature)

```sql
SELECT
    id,
    content_hash,
    timestamp,
    text_content,
    source_app_name
FROM clipboard_entries
WHERE content_type = 'text'
  AND text_content LIKE ?
ORDER BY timestamp DESC
LIMIT ?;
```

**Parameters**:
1. `search_pattern`: Search term with wildcards (e.g., `%password%`)
2. `limit`: Maximum results (INTEGER)

**Note**: For production use, consider FTS5 (Full-Text Search) for better performance.

---

## Data Integrity

### Constraints Validation

The following constraints are enforced by the database:

1. **Primary Key**: `id` must be unique and non-null
2. **Unique Hash**: `content_hash` must be unique (prevents duplicates)
3. **Content Type**: Must be 'text' or 'image'
4. **Mutual Exclusivity**: Either `text_content` OR `image_path` must be non-null, not both

### Application-Level Validation

Additional validation performed by application code (not enforced by database):

1. **UUID Format**: `id` must be valid UUID v4 format
2. **Hash Format**: `content_hash` must be 64-character hex string
3. **Timestamp Range**: `timestamp` must be reasonable (not negative, not far in future)
4. **Non-Empty Fields**: `source_bundle_id`, `source_app_name` must be non-empty
5. **Valid PID**: `source_pid` must be positive integer

---

## Migration Strategy

### Version 1.0 → 1.1 (Example Future Migration)

**Scenario**: Add `is_favorite` flag for user-pinned entries

```sql
-- Step 1: Add new column
ALTER TABLE clipboard_entries ADD COLUMN is_favorite INTEGER NOT NULL DEFAULT 0;

-- Step 2: Create index for favorite queries
CREATE INDEX IF NOT EXISTS idx_clipboard_entries_favorite
ON clipboard_entries(is_favorite, timestamp DESC);

-- Step 3: Update user_version PRAGMA
PRAGMA user_version = 2;
```

### Migration Implementation Pattern

```rust
fn migrate(conn: &Connection, from_version: i32, to_version: i32) -> Result<()> {
    let transaction = conn.unchecked_transaction()?;

    for version in from_version..to_version {
        match version {
            1 => apply_migration_v1_to_v2(&transaction)?,
            2 => apply_migration_v2_to_v3(&transaction)?,
            _ => return Err(Error::InvalidMigrationVersion),
        }
    }

    transaction.commit()?;
    Ok(())
}
```

---

## Performance Considerations

### Query Optimization

1. **Use Prepared Statements**: Compile SQL once, execute many times
2. **Use Indexes**: All `WHERE`, `ORDER BY`, and JOIN columns should be indexed
3. **Use LIMIT**: Prevent large result sets from consuming memory
4. **Use EXPLAIN QUERY PLAN**: Verify index usage

**Example**:
```sql
EXPLAIN QUERY PLAN
SELECT * FROM clipboard_entries
WHERE content_type = 'text'
ORDER BY timestamp DESC
LIMIT 50;
-- Expected: Use idx_clipboard_entries_type_timestamp
```

### Transaction Batching

For bulk inserts, use transactions for performance:

```sql
BEGIN;
INSERT INTO clipboard_entries (...) VALUES (...);
INSERT INTO clipboard_entries (...) VALUES (...);
-- ... more inserts ...
COMMIT;
```

### Connection Pooling

For concurrent access, use a connection pool:

```rust
use r2d2::Pool;
use r2d2_sqlite::SqliteConnectionManager;

let manager = SqliteConnectionManager::file("clipboard.db");
let pool = Pool::new(manager).unwrap();
```

---

## Backup and Recovery

### Online Backup (SQLite Backup API)

```sql
-- Backup to another file while database is in use
.backup backup.db
```

### File System Backup

Simple file copy (requires closing database first):

```bash
cp ~/Library/Application\ Support/Pasty/clipboard.db ~/backup/
```

### Export to SQL

```sql
.output backup.sql
.dump
```

---

## Maintenance

### VACUUM

Reclaim unused space and defragment database:

```sql
VACUUM;
```

**Frequency**: Run weekly or monthly

### ANALYZE

Update query planner statistics:

```sql
ANALYZE;
```

**Frequency**: Run after significant data changes (inserts, deletes)

### Rebuild Indexes

Drop and recreate indexes for optimal performance:

```sql
DROP INDEX IF EXISTS idx_clipboard_entries_timestamp;
CREATE INDEX idx_clipboard_entries_timestamp ON clipboard_entries(timestamp DESC);
```

---

## Security Considerations

### File Permissions

Database file should have restrictive permissions:

```bash
chmod 600 ~/Library/Application\ Support/Pasty/clipboard.db
```

### Encryption at Rest

SQLite database can be encrypted using SQLCipher (not included in standard SQLite):

```bash
# Requires SQLCipher library
./configure --with-crypto-lib
make
```

**Note**: For macOS, system-level FileVault encryption provides sufficient protection for most use cases.

### SQL Injection Prevention

Always use parameterized queries (prepared statements):

```rust
// ✅ SAFE: Parameterized query
conn.execute(
    "INSERT INTO clipboard_entries (id, text_content) VALUES (?1, ?2)",
    params![id, text],
)?;

// ❌ UNSAFE: String concatenation
conn.execute(&format!(
    "INSERT INTO clipboard_entries (id, text_content) VALUES ('{}', '{}')",
    id, text
),)?;
```

---

## Testing

### Unit Tests

Test database operations in isolation:

```rust
#[cfg(test)]
mod tests {
    use super::*;

    fn setup_test_db() -> Connection {
        let conn = Connection::open_in_memory().unwrap();
        initialize_schema(&conn).unwrap();
        conn
    }

    #[test]
    fn test_insert_and_retrieve() {
        let conn = setup_test_db();
        let entry = create_test_entry();

        insert_entry(&conn, &entry).unwrap();
        let retrieved = get_entry_by_id(&conn, &entry.id).unwrap();

        assert_eq!(entry.id, retrieved.id);
        assert_eq!(entry.content_hash, retrieved.content_hash);
    }

    #[test]
    fn test_duplicate_detection() {
        let conn = setup_test_db();
        let entry = create_test_entry();

        insert_entry(&conn, &entry).unwrap();
        let result = insert_entry(&conn, &entry);

        assert!(matches!(result, Err(Error::DuplicateHash)));
    }
}
```

### Integration Tests

Test database operations with real file:

```rust
#[test]
fn test_persistence_across_connections() {
    let db_path = ":memory:";
    let conn1 = Connection::open(db_path).unwrap();
    let conn2 = Connection::open(db_path).unwrap();

    initialize_schema(&conn1).unwrap();

    let entry = create_test_entry();
    insert_entry(&conn1, &entry).unwrap();

    let retrieved = get_entry_by_id(&conn2, &entry.id).unwrap();
    assert_eq!(entry.id, retrieved.id);
}
```

---

## Summary

This database schema contract provides:

- ✅ Complete SQL schema definition
- ✅ Clear column specifications and constraints
- ✅ Optimized indexes for common query patterns
- ✅ Query patterns for all database operations
- ✅ Data integrity rules (database and application-level)
- ✅ Migration strategy for schema evolution
- ✅ Performance optimization guidelines
- ✅ Security best practices
- ✅ Backup and recovery procedures
- ✅ Testing strategies
