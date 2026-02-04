//! Clipboard entry data model
//!
//! Represents a single clipboard content item with metadata.

use serde::{Deserialize, Serialize};

/// Represents a single clipboard entry with content and metadata
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ClipboardEntry {
    /// Unique identifier for this entry (UUID v4)
    pub id: String,

    /// Timestamp when entry was created (Unix timestamp)
    pub timestamp: i64,

    /// Content type (text, image, file, etc.)
    pub content_type: ContentType,

    /// Actual clipboard data
    pub data: ClipboardData,

    /// Source application that copied content (optional)
    pub source_app: Option<String>,

    /// Whether this entry is pinned/favorite
    pub is_pinned: bool,
}

impl ClipboardEntry {
    /// Create a new clipboard entry
    ///
    /// # Arguments
    /// * `content_type` - Type of clipboard content
    /// * `data` - The clipboard data
    ///
    /// # Returns
    /// A new ClipboardEntry with generated ID and current timestamp
    pub fn new(content_type: ContentType, data: ClipboardData) -> Self {
        use std::time::{SystemTime, UNIX_EPOCH};

        let timestamp = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_secs() as i64;

        ClipboardEntry {
            id: uuid::Uuid::new_v4().to_string(),
            timestamp,
            content_type,
            data,
            source_app: None,
            is_pinned: false,
        }
    }

    /// Validate that the entry's data matches its content type
    ///
    /// # Returns
    /// `true` if data matches content type, `false` otherwise
    pub fn validate(&self) -> bool {
        match (&self.content_type, &self.data) {
            (ContentType::Text, ClipboardData::Text(_)) => true,
            (ContentType::Image, ClipboardData::Image(_)) => true,
            (ContentType::File, ClipboardData::File(_)) => true,
            (ContentType::HTML, ClipboardData::HTML(_)) => true,
            (ContentType::Custom(_), _) => true, // Custom types are unvalidated
            _ => false,
        }
    }
}

/// Supported clipboard content types
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub enum ContentType {
    Text,
    Image,
    File,
    HTML,
    Custom(String),
}

/// Clipboard data variants
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum ClipboardData {
    Text(String),
    Image(Vec<u8>),  // Raw image bytes
    File(String),    // File path
    HTML(String),
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_clipboard_entry_creation() {
        let entry = ClipboardEntry::new(
            ContentType::Text,
            ClipboardData::Text("Hello, World!".to_string()),
        );

        assert!(!entry.id.is_empty());
        assert!(entry.timestamp > 0);
        assert_eq!(entry.content_type, ContentType::Text);
        assert!(entry.source_app.is_none());
        assert!(!entry.is_pinned);
    }

    #[test]
    fn test_clipboard_entry_validation_valid() {
        let entry = ClipboardEntry {
            id: "test-id".to_string(),
            timestamp: 12345,
            content_type: ContentType::Text,
            data: ClipboardData::Text("Test".to_string()),
            source_app: None,
            is_pinned: false,
        };

        assert!(entry.validate());
    }

    #[test]
    fn test_clipboard_entry_validation_invalid() {
        let entry = ClipboardEntry {
            id: "test-id".to_string(),
            timestamp: 12345,
            content_type: ContentType::Text,
            data: ClipboardData::Image(vec![1, 2, 3]),
            source_app: None,
            is_pinned: false,
        };

        assert!(!entry.validate());
    }
}
