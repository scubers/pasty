import Cocoa
import SwiftUI
import Combine
import KeyboardShortcuts
import PastyCore

@main
class App: NSObject, NSApplicationDelegate {
    static func main() {
        let app = NSApplication.shared
        let delegate = App()
        app.delegate = delegate
        app.run()
    }

    // Core Components
    private var clipboardManager = pasty.ClipboardManager()
    private let clipboardWatcher = ClipboardWatcher()
    
    // UI Components
    private var statusItem: NSStatusItem!
    private var windowController: MainPanelWindowController!
    private var viewModel: MainPanelViewModel!
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Initialize Core
        let version = pasty.ClipboardManager.getVersion()
        print("Pasty2 Core v\(String(version))")
        
        let appDataPath = AppPaths.appDataDirectory().path
        
        // Copy migrations
        copyMigrations(to: AppPaths.appDataDirectory())
        
        appDataPath.withCString { pointer in
            pasty_history_set_storage_directory(pointer)
        }

        if clipboardManager.initialize() {
            print("Core initialized successfully")
        }
        
        // Start Clipboard Watcher
        clipboardWatcher.start(interval: 0.4)

        // UI Setup
        NSApp.setActivationPolicy(.accessory)
        
        setupDependencies()
        setupMenuBar()
        setupBindings()
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        clipboardWatcher.stop()
        clipboardManager.shutdown()
    }

    @MainActor
    private func setupDependencies() {
        let historyService = ClipboardHistoryServiceImpl()
        let hotkeyService = HotkeyServiceImpl()
        
        viewModel = MainPanelViewModel(
            historyService: historyService,
            hotkeyService: hotkeyService
        )
        
        windowController = MainPanelWindowController(viewModel: viewModel)
    }

    @MainActor
    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        if let button = statusItem.button {
            button.title = "📋"
        }
        
        let menu = NSMenu()
        let openItem = NSMenuItem(title: "Open Panel", action: #selector(openPanel), keyEquivalent: "")
        menu.addItem(openItem)
        menu.addItem(NSMenuItem.separator())
        let quitItem = NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)
        
        statusItem.menu = menu
    }
    
    @MainActor
    private func setupBindings() {
        viewModel.$state
            .map(\.isVisible)
            .removeDuplicates()
            .sink { [weak self] isVisible in
                if isVisible {
                    self?.showPanel()
                } else {
                    self?.hidePanel()
                }
            }
            .store(in: &cancellables)
    }

    @MainActor
    @objc private func openPanel() {
        viewModel.send(.showPanel)
    }
    
    @MainActor
    private func showPanel() {
        let mouseLocation = NSEvent.mouseLocation
        windowController.show(at: mouseLocation)
    }
    
    @MainActor
    private func hidePanel() {
        windowController.hide()
    }
    
    private func copyMigrations(to destination: URL) {
        let destMigrationsPath = destination.appendingPathComponent("migrations")
        let fileManager = FileManager.default
        let migrationFiles = [
            "0001-initial-schema.sql",
            "0002-add-search-index.sql",
            "0003-add-metadata.sql"
        ]

        do {
            if fileManager.fileExists(atPath: destMigrationsPath.path) {
                try fileManager.removeItem(at: destMigrationsPath)
            }
            try fileManager.createDirectory(at: destMigrationsPath, withIntermediateDirectories: true)

            var copiedCount = 0
            for migrationFile in migrationFiles {
                let name = (migrationFile as NSString).deletingPathExtension
                let ext = (migrationFile as NSString).pathExtension

                let sourceURL =
                    Bundle.main.url(forResource: name, withExtension: ext, subdirectory: "migrations")
                    ?? Bundle.main.url(forResource: name, withExtension: ext)

                guard let sourceURL else {
                    print("Migration file missing in bundle: \(migrationFile)")
                    continue
                }

                let destinationURL = destMigrationsPath.appendingPathComponent(migrationFile)
                try fileManager.copyItem(at: sourceURL, to: destinationURL)
                copiedCount += 1
            }

            print("Copied \(copiedCount)/\(migrationFiles.count) migrations to \(destMigrationsPath.path)")
        } catch {
            print("Failed to copy migrations: \(error)")
        }
    }
}
