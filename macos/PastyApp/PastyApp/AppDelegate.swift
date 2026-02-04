//! Application Delegate for Pasty macOS app
//!
//! Manages application lifecycle and initializes the Rust core.

import Cocoa
import Foundation

class AppDelegate: NSObject, NSApplicationDelegate {

    // MARK: - Properties

    private var menuBarManager: MenuBarManager?

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
        menuBarManager = MenuBarManager()
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
}
