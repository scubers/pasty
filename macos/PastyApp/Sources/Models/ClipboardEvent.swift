import Foundation

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

/// Clipboard content type enumeration
enum ClipboardContentType {
    case text
    case image
    case fileReference  // Logged only, not stored
    case unsupported    // Ignored
}
