// Pasty2 - Copyright (c) 2026. MIT License.

import Cocoa
import PastyCore

@main
struct PastyApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var clipboardManager = pasty.ClipboardManager()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        let version = pasty.ClipboardManager.getVersion()
        let appName = pasty.ClipboardManager.getAppName()
        
        print("\(String(appName)) v\(String(version)) launched")
        
        if clipboardManager.initialize() {
            print("Core initialized successfully")
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        clipboardManager.shutdown()
        print("Core shutdown")
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
    
    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
}
