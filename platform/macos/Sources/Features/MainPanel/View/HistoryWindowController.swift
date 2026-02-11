// Pasty - Copyright (c) 2026. MIT License.

import Cocoa

final class HistoryWindowController: NSWindowController {
    convenience init() {
        let viewController = HistoryViewController()
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 980, height: 620),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Clipboard History"
        window.contentViewController = viewController
        self.init(window: window)
    }
}
