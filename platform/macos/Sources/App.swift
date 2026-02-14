import Cocoa
import SwiftUI
import Combine
import QuartzCore
import PastyCore

@main
class App: NSObject, NSApplicationDelegate {
    var coreRuntime: UnsafeMutableRawPointer? {
        appCoordinator.coreRuntime
    }


    static func main() {
        let app = NSApplication.shared
        let delegate = App()
        app.delegate = delegate
        app.run()
    }

    // Core Components
    private var clipboardWatcher: ClipboardWatcher!
    private var ocrService: OCRService!
    private let appCoordinator = AppCoordinator()
    private var settingsStore: SettingsStore!
    private var settingsViewModel: SettingsViewModel!
    
    // UI Components
    private var statusItem: NSStatusItem!
    private var windowController: MainPanelWindowController!
    private var viewModel: MainPanelViewModel!
    private var interactionService: MainPanelInteractionService!
    private var cancellables = Set<AnyCancellable>()
    private var localEventMonitor: Any?
    private var mouseDownMonitor: AnyCancellable?
    private var benchmarkCancellable: AnyCancellable?
    private var cloudSyncSettingsCancellable: AnyCancellable?
    private var cloudSyncImportTimer: AnyCancellable?
    private var lastSettingsWarningShown: String?
    @MainActor
    private var tagEditorHotkeyOwner: TagEditorHotkeyOwner?
    @MainActor
    private var tagEditorHotkeyToken: InAppHotkeyPermissionToken?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Initialize Logger
        LoggerService.shared.setup()
        LoggerService.info("Application started")

        // Initialize Core
        LoggerService.info("Pasty Core v0.1.0")

        settingsStore = SettingsStore(coordinator: appCoordinator)
        settingsViewModel = SettingsViewModel(coordinator: appCoordinator, settingsStore: settingsStore)
        clipboardWatcher = ClipboardWatcher(coordinator: appCoordinator)
        ocrService = OCRService(coordinator: appCoordinator)

        let clipboardDataPath = appCoordinator.clipboardData.path

        if let message = appCoordinator.lastWarningMessage {
            showSettingsWarningIfNeeded(message)
        }

        appCoordinator.events
            .compactMap { event -> String? in
                if case let .settingsWarning(message) = event {
                    return message
                }
                return nil
            }
            .sink { [weak self] message in
                Task { @MainActor in
                    self?.showSettingsWarningIfNeeded(message)
                }
            }
            .store(in: &cancellables)
        
        let runtime = pasty_runtime_create()
        appCoordinator.coreRuntime = runtime

        var coreStarted = false
        if let runtime {
            if let bundleMigrationsPath = Bundle.main.resourceURL?.appendingPathComponent("migrations") {
                coreStarted = clipboardDataPath.withCString { storagePointer in
                    bundleMigrationsPath.path.withCString { migrationPointer in
                        pasty_runtime_start(
                            runtime,
                            storagePointer,
                            migrationPointer,
                            Int32(appCoordinator.settings.history.maxCount)
                        )
                    }
                }
            } else {
                coreStarted = clipboardDataPath.withCString { storagePointer in
                    pasty_runtime_start(
                        runtime,
                        storagePointer,
                        nil,
                        Int32(appCoordinator.settings.history.maxCount)
                    )
                }
            }
        }

        if coreStarted {
            LoggerService.info("Core initialized successfully")
            settingsStore.syncCurrentSettingsToCore()
            if let runtime = appCoordinator.coreRuntime {
                initializeE2EEIfPossible(runtime: runtime, cloudSync: appCoordinator.settings.cloudSync)
            }
        } else {
            LoggerService.error("Core initialization failed")
        }

        setupCloudSyncImportLoop()
        
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
        clipboardWatcher.start(onChange: { [weak self] inserted in
            Task { @MainActor in
                self?.viewModel.send(.clipboardContentChanged(inserted: inserted))
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
        LoggerService.info("Application terminating")
        clipboardWatcher.stop()
        if let localEventMonitor {
            NSEvent.removeMonitor(localEventMonitor)
            self.localEventMonitor = nil
        }
        mouseDownMonitor?.cancel()
        mouseDownMonitor = nil
        cloudSyncImportTimer?.cancel()
        cloudSyncImportTimer = nil
        cloudSyncSettingsCancellable?.cancel()
        cloudSyncSettingsCancellable = nil
        tagEditorHotkeyToken?.resign()
        tagEditorHotkeyToken = nil
        tagEditorHotkeyOwner = nil
        if let runtime = appCoordinator.coreRuntime {
            pasty_runtime_stop(runtime)
            pasty_runtime_destroy(runtime)
            appCoordinator.coreRuntime = nil
        }
    }

    @MainActor
    private func setupDependencies() {
        let historyService = ClipboardHistoryServiceImpl(coordinator: appCoordinator)
        let hotkeyService = HotkeyServiceImpl()
        let interactionService = MainPanelInteractionServiceImpl()
        self.interactionService = interactionService
        
        viewModel = MainPanelViewModel(
            historyService: historyService,
            hotkeyService: hotkeyService,
            interactionService: interactionService,
            coordinator: appCoordinator
        )
        
        windowController = MainPanelWindowController(viewModel: viewModel, coordinator: appCoordinator)
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

        viewModel.$state
            .map(\.isTagEditorPresented)
            .removeDuplicates()
            .sink { [weak self] isTagEditorPresented in
                guard let self else {
                    return
                }

                if isTagEditorPresented {
                    if self.tagEditorHotkeyOwner == nil {
                        self.tagEditorHotkeyOwner = TagEditorHotkeyOwner(
                            isTagEditorPresented: { [weak self] in
                                self?.viewModel.state.isTagEditorPresented == true
                            },
                            onClose: { [weak self] in
                                self?.viewModel.send(.closeTagEditor)
                            },
                            onSave: { [weak self] in
                                guard self != nil else {
                                    return
                                }
                                NotificationCenter.default.post(name: .tagEditorSaveHotkeyTriggered, object: nil)
                            }
                        )
                    }

                    if let owner = self.tagEditorHotkeyOwner {
                        self.tagEditorHotkeyToken?.resign()
                        self.tagEditorHotkeyToken = InAppHotkeyPermissionManager.shared.request(owner: owner)
                    }
                } else {
                    self.tagEditorHotkeyToken?.resign()
                    self.tagEditorHotkeyToken = nil
                    self.tagEditorHotkeyOwner = nil
                }
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

            // Handle Cmd+q to quit
            if event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command,
               event.charactersIgnoringModifiers == "q" {
                NSApp.terminate(nil)
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
        SettingsWindowController.show(settingsViewModel: settingsViewModel, coordinator: appCoordinator)
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

    private func setupCloudSyncImportLoop() {
        cloudSyncSettingsCancellable = appCoordinator.$settings
            .map(\.cloudSync)
            .removeDuplicates()
            .sink { [weak self] cloudSync in
                self?.updateCloudSyncImportLoop(cloudSync: cloudSync)
            }
    }

    private func updateCloudSyncImportLoop(cloudSync: CloudSyncSettings) {
        LoggerService.info("Stopping cloud sync import timer")
        cloudSyncImportTimer?.cancel()
        cloudSyncImportTimer = nil

        guard cloudSync.enabled, !cloudSync.rootPath.isEmpty else {
            return
        }

        LoggerService.info("Starting cloud sync import timer")
        LoggerService.debug("Cloud sync import interval: 60 seconds")
        runCloudSyncImportNow()

        cloudSyncImportTimer = Timer
            .publish(every: 60, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.runCloudSyncImportNow()
            }
    }

    private func runCloudSyncImportNow() {
        guard let runtime = appCoordinator.coreRuntime else {
            return
        }
        let runtimeAddress = UInt(bitPattern: runtime)
        let cloudSync = appCoordinator.settings.cloudSync

        DispatchQueue.global(qos: .utility).async {
            guard let runtime = UnsafeMutableRawPointer(bitPattern: runtimeAddress) else {
                return
            }
            LoggerService.debug("Starting cloud sync import now")
            self.initializeE2EEIfPossible(runtime: runtime, cloudSync: cloudSync)
            let result = pasty_cloud_sync_import_now(runtime)
            LoggerService.info("Cloud sync import finished with result: \(result)")
        }
    }

    private func initializeE2EEIfPossible(runtime: UnsafeMutableRawPointer, cloudSync: CloudSyncSettings) {
        guard cloudSync.enabled else { return }
        let normalizedPath = cloudSync.rootPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedPath.isEmpty else { return }

        LoggerService.debug("Attempting to initialize E2EE for path: \(normalizedPath)")
        if let passphrase = KeychainService.getPassphrase(account: normalizedPath), !passphrase.isEmpty {
            LoggerService.debug("Passphrase found in keychain (length: \(passphrase.count))")
            pasty_cloud_sync_e2ee_initialize(runtime, passphrase)
            LoggerService.info("E2EE initialized successfully")
        } else {
            LoggerService.debug("No passphrase found in keychain for E2EE")
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
