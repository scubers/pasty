import Foundation
import Cocoa

struct ImageHandler: ContentHandler {
    func handle(pasteboard: NSPasteboard, source: SourceApplication, coordinator: ClipboardCoordinator) {
        guard let imageData = pasteboard.data(forType: .png) ?? pasteboard.data(forType: .tiff) else {
            return
        }

        // Determine format
        let format: String
        if pasteboard.data(forType: .png) != nil {
            format = "png"
        } else {
            format = "tiff"
        }

        // Delegate to platform logic layer
        coordinator.storeImageContent(imageData, format: format, source: source)
    }
}
