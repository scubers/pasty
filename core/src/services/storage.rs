use std::path::{Path, PathBuf};
use std::fs::{self, File};
use std::io::Write;

/// Error types for storage operations
#[derive(Debug, thiserror::Error)]
pub enum StorageError {
    #[error("IO error: {0}")]
    Io(#[from] std::io::Error),

    #[error("Insufficient disk space")]
    InsufficientDiskSpace,

    #[error("Invalid path: {0}")]
    InvalidPath(String),
}

/// File system storage service for clipboard images
pub struct StorageService {
    base_dir: PathBuf,
}

impl StorageService {
    /// Create new storage service with base directory
    pub fn new<P: AsRef<Path>>(base_dir: P) -> Result<Self, StorageError> {
        let base_dir = base_dir.as_ref().to_path_buf();

        // Create base directory if it doesn't exist
        if !base_dir.exists() {
            fs::create_dir_all(&base_dir)?;
        }

        Ok(Self { base_dir })
    }

    /// Save image data to disk with hash-based sharding
    pub fn save_image(&self, hash: &str, data: &[u8], format: &str) -> Result<PathBuf, StorageError> {
        // Create two-level sharded directory: images/ab/cdef1234...
        let shard_dir = self.get_shard_directory(hash)?;
        fs::create_dir_all(&shard_dir)?;

        // Create file path with hash and extension
        let filename = format!("{}.{}", hash, format);
        let file_path = shard_dir.join(filename);

        // Write image data
        let mut file = File::create(&file_path)?;
        file.write_all(data)?;

        Ok(file_path)
    }

    /// Get sharded directory path for hash
    fn get_shard_directory(&self, hash: &str) -> Result<PathBuf, StorageError> {
        if hash.len() < 4 {
            return Err(StorageError::InvalidPath("Hash too short".to_string()));
        }

        // Use first 4 characters for sharding
        let shard = &hash[0..4];
        let shard_dir = self.base_dir.join(shard);

        Ok(shard_dir)
    }

    /// Get relative path from base directory for given hash
    pub fn get_relative_path(&self, hash: &str, format: &str) -> String {
        let shard = if hash.len() >= 4 { &hash[0..4] } else { "misc" };
        let filename = format!("{}.{}", hash, format);
        format!("{}/{}", shard, filename)
    }

    /// Delete image file by hash
    pub fn delete_image(&self, hash: &str, format: &str) -> Result<(), StorageError> {
        let relative_path = self.get_relative_path(hash, format);
        let file_path = self.base_dir.join(&relative_path);

        if file_path.exists() {
            fs::remove_file(file_path)?;
        }

        Ok(())
    }

    /// Check if image exists
    pub fn image_exists(&self, hash: &str, format: &str) -> bool {
        let relative_path = self.get_relative_path(hash, format);
        let file_path = self.base_dir.join(&relative_path);
        file_path.exists()
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::TempDir;

    #[test]
    fn test_storage_service_creation() {
        let temp_dir = TempDir::new().unwrap();
        let storage = StorageService::new(temp_dir.path()).unwrap();

        assert!(storage.base_dir.exists());
    }

    #[test]
    fn test_save_and_check_image() {
        let temp_dir = TempDir::new().unwrap();
        let storage = StorageService::new(temp_dir.path()).unwrap();

        let hash = "abc123def456";
        let data = b"fake image data";

        let path = storage.save_image(hash, data, "png").unwrap();
        assert!(path.exists());
        assert!(storage.image_exists(hash, "png"));
    }

    #[test]
    fn test_sharded_directory_structure() {
        let temp_dir = TempDir::new().unwrap();
        let storage = StorageService::new(temp_dir.path()).unwrap();

        let hash = "abcd1234";
        let data = b"test data";

        let path = storage.save_image(hash, data, "png").unwrap();

        // Should be in base_dir/abcd/abcd1234.png
        let expected_parent = storage.base_dir.join("abcd");
        assert_eq!(path.parent(), Some(expected_parent.as_path()));
    }

    #[test]
    fn test_get_relative_path() {
        let temp_dir = TempDir::new().unwrap();
        let storage = StorageService::new(temp_dir.path()).unwrap();

        let path = storage.get_relative_path("abcdef123456", "png");
        assert_eq!(path, "abcd/abcdef123456.png");
    }
}
