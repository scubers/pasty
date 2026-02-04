use crate::models::{ClipboardEntry, ContentType, Content, SourceApplication};
use crate::services::database::{Database, DatabaseError};
use crate::services::deduplication::DeduplicationService;
use crate::services::storage::StorageService;
use std::path::Path;

/// High-level clipboard storage service
///
/// Provides a unified API for clipboard operations including:
/// - Storing text and image content with automatic deduplication
/// - Retrieving clipboard history with filtering and pagination
/// - Managing metadata about clipboard entries
///
/// # Example
/// ```rust,no_run
/// use pasty_core::services::ClipboardStore;
/// use pasty_core::models::SourceApplication;
///
/// let store = ClipboardStore::new("./clipboard.db", "./images")?;
/// let source = SourceApplication::new("com.app.ID".into(), "App".into(), 1234);
///
/// // Store text
/// let entry = store.store_text("Hello, world!", source)?;
///
/// // Retrieve history
/// let history = store.get_history(10, 0)?;
/// # Ok::<(), pasty_core::services::database::DatabaseError>(())
/// ```
pub struct ClipboardStore {
    db: Database,
    storage: StorageService,
}

impl ClipboardStore {
    /// Create a new clipboard store
    ///
    /// Initializes the database connection and storage service.
    /// Automatically creates required directories and runs migrations if needed.
    ///
    /// # Arguments
    /// * `db_path` - Path to SQLite database file (created if it doesn't exist)
    /// * `storage_base_dir` - Base directory for image storage (created if it doesn't exist)
    ///
    /// # Returns
    /// * `Ok(ClipboardStore)` - Successfully initialized store
    /// * `Err(DatabaseError)` - Failed to initialize (check error for details)
    ///
    /// # Errors
    /// Returns `DatabaseError` if:
    /// - Cannot create or open database file
    /// - Cannot create storage directory
    /// - Migration fails
    pub fn new<P: AsRef<Path>>(db_path: P, storage_base_dir: P) -> Result<Self, DatabaseError> {
        let db = Database::open(&db_path)?;
        let storage_path = storage_base_dir.as_ref();
        let storage = StorageService::new(&storage_base_dir)
            .map_err(|e| DatabaseError::connection_error(
                storage_path.display().to_string(),
                e.to_string()
            ))?;

        Ok(Self { db, storage })
    }

    /// Store text clipboard entry with automatic deduplication
    ///
    /// Stores text content in the database. If the same text (ignoring leading/trailing
    /// whitespace) already exists, updates the timestamp instead of creating a duplicate.
    ///
    /// # Arguments
    /// * `text` - Text content to store (any UTF-8 string)
    /// * `source` - Application that provided the clipboard content
    ///
    /// # Returns
    /// * `Ok(ClipboardEntry)` - The stored or updated entry
    /// * `Err(DatabaseError)` - Storage operation failed
    ///
    /// # Behavior
    /// - Text is automatically trimmed (leading/trailing whitespace removed) before hashing
    /// - Duplicate detection is case-sensitive and uses exact content matching
    /// - Latest copy time is updated for duplicates
    ///
    /// # Example
    /// ```rust,no_run
    /// # use pasty_core::services::ClipboardStore;
    /// # use pasty_core::models::SourceApplication;
    /// # let store = ClipboardStore::new("./db", "./images").unwrap();
    /// let source = SourceApplication::new("com.app.ID".into(), "App".into(), 1234);
    /// let entry = store.store_text("Hello, world!", source)?;
    /// # Ok::<(), pasty_core::services::database::DatabaseError>(())
    /// ```
    pub fn store_text(
        &self,
        text: &str,
        source: SourceApplication,
    ) -> Result<ClipboardEntry, DatabaseError> {
        // Calculate hash
        let hash = DeduplicationService::hash_text(text);

        // Check for duplicate
        if let Some(mut existing) = self.db.get_entry_by_hash(&hash)? {
            // Update timestamp for duplicate
            existing.update_latest_copy_time();
            self.db.update_latest_copy_time(&hash, existing.latest_copy_time_ms)?;
            return Ok(existing);
        }

        // Create new entry
        let entry = ClipboardEntry::new(
            hash.clone(),
            ContentType::Text,
            Content::Text(text.to_string()),
            source,
        );

        // Insert into database
        self.db.insert_entry(&entry)?;

        Ok(entry)
    }

    /// Store image clipboard entry with automatic deduplication
    ///
    /// Stores image content on disk and metadata in the database.
    /// If an image with identical content already exists, updates the timestamp instead.
    ///
    /// # Arguments
    /// * `image_data` - Raw image bytes (PNG, JPEG, etc.)
    /// * `format` - Image format extension (e.g., "png", "jpg", "gif")
    /// * `source` - Application that provided the clipboard content
    ///
    /// # Returns
    /// * `Ok(ClipboardEntry)` - The stored or updated entry
    /// * `Err(DatabaseError)` - Storage operation failed
    ///
    /// # Behavior
    /// - Images are stored with two-level directory sharding for performance
    /// - Image files are created with 600 permissions (owner read/write only)
    /// - Duplicate detection uses SHA-256 hash of the image data
    ///
    /// # Storage Format
    /// Images are stored at: `<storage_base_dir>/<hash[0..4]>/<hash>.<format>`
    ///
    /// # Example
    /// ```rust,no_run
    /// # use pasty_core::services::ClipboardStore;
    /// # use pasty_core::models::SourceApplication;
    /// # let store = ClipboardStore::new("./db", "./images").unwrap();
    /// let source = SourceApplication::new("com.app.ID".into(), "App".into(), 1234);
    /// let image_data = std::fs::read("screenshot.png")?;
    /// let entry = store.store_image(&image_data, "png", source)?;
    /// # Ok::<(), Box<dyn std::error::Error>>(())
    /// ```
    pub fn store_image(
        &self,
        image_data: &[u8],
        format: &str,
        source: SourceApplication,
    ) -> Result<ClipboardEntry, DatabaseError> {
        // Calculate hash
        let hash = DeduplicationService::hash_image(image_data);

        // Check for duplicate
        if let Some(mut existing) = self.db.get_entry_by_hash(&hash)? {
            // Update timestamp for duplicate
            existing.update_latest_copy_time();
            self.db.update_latest_copy_time(&hash, existing.latest_copy_time_ms)?;
            return Ok(existing);
        }

        // Save image to disk
        let _image_path = self.storage.save_image(&hash, image_data, format)
            .map_err(|e| DatabaseError::connection_error(
                format!("image save for hash {}", hash),
                e.to_string()
            ))?;

        // Get relative path for storage in database
        let relative_path = self.storage.get_relative_path(&hash, format);

        // Create ImageFile metadata
        use crate::models::{ImageFile, ImageFormat};
        let image_file = ImageFile {
            path: relative_path,
            size: image_data.len() as u64,
            dimensions: None,
            format: ImageFormat::from_extension(format),
        };

        // Create new entry
        let entry = ClipboardEntry::new(
            hash.clone(),
            ContentType::Image,
            Content::Image(image_file),
            source,
        );

        // Insert into database
        self.db.insert_entry(&entry)?;

        Ok(entry)
    }

    /// Get all clipboard history entries
    pub fn get_history(&self, limit: usize, offset: usize) -> Result<Vec<ClipboardEntry>, DatabaseError> {
        self.db.get_all_entries(limit, offset)
    }

    /// Get entries filtered by content type
    pub fn get_history_filtered(
        &self,
        content_type: ContentType,
        limit: usize,
        offset: usize,
    ) -> Result<Vec<ClipboardEntry>, DatabaseError> {
        self.db.get_entries_by_type(content_type, limit, offset)
    }

    /// Get entry by content hash
    pub fn get_entry_by_hash(&self, hash: &str) -> Result<Option<ClipboardEntry>, DatabaseError> {
        self.db.get_entry_by_hash(hash)
    }

    /// Get a clipboard entry by its unique identifier
    ///
    /// Retrieves a single entry using its UUID. This is the most efficient way
    /// to retrieve a specific entry when you know its ID.
    ///
    /// # Arguments
    /// * `id` - UUID of the entry (as returned by ClipboardEntry::id)
    ///
    /// # Returns
    /// * `Ok(Some(entry))` - Entry found
    /// * `Ok(None)` - Entry not found (not an error)
    /// * `Err(DatabaseError)` - Query failed
    ///
    /// # Performance
    /// - Uses indexed query on primary key
    /// - O(log n) lookup time
    /// - Target: < 5ms for any database size
    ///
    /// # Example
    /// ```rust,no_run
    /// # use pasty_core::services::ClipboardStore;
    /// # use pasty_core::models::SourceApplication;
    /// # let store = ClipboardStore::new("./db", "./images").unwrap();
    /// use uuid::Uuid;
    ///
    /// let id = Uuid::parse_str("01234567-89ab-cdef-0123-456789abcdef").unwrap();
    /// if let Some(entry) = store.get_entry_by_id(id)? {
    ///     println!("Found: {:?}", entry.content);
    /// }
    /// # Ok::<(), pasty_core::services::database::DatabaseError>(())
    /// ```
    pub fn get_entry_by_id(&self, id: uuid::Uuid) -> Result<Option<ClipboardEntry>, DatabaseError> {
        self.db.get_entry_by_id(id)
    }

    /// Check if entry with given hash exists
    pub fn entry_exists(&self, hash: &str) -> Result<bool, DatabaseError> {
        self.db.entry_exists(hash)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::TempDir;

    #[test]
    fn test_store_and_retrieve_text() {
        let temp_dir = TempDir::new().unwrap();
        let db_path = temp_dir.path().join("test.db");
        let storage_dir = temp_dir.path().join("images");

        let store = ClipboardStore::new(&db_path, &storage_dir).unwrap();

        let source = SourceApplication::new("com.test.App".to_string(), "TestApp".to_string(), 1234);

        // Store text
        let entry = store.store_text("Hello, World!", source.clone()).unwrap();
        assert_eq!(entry.content_hash, store.store_text("Hello, World!", source).unwrap().content_hash);

        // Retrieve
        let history = store.get_history(10, 0).unwrap();
        assert_eq!(history.len(), 1);
        assert_eq!(history[0].content_hash, entry.content_hash);
    }

    #[test]
    fn test_text_deduplication() {
        let temp_dir = TempDir::new().unwrap();
        let db_path = temp_dir.path().join("test.db");
        let storage_dir = temp_dir.path().join("images");

        let store = ClipboardStore::new(&db_path, &storage_dir).unwrap();
        let source = SourceApplication::new("com.test.App".to_string(), "TestApp".to_string(), 1234);

        // Store same text twice
        let entry1 = store.store_text("Test text", source.clone()).unwrap();
        let entry2 = store.store_text("Test text", source).unwrap();

        // Should have same hash
        assert_eq!(entry1.content_hash, entry2.content_hash);

        // Should only have one entry in database
        let history = store.get_history(10, 0).unwrap();
        assert_eq!(history.len(), 1);
    }
}
