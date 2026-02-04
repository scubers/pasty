//! Application Delegate for Pasty macOS app
//!
//! Manages application lifecycle and initializes the Rust core.

import Cocoa
import Foundation

class AppDelegate: NSObject, NSApplicationDelegate {

    // MARK: - Application Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Initialize the Rust core
        do {
            try PastyFFIBridge.shared.initialize()
            print("Pasty core initialized successfully")
        } catch {
            let error = PastyFFIBridge.shared.getLastError() ?? "Unknown error"
            NSLog("Failed to initialize Pasty core: \(error)")
            // Show alert to user
            let alert = NSAlert()
            alert.messageText = "Initialization Failed"
            alert.informativeText = "Could not initialize Pasty core library."
            alert.alertStyle = .critical
            alert.addButton(withTitle: "Quit")
            alert.runModal()
            NSApp.terminate(nil)
        }

        // Setup menu bar
        setupMenuBar()
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Shutdown the Rust core
        do {
            try PastyFFIBridge.shared.shutdown()
            print("Pasty core shut down successfully")
        } catch {
            let error = PastyFFIBridge.shared.getLastError() ?? "Unknown error"
            NSLog("Failed to shutdown Pasty core: \(error)")
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // This is a menu bar app, so don't terminate when last window closes
        return false
    }

    // MARK: - Menu Bar Setup

    private func setupMenuBar() {
        let menuBar = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = menuBar.button {
            button.title = "📋"
        }

        let menu = NSMenu()

        // About menu item
        let aboutItem = NSMenuItem(
            title: "About Pasty",
            action: #selector(showAbout),
            keyEquivalent: ""
        )
        aboutItem.target = self
        menu.addItem(aboutItem)

        menu.addItem(NSMenuItem.separator())

        // Quit menu item
        let quitItem = NSMenuItem(
            title: "Quit Pasty",
            action: #selector(quitApplication),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        menuBar.menu = menu
    }

    // MARK: - Menu Actions

    @objc private func showAbout() {
        let alert = NSAlert()
        alert.messageText = "About Pasty"

        if let version = PastyFFIBridge.shared.getVersion() {
            alert.informativeText = "Pasty Clipboard Manager\nCore Version: \(version)\n\nA cross-platform clipboard manager"
        } else {
            alert.informativeText = "Pasty Clipboard Manager\n\nA cross-platform clipboard manager"
        }

        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    @objc private func quitApplication() {
        NSApp.terminate(nil)
    }
}
