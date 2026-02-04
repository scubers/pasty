import Foundation
import Cocoa

/// Protocol for content type-specific handlers
protocol ContentHandler {
    func handle(pasteboard: NSPasteboard, source: SourceApplication, coordinator: ClipboardCoordinator)
}

/// Factory for creating appropriate handlers
struct ContentHandlerFactory {
    static func handler(for type: ClipboardContentType) -> ContentHandler? {
        switch type {
        case .text:
            return TextHandler()
        case .image:
            return ImageHandler()
        case .fileReference:
            return FileHandler()
        case .unsupported:
            return nil
        }
    }
}
