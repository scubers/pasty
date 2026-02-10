import Cocoa
import SwiftUI
import Combine
import QuartzCore
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
    private let ocrService = OCRService.shared
    
    // UI Components
    private var statusItem: NSStatusItem!
    private var windowController: MainPanelWindowController!
    private var viewModel: MainPanelViewModel!
    private var interactionService: MainPanelInteractionService!
    private var cancellables = Set<AnyCancellable>()
    private var localEventMonitor: Any?
    private var mouseDownMonitor: AnyCancellable?
    private var benchmarkCancellable: AnyCancellable?
    private var lastSettingsWarningShown: String?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Initialize Core
        let version = pasty.ClipboardManager.getVersion()
        print("Pasty2 Core v\(String(version))")
        
        let settingsManager = SettingsManager.shared
        let clipboardDataPath = settingsManager.clipboardData.path

        if let message = settingsManager.lastWarningMessage {
            showSettingsWarningIfNeeded(message)
        }

        NotificationCenter.default
            .publisher(for: .pastySettingsWarning)
            .compactMap { $0.userInfo?["message"] as? String }
            .sink { [weak self] message in
                Task { @MainActor in
                    self?.showSettingsWarningIfNeeded(message)
                }
            }
            .store(in: &cancellables)
        
        if let bundleMigrationsPath = Bundle.main.resourceURL?.appendingPathComponent("migrations") {
            bundleMigrationsPath.path.withCString { pointer in
                pasty_history_set_migration_directory(pointer)
            }
        }
        
        clipboardDataPath.withCString { pointer in
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
        setupOutsideClickMonitor()
        setupBindings()

        if ProcessInfo.processInfo.environment["PASTY_UI_BENCH"] == "1" {
            Task { @MainActor in
                await runUIBenchmark()
            }
            return
        }

        // Start Clipboard Watcher
        clipboardWatcher.start(onChange: { [weak self] in
            Task { @MainActor in
                self?.viewModel.send(.clipboardContentChanged)
            }
        })

        ocrService.start()
    }

    @MainActor
    private func showSettingsWarningIfNeeded(_ message: String) {
        guard lastSettingsWarningShown != message else {
            return
        }
        lastSettingsWarningShown = message

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Settings Warning"
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        clipboardWatcher.stop()
        if let localEventMonitor {
            NSEvent.removeMonitor(localEventMonitor)
            self.localEventMonitor = nil
        }
        mouseDownMonitor?.cancel()
        mouseDownMonitor = nil
        clipboardManager.shutdown()
    }

    @MainActor
    private func setupDependencies() {
        let historyService = ClipboardHistoryServiceImpl()
        let hotkeyService = HotkeyServiceImpl()
        let interactionService = MainPanelInteractionServiceImpl()
        self.interactionService = interactionService
        
        viewModel = MainPanelViewModel(
            historyService: historyService,
            hotkeyService: hotkeyService,
            interactionService: interactionService
        )
        
        windowController = MainPanelWindowController(viewModel: viewModel)
    }

    @MainActor
    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            button.image = NSImage(named: "StatusBarIcon")
            button.image?.isTemplate = true
        }
        
        let menu = NSMenu()
        let openItem = NSMenuItem(title: "Open Panel", action: #selector(openPanel), keyEquivalent: "")
        menu.addItem(openItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ",")
        menu.addItem(settingsItem)
        
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

        viewModel.$state
            .map(\.pendingDeleteItem)
            .sink { [weak self] pendingItem in
                guard let self else {
                    return
                }
                guard pendingItem != nil else {
                    return
                }
                guard self.windowController.window?.attachedSheet == nil else {
                    return
                }
                self.showDeleteConfirmation()
            }
            .store(in: &cancellables)
    }

    @MainActor
    private func setupKeyboardMonitor() {
        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            // Handle Cmd+, to open settings
            if event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command,
               event.charactersIgnoringModifiers == "," {
                self?.openSettings()
                return nil
            }

            if InAppHotkeyPermissionManager.shared.handle(event: event) {
                return nil
            }
            return event
        }
    }

    @MainActor
    @objc private func openPanel() {
        viewModel.send(.showPanel)
    }
    
    @MainActor
    @objc private func openSettings() {
        SettingsWindowController.show()
    }
    
    @MainActor
    private func showPanel() {
        let tracker = interactionService.trackAndRestoreFrontmostApplication()
        viewModel.send(.frontmostApplicationTracked(tracker))
        let mouseLocation = NSEvent.mouseLocation
        windowController.show(at: mouseLocation)
    }
    
    @MainActor
    private func hidePanel() {
        windowController.hide()
        interactionService.restoreFrontmostApplication()
    }

    @MainActor
    private func setupOutsideClickMonitor() {
        mouseDownMonitor = NotificationCenter.default
            .publisher(for: NSApplication.didResignActiveNotification)
            .sink { [weak self] _ in
                self?.viewModel.send(.hidePanel)
            }
    }

    @MainActor
    private var deleteConfirmationToken: InAppHotkeyPermissionToken?

    @MainActor
    private func showDeleteConfirmation() {
        guard viewModel.state.pendingDeleteItem != nil,
              let window = windowController.window else {
            return
        }

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Delete clipboard item"
        alert.informativeText = "Delete this record from clipboard history? This action cannot be undone."
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")
        
        let deleteOwner = DeleteConfirmationHotkeyOwner(
            alert: alert,
            onConfirm: { [weak self] in
                self?.viewModel.send(.deleteSelectedConfirmed)
            },
            onCancel: { [weak self] in
                self?.viewModel.send(.cancelDelete)
            }
        )
        
        deleteConfirmationToken?.resign()
        deleteConfirmationToken = InAppHotkeyPermissionManager.shared.request(owner: deleteOwner)

        alert.beginSheetModal(for: window) { [weak self] response in
            guard let self else {
                return
            }
            if response == .alertFirstButtonReturn {
                self.viewModel.send(.deleteSelectedConfirmed)
            } else {
                self.viewModel.send(.cancelDelete)
            }
            self.deleteConfirmationToken?.resign()
            self.deleteConfirmationToken = nil
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
