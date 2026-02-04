use sha2::{Sha256, Digest};
use crate::models::{ContentType, Content};

/// Content hashing and deduplication service
pub struct DeduplicationService;

impl DeduplicationService {
    /// Calculate SHA-256 hash of text content
    pub fn hash_text(text: &str) -> String {
        let normalized = Self::normalize_text(text);
        let mut hasher = Sha256::new();
        hasher.update(normalized.as_bytes());
        format!("{:x}", hasher.finalize())
    }

    /// Calculate SHA-256 hash of image data
    pub fn hash_image(image_data: &[u8]) -> String {
        let mut hasher = Sha256::new();
        hasher.update(image_data);
        format!("{:x}", hasher.finalize())
    }

    /// Normalize text before hashing (trim whitespace)
    pub fn normalize_text(text: &str) -> String {
        text.trim().to_string()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_hash_text() {
        let hash1 = DeduplicationService::hash_text("Hello, World!");
        let hash2 = DeduplicationService::hash_text("Hello, World!");
        let hash3 = DeduplicationService::hash_text("Different text");

        assert_eq!(hash1, hash2);
        assert_ne!(hash1, hash3);
        assert_eq!(hash1.len(), 64); // SHA-256 produces 64 hex chars
    }

    #[test]
    fn test_hash_text_normalization() {
        let hash1 = DeduplicationService::hash_text("  Hello, World!  ");
        let hash2 = DeduplicationService::hash_text("Hello, World!");

        assert_eq!(hash1, hash2); // Should be same after trimming
    }

    #[test]
    fn test_hash_image() {
        let data1 = vec![1, 2, 3, 4, 5];
        let data2 = vec![1, 2, 3, 4, 5];
        let data3 = vec![5, 4, 3, 2, 1];

        let hash1 = DeduplicationService::hash_image(&data1);
        let hash2 = DeduplicationService::hash_image(&data2);
        let hash3 = DeduplicationService::hash_image(&data3);

        assert_eq!(hash1, hash2);
        assert_ne!(hash1, hash3);
    }

    #[test]
    fn test_normalize_text() {
        assert_eq!(
            DeduplicationService::normalize_text("  hello  "),
            "hello"
        );
        assert_eq!(
            DeduplicationService::normalize_text("\n\t  test  \t\n"),
            "test"
        );
        assert_eq!(
            DeduplicationService::normalize_text("no spaces"),
            "no spaces"
        );
    }
}
