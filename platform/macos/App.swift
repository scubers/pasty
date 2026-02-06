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
    private let clipboardWatcher = ClipboardWatcher()
    private var historyWindowController: HistoryWindowController?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        let version = pasty.ClipboardManager.getVersion()
        let appName = pasty.ClipboardManager.getAppName()
        
        print("\(String(appName)) v\(String(version)) launched")
        
        let appDataPath = AppPaths.appDataDirectory().path
        appDataPath.withCString { pointer in
            pasty_history_set_storage_directory(pointer)
        }

        if clipboardManager.initialize() {
            print("Core initialized successfully")
        }

        clipboardWatcher.start(interval: 0.4)

        let windowController = HistoryWindowController()
        windowController.showWindow(nil)
        historyWindowController = windowController
    }

    func applicationWillTerminate(_ notification: Notification) {
        clipboardWatcher.stop()
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
