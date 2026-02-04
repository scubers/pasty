use crate::models::{ClipboardEntry, ContentType, Content, SourceApplication};
use crate::services::database::{Database, DatabaseError};
use crate::services::deduplication::DeduplicationService;
use crate::services::storage::StorageService;
use std::path::Path;

/// High-level clipboard storage service
pub struct ClipboardStore {
    db: Database,
    storage: StorageService,
}

impl ClipboardStore {
    /// Create new clipboard store
    pub fn new<P: AsRef<Path>>(db_path: P, storage_base_dir: P) -> Result<Self, DatabaseError> {
        let db = Database::open(db_path)?;
        let storage = StorageService::new(storage_base_dir)
            .map_err(|e| DatabaseError::Connection(e.to_string()))?;

        Ok(Self { db, storage })
    }

    /// Store text clipboard entry with deduplication
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

    /// Store image clipboard entry with deduplication
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
            .map_err(|e| DatabaseError::Connection(e.to_string()))?;

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
