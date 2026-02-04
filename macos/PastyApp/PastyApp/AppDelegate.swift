//! Application Delegate for Pasty macOS app
//!
//! Manages application lifecycle and initializes the Rust core.

import Cocoa
import Foundation

class AppDelegate: NSObject, NSApplicationDelegate {

    // MARK: - Properties

    private var statusItem: NSStatusItem?

    // MARK: - Application Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSLog("PastyApp launched successfully")

        // Initialize the Rust core
        do {
            try PastyFFIBridge.shared.initialize()
            NSLog("Pasty core initialized successfully")
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
        NSLog("Setting up menu bar...")

        // Create status item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        guard let statusItem = statusItem else {
            NSLog("Failed to create status bar item")
            return
        }

        NSLog("Status bar item created successfully")

        if let button = statusItem.button {
            button.title = "Pasty"
            NSLog("Status bar button title set to: Pasty")
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

        statusItem.menu = menu
        NSLog("Menu bar setup complete")
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
