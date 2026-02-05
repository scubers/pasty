//! Application Delegate for Pasty macOS app
//!
//! Manages application lifecycle and initializes the Rust core.

import Cocoa
import Foundation
import KeyboardShortcuts










class AppDelegate: NSObject, NSApplicationDelegate {

    // MARK: - Properties

    private var menuBarManager: MenuBarManager?
    private var clipboardMonitor: ClipboardMonitor?
    private var panelCoordinator: ClipboardPanelCoordinator?

    // MARK: - Application Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSLog("PastyApp launched successfully")

        // Set activation policy to .accessory to hide from Dock
        // This ensures the app doesn't appear in the Dock when running
        NSApp.setActivationPolicy(.accessory)
        NSLog("✓ Application activation policy set to .accessory (hidden from Dock)")

        // Get storage paths BEFORE initializing Rust
        let storageManager = StorageManager.shared
        let dbPath = storageManager.getDatabasePath().path
        let storagePath = storageManager.getImagesDirectory().path

        NSLog("Initializing clipboard store...")
        NSLog("Database path: \(dbPath)")
        NSLog("Images path: \(storagePath)")

        // Initialize Rust core with proper paths
        dbPath.withCString { dbPtr in
            storagePath.withCString { storagePtr in
                let result = pasty_clipboard_init(dbPtr, storagePtr)

                if result == 0 {
                    NSLog("✓ Pasty core initialized successfully")
                } else {
                    let errorPtr = pasty_get_last_error()
                    let error: String
                    if let ptr = errorPtr {
                        error = String(cString: ptr)
                    } else {
                        error = "Unknown error"
                    }
                    NSLog("Failed to initialize Pasty core: \(error)")

                    // Show alert to user
                    let alert = NSAlert()
                    alert.messageText = "Initialization Failed"
                    alert.informativeText = "Could not initialize clipboard store."
                    alert.alertStyle = .critical
                    alert.addButton(withTitle: "Quit")
                    alert.runModal()
                    NSApp.terminate(nil)
                }
            }
        }

        // Setup menu bar
        menuBarManager = MenuBarManager()

        // Start clipboard monitoring
        let detector = ContentTypeDetector()
        let coordinator = ClipboardCoordinator()

        clipboardMonitor = ClipboardMonitor(detector: detector, coordinator: coordinator)
        clipboardMonitor?.startMonitoring()

        NSLog("✓ Clipboard monitoring started")

        // Setup clipboard panel coordinator and global shortcut
        panelCoordinator = ClipboardPanelCoordinator()
        panelCoordinator?.setupGlobalShortcut()
        NSLog("✓ Global keyboard shortcut registered: ⌘+Shift+V")
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Stop clipboard monitoring
        clipboardMonitor?.stopMonitoring()
        NSLog("Clipboard monitoring stopped")

        // Shutdown the Rust core
        let result = pasty_shutdown()
        if result == 0 {
            NSLog("Pasty core shut down successfully")
        } else {
            NSLog("Failed to shutdown Pasty core")
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // This is a menu bar app, so don't terminate when last window closes
        return false
    }
}
