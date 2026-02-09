import Cocoa
import SwiftUI

final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    private let hostingController: NSHostingController<SettingsView>
    static var shared: SettingsWindowController?

    init() {
        let view = SettingsView()
        self.hostingController = NSHostingController(rootView: view)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 400),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        
        window.title = "Settings"
        window.center()
        window.level = .floating // Keep above main panel
        window.isReleasedWhenClosed = false
        window.contentView = hostingController.view

        super.init(window: window)
        window.delegate = self
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    static func show() {
        if shared == nil {
            shared = SettingsWindowController()
        }
        shared?.showWindow(nil)
        shared?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func windowWillClose(_ notification: Notification) {
        SettingsWindowController.shared = nil
    }
}
