import Foundation
import Cocoa

struct FileHandler: ContentHandler {
    func handle(pasteboard: NSPasteboard, source: SourceApplication, coordinator: ClipboardCoordinator) {
        // Log file/folder reference but don't store
        if let fileURLs = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] {
            for url in fileURLs {
                NSLog("[FileHandler] File reference detected: \(url.path)")
            }
        }
    }
}
