import Cocoa
import SwiftUI

final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    private let hostingController: NSHostingController<AnyView>
    static var shared: SettingsWindowController?

    init(settingsViewModel: SettingsViewModel, coordinator: AppCoordinator) {
        let view = AnyView(
            SettingsView()
                .environmentObject(settingsViewModel)
                .environmentObject(coordinator)
        )
        self.hostingController = NSHostingController(rootView: view)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 550),
            styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView, .borderless],
            backing: .buffered,
            defer: false
        )
        
        window.title = "Settings"
        window.center()
        window.level = .floating // Keep above main panel
        window.isReleasedWhenClosed = false
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.backgroundColor = .clear
        window.isMovableByWindowBackground = false
        window.contentView = hostingController.view

        super.init(window: window)
        window.delegate = self
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    static func show(settingsViewModel: SettingsViewModel, coordinator: AppCoordinator) {
        if shared == nil {
            shared = SettingsWindowController(settingsViewModel: settingsViewModel, coordinator: coordinator)
        }
        shared?.showWindow(nil)
        shared?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func windowWillClose(_ notification: Notification) {
        SettingsWindowController.shared = nil
    }
}
