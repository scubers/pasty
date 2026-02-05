use crate::models::{
    ClipboardEntry, Content, ContentType, ImageFile, ImageFormat, SourceApplication,
};
use chrono::{DateTime, Utc};
use log::{debug, error, info, warn};
use rusqlite::{params, params_from_iter, Connection, Result as SqliteResult};
use std::path::Path;

/// Error types for database operations with context
#[derive(Debug, thiserror::Error)]
pub enum DatabaseError {
    /// SQLite底层错误，包含具体操作上下文
    #[error("Database operation '{operation}' failed: {source}")]
    SqliteWithOperation {
        operation: String,
        #[source]
        source: rusqlite::Error,
    },

    /// SQLite错误（向后兼容）
    #[error("SQLite error: {0}")]
    Sqlite(#[from] rusqlite::Error),

    /// 数据库连接失败，包含路径信息
    #[error("Failed to connect to database at '{path}': {reason}")]
    Connection { path: String, reason: String },

    /// 数据库迁移失败
    #[error("Migration to version {version} failed: {reason}")]
    Migration { version: i32, reason: String },

    /// 条目未找到（可能不是错误）
    #[error("Entry not found: {id}")]
    EntryNotFound { id: String },

    /// 数据库锁定，重试失败
    #[error("Database is busy, retry attempts: {attempts}")]
    DatabaseLocked { attempts: u32 },

    /// IO错误
    #[error("IO error during database operation: {0}")]
    Io(#[from] std::io::Error),
}

impl DatabaseError {
    /// 为SQLite错误添加操作上下文
    pub fn with_operation(operation: impl Into<String>, err: rusqlite::Error) -> Self {
        DatabaseError::SqliteWithOperation {
            operation: operation.into(),
            source: err,
        }
    }

    /// 创建连接错误
    pub fn connection_error(path: impl Into<String>, reason: impl Into<String>) -> Self {
        DatabaseError::Connection {
            path: path.into(),
            reason: reason.into(),
        }
    }

    /// 创建迁移错误
    pub fn migration_error(version: i32, reason: impl Into<String>) -> Self {
        DatabaseError::Migration {
            version,
            reason: reason.into(),
        }
    }

    /// 检查是否为可重试的错误（如数据库锁定）
    pub fn is_retryable(&self) -> bool {
        match self {
            DatabaseError::Sqlite(err) => {
                matches!(err, rusqlite::Error::SqliteFailure(_, _))
            }
            DatabaseError::SqliteWithOperation { source, .. } => {
                matches!(source, rusqlite::Error::SqliteFailure(_, _))
            }
            DatabaseError::DatabaseLocked { .. } => true,
            _ => false,
        }
    }
}

/// Database connection manager
pub struct Database {
    conn: Connection,
}

impl Database {
    /// Open or create database at specified path
    pub fn open<P: AsRef<Path>>(db_path: P) -> Result<Self, DatabaseError> {
        let db_path_str = db_path.as_ref().display().to_string();
        info!("Opening database at: {}", db_path_str);

        let conn = Connection::open(&db_path).map_err(|e| {
            error!("Failed to open database: {}", e);
            DatabaseError::connection_error(db_path_str.clone(), e.to_string())
        })?;

        // Enable WAL mode for better concurrency
        debug!("Configuring WAL mode for better concurrency");
        conn.pragma_update(None, "journal_mode", "WAL")?;
        conn.pragma_update(None, "synchronous", "NORMAL")?;

        // Enable prepared statement cache for better performance
        conn.set_prepared_statement_cache_capacity(100);
        debug!("Prepared statement cache enabled (capacity: 100)");

        let db = Self { conn };
        db.initialize()?;

        info!("Database opened successfully");
        Ok(db)
    }

    /// Execute a database operation with automatic retry for transient locks
    ///
    /// Retries operations that fail due to SQLITE_BUSY (database locked).
    /// Uses exponential backoff: 50ms, 100ms, 200ms, 400ms, 800ms (5 attempts)
    fn execute_with_retry<F, R>(&self, operation_name: &str, op: F) -> Result<R, DatabaseError>
    where
        F: Fn() -> Result<R, rusqlite::Error>,
    {
        let max_attempts = 5;
        let mut delay_ms = 50;

        for attempt in 0..max_attempts {
            match op() {
                Ok(result) => {
                    if attempt > 0 {
                        info!("{} succeeded after {} retries", operation_name, attempt);
                    }
                    return Ok(result);
                }
                Err(rusqlite::Error::SqliteFailure(_, _)) => {
                    // Check if this is a database locked/busy error
                    if attempt < max_attempts - 1 {
                        warn!(
                            "{} failed (database busy), retry {} in {}ms",
                            operation_name,
                            attempt + 1,
                            delay_ms
                        );
                        std::thread::sleep(std::time::Duration::from_millis(delay_ms));
                        delay_ms *= 2; // Exponential backoff
                        continue;
                    } else {
                        error!(
                            "{} failed after {} attempts: database busy",
                            operation_name, max_attempts
                        );
                        return Err(DatabaseError::DatabaseLocked {
                            attempts: max_attempts,
                        });
                    }
                }
                Err(e) => {
                    error!("{} failed: {}", operation_name, e);
                    return Err(DatabaseError::from(e));
                }
            }
        }

        unreachable!()
    }

    /// Initialize database schema and run migrations
    fn initialize(&self) -> Result<(), DatabaseError> {
        // Check if migration table exists
        let user_version: i32 = self
            .conn
            .pragma_query_value(None, "user_version", |row| row.get(0))?;

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
                info!("Running migration version 1: initial schema");
                let migration_sql = include_str!("../../migrations/001_initial.up.sql");
                self.conn
                    .execute_batch(migration_sql)
                    .map_err(|e| DatabaseError::migration_error(version, e.to_string()))?;
            }
            _ => {
                error!("Unknown migration version: {}", version);
                return Err(DatabaseError::migration_error(version, "Unknown version"));
            }
        }

        Ok(())
    }

    /// Insert a new clipboard entry
    pub fn insert_entry(&self, entry: &ClipboardEntry) -> Result<(), DatabaseError> {
        debug!("Inserting clipboard entry: {}", entry.id);

        let (text_content, image_path) = match &entry.content {
            Content::Text(text) => (Some(text.as_str()), None),
            Content::Image(img) => (None, Some(img.path.as_str())),
        };

        self.execute_with_retry("insert_entry", || {
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
            )
        })?;

        debug!("Clipboard entry inserted successfully: {}", entry.id);
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

        let result = self
            .conn
            .query_row(query, params![hash], |row| Ok(Self::row_to_entry(row)?));

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
    pub fn update_latest_copy_time(
        &self,
        hash: &str,
        new_time: DateTime<Utc>,
    ) -> Result<(), DatabaseError> {
        self.conn.execute(
            "UPDATE clipboard_entries SET latest_copy_time_ms = ?1 WHERE content_hash = ?2",
            params![new_time.timestamp_millis(), hash],
        )?;

        Ok(())
    }

    /// Update latest copy time for entry by ID
    pub fn update_latest_copy_time_by_id(
        &self,
        id: uuid::Uuid,
        new_time: DateTime<Utc>,
    ) -> Result<(), DatabaseError> {
        self.conn.execute(
            "UPDATE clipboard_entries SET latest_copy_time_ms = ?1 WHERE id = ?2",
            params![new_time.timestamp_millis(), id.to_string()],
        )?;

        Ok(())
    }

    /// Get all entries (with pagination)
    pub fn get_all_entries(
        &self,
        limit: usize,
        offset: usize,
    ) -> Result<Vec<ClipboardEntry>, DatabaseError> {
        let mut stmt = self.conn.prepare(
            "SELECT id, content_hash, content_type, timestamp, latest_copy_time_ms,
                    text_content, image_path, source_bundle_id, source_app_name, source_pid
             FROM clipboard_entries
             ORDER BY timestamp DESC
             LIMIT ?1 OFFSET ?2",
        )?;

        let entries = stmt
            .query_map(params![limit as i64, offset as i64], |row| {
                Ok(Self::row_to_entry(row)?)
            })?
            .collect::<Result<Vec<_>, _>>()?;

        Ok(entries)
    }

    /// Get entries by content type
    pub fn get_entries_by_type(
        &self,
        content_type: ContentType,
        limit: usize,
        offset: usize,
    ) -> Result<Vec<ClipboardEntry>, DatabaseError> {
        let mut stmt = self.conn.prepare(
            "SELECT id, content_hash, content_type, timestamp, latest_copy_time_ms,
                    text_content, image_path, source_bundle_id, source_app_name, source_pid
             FROM clipboard_entries
             WHERE content_type = ?1
             ORDER BY timestamp DESC
             LIMIT ?2 OFFSET ?3",
        )?;

        let entries = stmt
            .query_map(
                params![content_type.as_str(), limit as i64, offset as i64],
                |row| Ok(Self::row_to_entry(row)?),
            )?
            .collect::<Result<Vec<_>, _>>()?;

        Ok(entries)
    }

    pub fn count_entries(&self) -> Result<i64, DatabaseError> {
        let count: i64 =
            self.conn
                .query_row("SELECT COUNT(*) FROM clipboard_entries", [], |row| {
                    row.get(0)
                })?;
        Ok(count)
    }

    pub fn delete_oldest_unpinned_entries(&self, limit: usize) -> Result<usize, DatabaseError> {
        self.execute_with_retry("delete_oldest_unpinned", || {
            let deleted = self.conn.execute(
                "DELETE FROM clipboard_entries 
                 WHERE id IN (
                     SELECT id FROM clipboard_entries 
                     WHERE is_pinned = 0
                     ORDER BY timestamp ASC 
                     LIMIT ?
                 )",
                params![limit as i64],
            )?;
            Ok(deleted)
        })
    }

    /// Delete a single entry by ID
    pub fn delete_entry_by_id(&self, id: uuid::Uuid) -> Result<usize, DatabaseError> {
        self.execute_with_retry("delete_entry_by_id", || {
            let deleted = self.conn.execute(
                "DELETE FROM clipboard_entries WHERE id = ?1",
                params![id.to_string()],
            )?;
            Ok(deleted)
        })
    }

    /// Delete multiple entries by IDs
    pub fn delete_entries_by_ids(&self, ids: &[uuid::Uuid]) -> Result<usize, DatabaseError> {
        if ids.is_empty() {
            return Ok(0);
        }

        let placeholders = ids.iter().map(|_| "?").collect::<Vec<_>>().join(",");
        let query = format!(
            "DELETE FROM clipboard_entries WHERE id IN ({})",
            placeholders
        );
        self.execute_with_retry("delete_entries_by_ids", || {
            let deleted = self
                .conn
                .execute(&query, params_from_iter(ids.iter().map(|id| id.to_string())))?;
            Ok(deleted)
        })
    }

    /// Convert database row to ClipboardEntry
    fn row_to_entry(row: &rusqlite::Row) -> Result<ClipboardEntry, rusqlite::Error> {
        use uuid::Uuid;

        let id_str: String = row.get(0)?;
        let id = Uuid::parse_str(&id_str).map_err(|_| rusqlite::Error::InvalidQuery)?;

        let content_hash: String = row.get(1)?;
        let content_type_str: String = row.get(2)?;
        let content_type = ContentType::from_str(&content_type_str).ok_or_else(|| {
            rusqlite::Error::InvalidParameterName("Invalid content_type".to_owned())
        })?;

        let timestamp_ms: i64 = row.get(3)?;
        let timestamp = DateTime::<Utc>::from_timestamp_millis(timestamp_ms)
            .ok_or_else(|| rusqlite::Error::InvalidParameterName("Invalid timestamp".to_owned()))?;

        let latest_copy_ms: i64 = row.get(4)?;
        let latest_copy_time_ms = DateTime::<Utc>::from_timestamp_millis(latest_copy_ms)
            .ok_or_else(|| {
                rusqlite::Error::InvalidParameterName("Invalid latest_copy_time_ms".to_owned())
            })?;

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
        let version: i32 = db
            .conn
            .pragma_query_value(None, "user_version", |row| row.get(0))
            .unwrap();
        assert_eq!(version, 1);
    }

    #[test]
    fn test_insert_and_retrieve_entry() {
        let temp_file = NamedTempFile::new().unwrap();
        let db = Database::open(temp_file.path()).unwrap();

        let source =
            SourceApplication::new("com.test.App".to_string(), "TestApp".to_string(), 1234);
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

        let source =
            SourceApplication::new("com.test.App".to_string(), "TestApp".to_string(), 1234);
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
