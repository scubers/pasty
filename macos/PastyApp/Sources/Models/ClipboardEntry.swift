import Foundation

/// Represents a stored clipboard entry from the database
struct ClipboardEntry {
    /// Unique identifier (UUID)
    let id: String

    /// Content hash for deduplication
    let contentHash: String

    /// Type of content (text or image)
    let contentType: ContentType

    /// When the entry was first created
    let timestamp: Date

    /// When this content was last copied (updated on duplicates)
    let latestCopyTime: Date

    /// The actual content
    let content: Content

    /// Source application information
    let source: SourceApplication
}

/// Content enumeration
enum Content {
    case text(String)
    case image(ImageFile)
}

/// Image file metadata
struct ImageFile {
    /// Relative path to image file
    let path: String

    /// File size in bytes
    let size: UInt64

    /// Image dimensions (optional)
    let dimensions: (width: Int, height: Int)?

    /// Image format
    let format: ImageFormat

    enum ImageFormat: Equatable {
        case png
        case jpg
        case jpeg
        case gif
        case bmp
        case unknown
    }
}
