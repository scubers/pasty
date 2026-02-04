import Cocoa
import UniformTypeIdentifiers

/// Content type detection with priority ordering
struct ContentTypeDetector {

    /// Detects clipboard content type with priority ordering: text > image > file > unsupported
    func detectContentType(from pasteboard: NSPasteboard) -> ClipboardContentType {
        let types = pasteboard.types ?? []

        // Priority 1: Text (most common, always preferred if available)
        if types.contains(NSPasteboard.PasteboardType(UTType.text.identifier)) ||
           types.contains(NSPasteboard.PasteboardType(UTType.utf8PlainText.identifier)) {
            return .text
        }

        // Priority 2: Image
        if types.contains(NSPasteboard.PasteboardType(UTType.image.identifier)) {
            return .image
        }

        // Priority 3: File/folder reference
        if types.contains(NSPasteboard.PasteboardType(UTType.fileURL.identifier)) {
            return .fileReference
        }

        // Priority 4: Unsupported
        return .unsupported
    }
}
