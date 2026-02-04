import Foundation
import AppKit

/// Preview content for the preview panel
enum PreviewContent {
    case text(String)
    case image(NSImage)
    case empty  // No entry selected

    /// Check if content is empty
    var isEmpty: Bool {
        if case .empty = self {
            return true
        }
        return false
    }
}
