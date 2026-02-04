//! Main entry point for Pasty macOS application

import Cocoa

let app = NSApplication.shared
// Set as accessory app (menu bar only, no dock icon)
app.setActivationPolicy(.accessory)

let delegate = AppDelegate()
app.delegate = delegate

// Activate the app to ensure menu bar appears
NSApp.activate(ignoringOtherApps: true)

app.run()
