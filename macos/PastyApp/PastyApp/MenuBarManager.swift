//! Menu Bar Manager for Pasty macOS app
//!
//! Manages the status bar icon and menu items.

import Cocoa
import Foundation

/// Manages the application's menu bar interface
class MenuBarManager {

    // MARK: - Properties

    private var statusItem: NSStatusItem?

    // MARK: - Initialization

    init() {
        setupMenuBar()
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

        let menu = createMenu()
        statusItem.menu = menu

        NSLog("Menu bar setup complete")
    }

    // MARK: - Menu Creation

    private func createMenu() -> NSMenu {
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

        return menu
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
