import Foundation
import Cocoa

struct TextHandler: ContentHandler {
    func handle(pasteboard: NSPasteboard, source: SourceApplication, coordinator: ClipboardCoordinator) {
        guard let text = pasteboard.string(forType: .string) else {
            return
        }

        // Delegate to platform logic layer
        coordinator.storeTextContent(text, source: source)
    }
}
