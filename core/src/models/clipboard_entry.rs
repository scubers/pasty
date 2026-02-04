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

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
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

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_clipboard_entry_creation() {
        let source = SourceApplication::new("com.apple.Safari".to_string(), "Safari".to_string(), 1234);
        let entry = ClipboardEntry::new(
            "abc123".to_string(),
            ContentType::Text,
            Content::Text("Hello, World!".to_string()),
            source,
        );

        assert_eq!(entry.content_type, ContentType::Text);
        assert_eq!(entry.content_hash, "abc123");
        assert!(matches!(entry.content, Content::Text(_)));
    }

    #[test]
    fn test_content_type_from_str() {
        assert_eq!(ContentType::from_str("text"), Some(ContentType::Text));
        assert_eq!(ContentType::from_str("image"), Some(ContentType::Image));
        assert_eq!(ContentType::from_str("invalid"), None);
    }

    #[test]
    fn test_image_format_extension() {
        assert_eq!(ImageFormat::from_extension("png"), ImageFormat::Png);
        assert_eq!(ImageFormat::from_extension("jpg"), ImageFormat::Jpeg);
        assert_eq!(ImageFormat::from_extension("jpeg"), ImageFormat::Jpeg);
        assert_eq!(ImageFormat::from_extension("gif"), ImageFormat::Gif);
        assert_eq!(ImageFormat::from_extension("unknown"), ImageFormat::Unknown);
    }

    #[test]
    fn test_update_latest_copy_time() {
        let source = SourceApplication::new("com.test.App".to_string(), "Test".to_string(), 1);
        let mut entry = ClipboardEntry::new(
            "hash".to_string(),
            ContentType::Text,
            Content::Text("test".to_string()),
            source,
        );

        let original_time = entry.latest_copy_time_ms;
        std::thread::sleep(std::time::Duration::from_millis(10));
        entry.update_latest_copy_time();

        assert!(entry.latest_copy_time_ms > original_time);
    }
}
