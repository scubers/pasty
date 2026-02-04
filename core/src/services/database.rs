use rusqlite::{Connection, Result as SqliteResult, params};
use std::path::Path;
use crate::models::{ClipboardEntry, ContentType, Content, ImageFile, ImageFormat, SourceApplication};
use chrono::{DateTime, Utc};

/// Error types for database operations
#[derive(Debug, thiserror::Error)]
pub enum DatabaseError {
    #[error("SQLite error: {0}")]
    Sqlite(#[from] rusqlite::Error),

    #[error("Database connection error: {0}")]
    Connection(String),

    #[error("Migration error: {0}")]
    Migration(String),

    #[error("Entry not found: {0}")]
    EntryNotFound(String),
}

/// Database connection manager
pub struct Database {
    conn: Connection,
}

impl Database {
    /// Open or create database at specified path
    pub fn open<P: AsRef<Path>>(db_path: P) -> Result<Self, DatabaseError> {
        let conn = Connection::open(db_path)
            .map_err(|e| DatabaseError::Connection(e.to_string()))?;

        // Enable WAL mode for better concurrency
        conn.pragma_update(None, "journal_mode", "WAL")?;
        conn.pragma_update(None, "synchronous", "NORMAL")?;

        let db = Self { conn };
        db.initialize()?;

        Ok(db)
    }

    /// Initialize database schema and run migrations
    fn initialize(&self) -> Result<(), DatabaseError> {
        // Check if migration table exists
        let user_version: i32 = self.conn.pragma_query_value(None, "user_version", |row| row.get(0))?;

        if user_version == 0 {
            // Run initial migration
            self.run_migration(1)?;
        }

        Ok(())
    }

    /// Run a specific migration
    fn run_migration(&self, version: i32) -> Result<(), DatabaseError> {
        match version {
            1 => {
                let migration_sql = include_str!("../../migrations/001_initial.up.sql");
                self.conn.execute_batch(migration_sql)
                    .map_err(|e| DatabaseError::Migration(e.to_string()))?;
            }
            _ => return Err(DatabaseError::Migration(format!("Unknown migration version: {}", version))),
        }

        Ok(())
    }

    /// Insert a new clipboard entry
    pub fn insert_entry(&self, entry: &ClipboardEntry) -> Result<(), DatabaseError> {
        let (text_content, image_path) = match &entry.content {
            Content::Text(text) => (Some(text.as_str()), None),
            Content::Image(img) => (None, Some(img.path.as_str())),
        };

        self.conn.execute(
            "INSERT INTO clipboard_entries (
                id, content_hash, content_type, timestamp, latest_copy_time_ms,
                text_content, image_path, source_bundle_id, source_app_name, source_pid
            ) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10)",
            params![
                entry.id.to_string(),
                entry.content_hash,
                entry.content_type.as_str(),
                entry.timestamp.timestamp_millis(),
                entry.latest_copy_time_ms.timestamp_millis(),
                text_content,
                image_path,
                entry.source.bundle_id,
                entry.source.app_name,
                entry.source.pid,
            ],
        )?;

        Ok(())
    }

    /// Check if entry with given hash exists
    pub fn entry_exists(&self, hash: &str) -> Result<bool, DatabaseError> {
        let count: i64 = self.conn.query_row(
            "SELECT COUNT(*) FROM clipboard_entries WHERE content_hash = ?1",
            params![hash],
            |row| row.get(0),
        )?;

        Ok(count > 0)
    }

    /// Get entry by content hash
    pub fn get_entry_by_hash(&self, hash: &str) -> Result<Option<ClipboardEntry>, DatabaseError> {
        let query = "
            SELECT id, content_hash, content_type, timestamp, latest_copy_time_ms,
                   text_content, image_path, source_bundle_id, source_app_name, source_pid
            FROM clipboard_entries
            WHERE content_hash = ?1
        ";

        let result = self.conn.query_row(query, params![hash], |row| {
            Ok(Self::row_to_entry(row)?)
        });

        match result {
            Ok(entry) => Ok(Some(entry)),
            Err(rusqlite::Error::QueryReturnedNoRows) => Ok(None),
            Err(e) => Err(DatabaseError::Sqlite(e)),
        }
    }

    /// Get entry by ID
    pub fn get_entry_by_id(&self, id: uuid::Uuid) -> Result<Option<ClipboardEntry>, DatabaseError> {
        let query = "
            SELECT id, content_hash, content_type, timestamp, latest_copy_time_ms,
                   text_content, image_path, source_bundle_id, source_app_name, source_pid
            FROM clipboard_entries
            WHERE id = ?1
        ";

        let result = self.conn.query_row(query, params![id.to_string()], |row| {
            Ok(Self::row_to_entry(row)?)
        });

        match result {
            Ok(entry) => Ok(Some(entry)),
            Err(rusqlite::Error::QueryReturnedNoRows) => Ok(None),
            Err(e) => Err(DatabaseError::Sqlite(e)),
        }
    }

    /// Update latest copy time for existing entry
    pub fn update_latest_copy_time(&self, hash: &str, new_time: DateTime<Utc>) -> Result<(), DatabaseError> {
        self.conn.execute(
            "UPDATE clipboard_entries SET latest_copy_time_ms = ?1 WHERE content_hash = ?2",
            params![new_time.timestamp_millis(), hash],
        )?;

        Ok(())
    }

    /// Get all entries (with pagination)
    pub fn get_all_entries(&self, limit: usize, offset: usize) -> Result<Vec<ClipboardEntry>, DatabaseError> {
        let mut stmt = self.conn.prepare(
            "SELECT id, content_hash, content_type, timestamp, latest_copy_time_ms,
                    text_content, image_path, source_bundle_id, source_app_name, source_pid
             FROM clipboard_entries
             ORDER BY timestamp DESC
             LIMIT ?1 OFFSET ?2"
        )?;

        let entries = stmt.query_map(params![limit as i64, offset as i64], |row| {
            Ok(Self::row_to_entry(row)?)
        })?
        .collect::<Result<Vec<_>, _>>()?;

        Ok(entries)
    }

    /// Get entries by content type
    pub fn get_entries_by_type(&self, content_type: ContentType, limit: usize, offset: usize) -> Result<Vec<ClipboardEntry>, DatabaseError> {
        let mut stmt = self.conn.prepare(
            "SELECT id, content_hash, content_type, timestamp, latest_copy_time_ms,
                    text_content, image_path, source_bundle_id, source_app_name, source_pid
             FROM clipboard_entries
             WHERE content_type = ?1
             ORDER BY timestamp DESC
             LIMIT ?2 OFFSET ?3"
        )?;

        let entries = stmt.query_map(params![content_type.as_str(), limit as i64, offset as i64], |row| {
            Ok(Self::row_to_entry(row)?)
        })?
        .collect::<Result<Vec<_>, _>>()?;

        Ok(entries)
    }

    /// Convert database row to ClipboardEntry
    fn row_to_entry(row: &rusqlite::Row) -> Result<ClipboardEntry, rusqlite::Error> {
        use uuid::Uuid;

        let id_str: String = row.get(0)?;
        let id = Uuid::parse_str(&id_str)
            .map_err(|_| rusqlite::Error::InvalidQuery)?;

        let content_hash: String = row.get(1)?;
        let content_type_str: String = row.get(2)?;
        let content_type = ContentType::from_str(&content_type_str)
            .ok_or_else(|| rusqlite::Error::InvalidParameterName("Invalid content_type".to_owned()))?;

        let timestamp_ms: i64 = row.get(3)?;
        let timestamp = DateTime::<Utc>::from_timestamp_millis(timestamp_ms)
            .ok_or_else(|| rusqlite::Error::InvalidParameterName("Invalid timestamp".to_owned()))?;

        let latest_copy_ms: i64 = row.get(4)?;
        let latest_copy_time_ms = DateTime::<Utc>::from_timestamp_millis(latest_copy_ms)
            .ok_or_else(|| rusqlite::Error::InvalidParameterName("Invalid latest_copy_time_ms".to_owned()))?;

        let text_content: Option<String> = row.get(5)?;
        let image_path: Option<String> = row.get(6)?;

        let content = match content_type {
            ContentType::Text => {
                let text = text_content.ok_or_else(|| {
                    rusqlite::Error::InvalidParameterName("text_content is None".to_owned())
                })?;
                Content::Text(text)
            }
            ContentType::Image => {
                let path = image_path.ok_or_else(|| {
                    rusqlite::Error::InvalidParameterName("image_path is None".to_owned())
                })?;
                // Create basic ImageFile (additional metadata would be loaded separately)
                Content::Image(ImageFile {
                    path,
                    size: 0,
                    dimensions: None,
                    format: ImageFormat::Unknown,
                })
            }
        };

        let source = SourceApplication {
            bundle_id: row.get(7)?,
            app_name: row.get(8)?,
            pid: row.get(9)?,
        };

        Ok(ClipboardEntry {
            id,
            content_hash,
            content_type,
            timestamp,
            latest_copy_time_ms,
            content,
            source,
        })
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::NamedTempFile;

    #[test]
    fn test_database_initialization() {
        let temp_file = NamedTempFile::new().unwrap();
        let db = Database::open(temp_file.path()).unwrap();

        // Check that version is set
        let version: i32 = db.conn.pragma_query_value(None, "user_version", |row| row.get(0)).unwrap();
        assert_eq!(version, 1);
    }

    #[test]
    fn test_insert_and_retrieve_entry() {
        let temp_file = NamedTempFile::new().unwrap();
        let db = Database::open(temp_file.path()).unwrap();

        let source = SourceApplication::new("com.test.App".to_string(), "TestApp".to_string(), 1234);
        let entry = ClipboardEntry::new(
            "test_hash_123".to_string(),
            ContentType::Text,
            Content::Text("Test content".to_string()),
            source,
        );

        db.insert_entry(&entry).unwrap();

        let retrieved = db.get_entry_by_hash("test_hash_123").unwrap().unwrap();
        assert_eq!(retrieved.content_hash, "test_hash_123");
        assert_eq!(retrieved.source.bundle_id, "com.test.App");
    }

    #[test]
    fn test_entry_exists() {
        let temp_file = NamedTempFile::new().unwrap();
        let db = Database::open(temp_file.path()).unwrap();

        assert!(!db.entry_exists("nonexistent").unwrap());

        let source = SourceApplication::new("com.test.App".to_string(), "TestApp".to_string(), 1234);
        let entry = ClipboardEntry::new(
            "test_hash".to_string(),
            ContentType::Text,
            Content::Text("Test".to_string()),
            source,
        );

        db.insert_entry(&entry).unwrap();
        assert!(db.entry_exists("test_hash").unwrap());
    }
}
