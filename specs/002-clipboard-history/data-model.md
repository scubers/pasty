# Data Model: Clipboard History Manager

**Feature**: 002-clipboard-history
**Date**: 2026-02-04
**Status**: Complete

## Overview

This document defines the data model for the clipboard history feature, including database schema, Rust struct definitions, and Swift model mappings. The model supports text and image clipboard entries with deduplication via content hashing, tracks both initial and latest copy times, and includes database versioning for migrations.

## Entity Relationship Diagram

```
┌─────────────────────┐
│  ClipboardEntry     │
├─────────────────────┤
│ id (PK)             │───┐
│ content_hash        │   │
│ content_type        │   │
│ timestamp           │   │
│ latest_copy_time_ms │   │
│ text_content        │   │
│ image_path          │   │
│ source_bundle_id    │   │
│ source_app_name     │   │
│ source_pid          │   │
└─────────────────────┘   │
                          │
                          │ References
                          │
                          │
┌─────────────────────┐   │
│  ContentHash        │   │
├─────────────────────┤   │
│ hash_value (unique) │◄──┘
│ algorithm           │
│ created_at          │
└─────────────────────┘

┌─────────────────────┐
│  ImageFile          │
├─────────────────────┤
│ file_path           │
│ file_size           │
│ width               │
│ height              │
│ format              │
│ created_at          │
└─────────────────────┘

┌─────────────────────┐
│  DatabaseVersion    │
├─────────────────────┤
│ version (PK)        │
│ migration_date      │
│ applied_migrations  │
└─────────────────────┘
```

## Database Schema

### Table: clipboard_entries

Stores all clipboard history records with metadata.

```sql
CREATE TABLE clipboard_entries (
    -- Primary key
    id TEXT PRIMARY KEY NOT NULL,  -- UUID as text

    -- Content identification
    content_hash TEXT NOT NULL UNIQUE,  -- SHA-256 hex string

    -- Content type classification
    content_type TEXT NOT NULL,  -- 'text' or 'image'

    -- Timestamps
    timestamp INTEGER NOT NULL,  -- Initial copy time (Unix timestamp in milliseconds)
    latest_copy_time_ms INTEGER NOT NULL,  -- Most recent copy time (for duplicates)

    -- Content storage (mutually exclusive based on content_type)
    text_content TEXT,           -- NULL for image type
    image_path TEXT,             -- NULL for text type

    -- Source application metadata
    source_bundle_id TEXT NOT NULL,
    source_app_name TEXT NOT NULL,
    source_pid INTEGER NOT NULL,

    -- Metadata
    created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now') * 1000),
    updated_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now') * 1000)
);

-- Indexes for performance
CREATE INDEX idx_clipboard_entries_timestamp ON clipboard_entries(timestamp DESC);
CREATE INDEX idx_clipboard_entries_content_hash ON clipboard_entries(content_hash);
CREATE INDEX idx_clipboard_entries_content_type ON clipboard_entries(content_type);
```

**Constraints**:
- `id` is unique UUID (enforced by PRIMARY KEY)
- `content_hash` is unique (enforced by UNIQUE constraint) - enables deduplication
- Either `text_content` or `image_path` must be non-NULL (CHECK constraint not enforced by SQLite, validated in application logic)
- `timestamp` is indexed for efficient history retrieval (DESC order for most-recent-first queries)
- `content_type` is indexed for filtering by type

### Table: content_hashes (Optional for Future Use)

Tracks unique content hashes for analytics and optimization.

```sql
CREATE TABLE content_hashes (
    hash_value TEXT PRIMARY KEY NOT NULL,  -- SHA-256 hex string
    algorithm TEXT NOT NULL DEFAULT 'sha256',
    first_seen INTEGER NOT NULL,  -- Unix timestamp in milliseconds
    reference_count INTEGER NOT NULL DEFAULT 1
);

-- Index for finding hash statistics
CREATE INDEX idx_content_hashes_first_seen ON content_hashes(first_seen DESC);
```

**Note**: This table is optional for the initial implementation. Useful for:
- Tracking hash frequency (how often same content is copied)
- Analytics (most common clipboard items)
- Future optimization: Pre-check hash before processing

## Rust Data Structures

### ClipboardEntry Model

```rust
use serde::{Deserialize, Serialize};
use uuid::Uuid;
use chrono::{DateTime, Utc};

/// Represents a single clipboard history entry
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ClipboardEntry {
    /// Unique identifier (UUID)
    pub id: Uuid,

    /// Content hash (SHA-256) for deduplication
    pub content_hash: String,

    /// Type of clipboard content
    pub content_type: ContentType,

    /// Initial timestamp when content was first copied (milliseconds since Unix epoch)
    pub timestamp: DateTime<Utc>,

    /// Most recent timestamp when same content was copied again (milliseconds)
    pub latest_copy_time_ms: DateTime<Utc>,

    /// Actual content (text or image reference)
    pub content: Content,

    /// Application that provided the clipboard content
    pub source: SourceApplication,
}

impl ClipboardEntry {
    /// Create a new clipboard entry with generated ID
    pub fn new(
        content_hash: String,
        content_type: ContentType,
        content: Content,
        source: SourceApplication,
    ) -> Self {
        let now = Utc::now();
        Self {
            id: Uuid::new_v4(),
            content_hash,
            content_type,
            timestamp: now,
            latest_copy_time_ms: now,
            content,
            source,
        }
    }

    /// Update latest_copy_time_ms (for duplicate detection)
    pub fn update_latest_copy_time(&mut self) {
        self.latest_copy_time_ms = Utc::now();
    }
}

/// Content type classification
#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
pub enum ContentType {
    Text,
    Image,
}

impl ContentType {
    pub fn as_str(&self) -> &'static str {
        match self {
            ContentType::Text => "text",
            ContentType::Image => "image",
        }
    }

    pub fn from_str(s: &str) -> Option<Self> {
        match s {
            "text" => Some(ContentType::Text),
            "image" => Some(ContentType::Image),
            _ => None,
        }
    }
}

/// Clipboard content (text or image)
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum Content {
    Text(String),
    Image(ImageFile),
}

impl Content {
    /// Get content type
    pub fn content_type(&self) -> ContentType {
        match self {
            Content::Text(_) => ContentType::Text,
            Content::Image(_) => ContentType::Image,
        }
    }
}
```

### SourceApplication Model

```rust
/// Metadata about the application that provided clipboard content
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SourceApplication {
    /// Bundle identifier (e.g., "com.apple.Safari")
    pub bundle_id: String,

    /// Application display name (e.g., "Safari")
    pub app_name: String,

    /// Process ID (may be stale if app terminated)
    pub pid: u32,
}

impl SourceApplication {
    pub fn new(bundle_id: String, app_name: String, pid: u32) -> Self {
        Self {
            bundle_id,
            app_name,
            pid,
        }
    }
}
```

### ImageFile Model

```rust
/// Metadata for image file stored on disk
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ImageFile {
    /// Relative path to image file (hash-based filename)
    pub path: String,

    /// File size in bytes
    pub size: u64,

    /// Image dimensions (if available)
    pub dimensions: Option<ImageDimensions>,

    /// Image format (PNG, JPEG, etc.)
    pub format: ImageFormat,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ImageDimensions {
    pub width: u32,
    pub height: u32,
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize)]
pub enum ImageFormat {
    Png,
    Jpeg,
    Gif,
    Tiff,
    Bmp,
    Unknown,
}

impl ImageFormat {
    pub fn from_extension(ext: &str) -> Self {
        match ext.to_lowercase().as_str() {
            "png" => ImageFormat::Png,
            "jpg" | "jpeg" => ImageFormat::Jpeg,
            "gif" => ImageFormat::Gif,
            "tiff" | "tif" => ImageFormat::Tiff,
            "bmp" => ImageFormat::Bmp,
            _ => ImageFormat::Unknown,
        }
    }

    pub fn extension(&self) -> &'static str {
        match self {
            ImageFormat::Png => "png",
            ImageFormat::Jpeg => "jpg",
            ImageFormat::Gif => "gif",
            ImageFormat::Tiff => "tiff",
            ImageFormat::Bmp => "bmp",
            ImageFormat::Unknown => "dat",
        }
    }

    pub fn as_str(&self) -> &'static str {
        match self {
            ImageFormat::Png => "png",
            ImageFormat::Jpeg => "jpeg",
            ImageFormat::Gif => "gif",
            ImageFormat::Tiff => "tiff",
            ImageFormat::Bmp => "bmp",
            ImageFormat::Unknown => "unknown",
        }
    }
}
```

### Database Row Mapping

```rust
use rusqlite::{Row, Rows, types::FromSql};

impl ClipboardEntry {
    /// Construct ClipboardEntry from database row
    pub fn from_row(row: &Row) -> Result<Self, rusqlite::Error> {
        let content_type_str: String = row.get("content_type")?;
        let content_type = ContentType::from_str(&content_type_str)
            .ok_or_else(|| rusqlite::Error::InvalidQuery)?;

        let text_content: Option<String> = row.get("text_content")?;
        let image_path: Option<String> = row.get("image_path")?;

        let content = match content_type {
            ContentType::Text => {
                let text = text_content.ok_or_else(|| {
                    rusqlite::Error::InvalidColumnType(0, "text_content".to_owned())
                })?;
                Content::Text(text)
            }
            ContentType::Image => {
                let path = image_path.ok_or_else(|| {
                    rusqlite::Error::InvalidColumnType(0, "image_path".to_owned())
                })?;
                // Additional metadata would be loaded separately
                Content::Image(ImageFile {
                    path,
                    size: 0,
                    dimensions: None,
                    format: ImageFormat::Unknown,
                })
            }
        };

        Ok(Self {
            id: row.get("id")?,
            content_hash: row.get("content_hash")?,
            content_type,
            timestamp: {
                let ms: i64 = row.get("timestamp")?;
                DateTime::<Utc>::from_timestamp_millis(ms)
                    .ok_or_else(|| rusqlite::Error::InvalidColumnType(0, "timestamp".to_owned()))?
            },
            content,
            source: SourceApplication {
                bundle_id: row.get("source_bundle_id")?,
                app_name: row.get("source_app_name")?,
                pid: row.get("source_pid")?,
            },
        })
    }
}
```

## Swift Data Structures

### ClipboardEntry Model

```swift
import Foundation

/// Represents a single clipboard history entry
struct ClipboardEntry: Codable {
    /// Unique identifier (UUID as string)
    let id: String

    /// Content hash (SHA-256) for deduplication
    let contentHash: String

    /// Type of clipboard content
    let contentType: ContentType

    /// Timestamp when content was copied
    let timestamp: Date

    /// Actual content (text or image reference)
    let content: Content

    /// Application that provided the clipboard content
    let source: SourceApplication
}

/// Content type classification
enum ContentType: String, Codable {
    case text
    case image
}

/// Clipboard content (text or image)
enum Content: Codable {
    case text(String)
    case image(ImageFile)

    /// Custom coding to handle associated values
    enum CodingKeys: String, CodingKey {
        case type, data
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "text":
            let text = try container.decode(String.self, forKey: .data)
            self = .text(text)
        case "image":
            let image = try container.decode(ImageFile.self, forKey: .data)
            self = .image(image)
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Invalid content type"
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .text(let text):
            try container.encode("text", forKey: .type)
            try container.encode(text, forKey: .data)
        case .image(let image):
            try container.encode("image", forKey: .type)
            try container.encode(image, forKey: .data)
        }
    }
}
```

### SourceApplication Model

```swift
/// Metadata about the application that provided clipboard content
struct SourceApplication: Codable {
    /// Bundle identifier (e.g., "com.apple.Safari")
    let bundleId: String

    /// Application display name (e.g., "Safari")
    let appName: String

    /// Process ID
    let pid: Int32
}
```

### ImageFile Model

```swift
/// Metadata for image file stored on disk
struct ImageFile: Codable {
    /// Relative path to image file
    let path: String

    /// File size in bytes
    let size: UInt64

    /// Image dimensions (optional)
    let dimensions: ImageDimensions?

    /// Image format
    let format: ImageFormat
}

struct ImageDimensions: Codable {
    let width: UInt32
    let height: UInt32
}

enum ImageFormat: String, Codable {
    case png, jpeg, gif, tiff, bmp, unknown
}
```

### ClipboardEvent (Swift)

```swift
/// Represents a clipboard change event (before database storage)
struct ClipboardEvent {
    /// Type of content
    let contentType: ClipboardContentType

    /// Content data
    let contentData: Data

    /// Source application (captured at time of copy)
    let sourceApp: SourceApplication

    /// Timestamp of clipboard change
    let timestamp: Date
}

enum ClipboardContentType {
    case text
    case image
    case fileReference  // Logged only, not stored
    case unsupported    // Ignored
}
```

## Data Flow

### 1. Clipboard Change Detection (Swift)

```
NSPasteboard change detected
    ↓
ContentTypeDetector identifies type
    ↓
SourceAppIdentifier captures current app
    ↓
ClipboardEvent created
    ↓
[If text/image] → Extract content → Call Rust FFI
[If file/unsupported] → Log event → Stop
```

### 2. Content Storage (Rust)

```
Receive content from Swift FFI
    ↓
Calculate SHA-256 hash
    ↓
Check database for existing hash
    ↓
[If duplicate] → Update timestamp → Return existing entry
[If new] → Save to database → Save image (if applicable) → Return new entry
```

### 3. History Retrieval

```
Query request (with optional filters)
    ↓
SQL query with indexed columns
    ↓
Map database rows to ClipboardEntry structs
    ↓
Return results to Swift (via FFI)
```

## State Transitions

```
[New Content]
    ↓
Hash calculation
    ↓
Duplicate check
    ↓
    ├─→ [Duplicate] → Update timestamp → Return existing
    └─→ [New] → Insert DB + Save file → Return new
```

## Validation Rules

### ClipboardEntry

- `id` must be valid UUID v4
- `content_hash` must be 64-character hex string (SHA-256)
- `content_type` must be "text" or "image"
- `timestamp` must be positive integer (milliseconds)
- Either `text_content` or `image_path` must be non-NULL, not both
- `source_bundle_id` must be non-empty string
- `source_app_name` must be non-empty string
- `source_pid` must be positive integer

### ContentHash

- `hash_value` must be 64-character hex string
- `algorithm` must be "sha256"
- `first_seen` must be positive integer

### ImageFile

- `path` must be non-empty relative path
- `size` must be non-negative
- `width` and `height` (if present) must be positive

## Performance Considerations

1. **Indexing**:
   - `timestamp` indexed DESC for efficient recent-first queries
   - `content_hash` indexed UNIQUE for fast duplicate detection
   - `content_type` indexed for type filtering

2. **Query Optimization**:
   - Use `LIMIT` clause for pagination
   - Use `ORDER BY timestamp DESC` for most-recent-first
   - Use prepared statements for repeated queries

3. **Storage Optimization**:
   - Text content stored directly in database (fast access)
   - Images stored as files (reduces DB size)
   - Hash-based filenames enable natural deduplication

## Migration Strategy

### Database Version Management

#### Schema Version Tracking Table

```sql
CREATE TABLE IF NOT EXISTS schema_version (
    version INTEGER PRIMARY KEY NOT NULL,
    migration_date INTEGER NOT NULL,
    applied_migrations TEXT NOT NULL  -- JSON array of migration names
);

-- Initialize with version 1
INSERT INTO schema_version (version, migration_date, applied_migrations)
VALUES (1, strftime('%s', 'now') * 1000, '["initial_schema"]');
```

#### Rust Migration System

```rust
pub struct Migration {
    pub version: i32,
    pub name: String,
    pub up: String,   // SQL to apply migration
    pub down: String, // SQL to rollback migration
}

pub struct Migrator {
    migrations: Vec<Migration>,
}

impl Migrator {
    pub fn new() -> Self {
        Self {
            migrations: vec![
                Migration {
                    version: 1,
                    name: "initial_schema".to_string(),
                    up: include_str!("migrations/001_initial.up.sql"),
                    down: include_str!("migrations/001_initial.down.sql"),
                },
            ],
        }
    }

    pub fn migrate(&self, conn: &Connection) -> Result<()> {
        let current_version = get_current_version(conn)?;

        for migration in &self.migrations {
            if migration.version > current_version {
                apply_migration(conn, migration)?;
                record_migration(conn, migration)?;
            }
        }

        Ok(())
    }
}
```

### Version 1.0 (Initial)

**Schema**:
- Create `clipboard_entries` table with all required fields
- Create `schema_version` table for migration tracking
- Create indexes on `timestamp`, `content_hash`, `content_type`

**Migration File**: `migrations/001_initial.up.sql`
```sql
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
CREATE INDEX idx_clipboard_entries_timestamp ON clipboard_entries(timestamp DESC);
CREATE INDEX idx_clipboard_entries_content_hash ON clipboard_entries(content_hash);
CREATE INDEX idx_clipboard_entries_content_type ON clipboard_entries(content_type);
CREATE INDEX idx_clipboard_entries_type_timestamp ON clipboard_entries(content_type, timestamp DESC);

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
```

**Rollback**: `migrations/001_initial.down.sql`
```sql
DROP INDEX IF EXISTS idx_clipboard_entries_type_timestamp;
DROP INDEX IF EXISTS idx_clipboard_entries_content_type;
DROP INDEX IF EXISTS idx_clipboard_entries_content_hash;
DROP INDEX IF EXISTS idx_clipboard_entries_timestamp;
DROP TABLE IF EXISTS clipboard_entries;
DROP TABLE IF EXISTS schema_version;
PRAGMA user_version = 0;
```

### Future Migrations (Examples)

#### Version 1.1: Add Content Hash Analytics

**Purpose**: Track hash frequency for analytics

**Migration**: `migrations/002_add_content_hashes.up.sql`
```sql
CREATE TABLE IF NOT EXISTS content_hashes (
    hash_value TEXT PRIMARY KEY NOT NULL,
    algorithm TEXT NOT NULL DEFAULT 'sha256',
    first_seen INTEGER NOT NULL,
    reference_count INTEGER NOT NULL DEFAULT 1
);

CREATE INDEX IF NOT EXISTS idx_content_hashes_first_seen
ON content_hashes(first_seen DESC);

-- Update schema version
INSERT INTO schema_version (version, migration_date, applied_migrations)
VALUES (2, strftime('%s', 'now') * 1000, '["add_content_hashes"]');

PRAGMA user_version = 2;
```

#### Version 1.2: Add Soft Delete Support

**Purpose**: Allow soft deletion of entries

**Migration**: `migrations/003_add_soft_delete.up.sql`
```sql
ALTER TABLE clipboard_entries ADD COLUMN is_deleted INTEGER NOT NULL DEFAULT 0;
CREATE INDEX idx_clipboard_entries_deleted ON clipboard_entries(is_deleted, timestamp DESC);

-- Update schema version
INSERT INTO schema_version (version, migration_date, applied_migrations)
VALUES (3, strftime('%s', 'now') * 1000, '["add_soft_delete"]');

PRAGMA user_version = 3;
```

### Migration Execution Flow

1. **Application Startup**:
   ```rust
   let migrator = Migrator::new();
   migrator.migrate(&conn)?;
   ```

2. **Version Check**:
   ```rust
   fn get_current_version(conn: &Connection) -> Result<i32> {
       conn.query_row("PRAGMA user_version", [], |row| row.get(0))
   }
   ```

3. **Migration Application**:
   ```rust
   fn apply_migration(conn: &Connection, migration: &Migration) -> Result<()> {
       let transaction = conn.unchecked_transaction()?;
       transaction.execute_batch(&migration.up)?;
       transaction.commit()?;
       Ok(())
   }
   ```

4. **Migration Recording**:
   ```rust
   fn record_migration(conn: &Connection, migration: &Migration) -> Result<()> {
       conn.execute(
           "INSERT INTO schema_version (version, migration_date, applied_migrations) VALUES (?, ?, ?)",
           params![
               migration.version,
               Utc::now().timestamp_millis(),
               format!(r#"["{}"]"#, migration.name)
           ],
       )?;
       Ok(())
   }
   ```

### Migration Best Practices

1. **Always Test Migrations**:
   - Test on sample data before deploying
   - Test both upgrade and rollback paths
   - Use transactions for atomicity

2. **Backwards Compatibility**:
   - Old app versions should work with new schema for reasonable period
   - Use DEFAULT values for new columns
   - Avoid dropping columns/tables quickly

3. **Data Preservation**:
   - Never delete user data during migration
   - Use ALTER TABLE when possible (safer than CREATE + COPY)
   - Backup database before major migrations

4. **Version Increment Rules**:
   - MAJOR: Breaking changes (requires data migration)
   - MINOR: Additive changes (new columns, tables, indexes)
   - PATCH: Bug fixes (index changes, constraints)

## Summary

This data model provides:
- ✅ Clear separation of concerns (entries, hashes, files)
- ✅ Efficient queries via proper indexing
- ✅ Natural deduplication via unique hash constraint
- ✅ Support for text and image content types
- ✅ Rich metadata (timestamp, source app)
- ✅ Cross-language compatibility (Rust structs + Swift structs)
- ✅ Validation rules for data integrity
