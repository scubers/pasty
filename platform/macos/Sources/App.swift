import Cocoa
import SwiftUI
import Combine
import QuartzCore
import KeyboardShortcuts
import PastyCore

@main
class App: NSObject, NSApplicationDelegate {
    static func shouldHandleEscape(keyCode: UInt16, appIsActive: Bool, panelIsVisible: Bool) -> Bool {
        return keyCode == 53 && appIsActive && panelIsVisible
    }

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
    private var localEventMonitor: Any?
    private var benchmarkCancellable: AnyCancellable?

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
        
        // UI Setup
        NSApp.setActivationPolicy(.accessory)
        
        setupDependencies()
        setupMenuBar()
        setupKeyboardMonitor()
        setupBindings()

        if ProcessInfo.processInfo.environment["PASTY_UI_BENCH"] == "1" {
            Task { @MainActor in
                await runUIBenchmark()
            }
            return
        }

        // Start Clipboard Watcher
        clipboardWatcher.start(interval: 0.4, onChange: { [weak self] in
            Task { @MainActor in
                self?.viewModel.send(.clipboardContentChanged)
            }
        })
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        clipboardWatcher.stop()
        if let localEventMonitor {
            NSEvent.removeMonitor(localEventMonitor)
            self.localEventMonitor = nil
        }
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
    private func setupKeyboardMonitor() {
        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else {
                return event
            }
            guard Self.shouldHandleEscape(
                keyCode: event.keyCode,
                appIsActive: NSApp.isActive,
                panelIsVisible: self.viewModel.state.isVisible
            ) else {
                return event
            }

            self.viewModel.send(.togglePanel)
            return nil
        }
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

    @MainActor
    private func runUIBenchmark() async {
        print("PASTY_UI_BENCH_START")
        var panelSamples = [Double]()
        for _ in 0..<20 {
            let start = CACurrentMediaTime()
            windowController.window?.makeKeyAndOrderFront(nil)
            windowController.window?.orderOut(nil)
            panelSamples.append((CACurrentMediaTime() - start) * 1000)
        }

        let searchMs = await measureSearchLatency(query: "test")
        let previewMs = await measurePreviewSwitchLatency()
        let listIterationMs = await measureListIterationLatency()

        let summary = [
            "panel_avg_ms": panelSamples.reduce(0, +) / Double(max(panelSamples.count, 1)),
            "panel_p95_ms": percentile(panelSamples, 0.95),
            "search_ms": searchMs,
            "preview_switch_ms": previewMs,
            "list_iteration_ms": listIterationMs,
        ]

        if let data = try? JSONSerialization.data(withJSONObject: summary, options: [.sortedKeys]),
           let text = String(data: data, encoding: .utf8) {
            print("PASTY_UI_BENCH_RESULT \(text)")
        }

        print("PASTY_UI_BENCH_END")
        NSApp.terminate(nil)
    }

    @MainActor
    private func measureSearchLatency(query: String) async -> Double {
        let start = CACurrentMediaTime()
        viewModel.send(.searchChanged(query))

        try? await Task.sleep(nanoseconds: 220_000_000)

        let timeout = CACurrentMediaTime() + 3.0
        while CACurrentMediaTime() < timeout {
            if !viewModel.state.isLoading {
                return (CACurrentMediaTime() - start) * 1000
            }
            try? await Task.sleep(nanoseconds: 20_000_000)
        }

        return (CACurrentMediaTime() - start) * 1000
    }

    @MainActor
    private func measurePreviewSwitchLatency() async -> Double {
        if viewModel.state.items.count < 2 {
            viewModel.send(.searchChanged(""))
            try? await Task.sleep(nanoseconds: 300_000_000)
        }

        guard viewModel.state.items.count >= 2 else {
            return 0
        }

        let first = viewModel.state.items[0]
        let second = viewModel.state.items[1]

        let start = CACurrentMediaTime()
        for _ in 0..<20 {
            viewModel.send(.itemSelected(first))
            viewModel.send(.itemSelected(second))
        }
        return ((CACurrentMediaTime() - start) * 1000) / 40.0
    }

    @MainActor
    private func measureListIterationLatency() async -> Double {
        if viewModel.state.items.isEmpty {
            viewModel.send(.searchChanged(""))
            try? await Task.sleep(nanoseconds: 300_000_000)
        }

        guard !viewModel.state.items.isEmpty else {
            return 0
        }

        let samples = Array(viewModel.state.items.prefix(50))
        let start = CACurrentMediaTime()
        for item in samples {
            viewModel.send(.itemSelected(item))
        }
        return ((CACurrentMediaTime() - start) * 1000) / Double(max(samples.count, 1))
    }

    private func percentile(_ values: [Double], _ p: Double) -> Double {
        guard !values.isEmpty else {
            return 0
        }
        let sorted = values.sorted()
        let index = min(sorted.count - 1, Int(Double(sorted.count - 1) * p))
        return sorted[index]
    }
}
