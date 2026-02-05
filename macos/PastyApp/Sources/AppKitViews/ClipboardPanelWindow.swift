import Cocoa
import Combine
import SwiftUI
import SnapKit

/// Main panel window (NSPanel) for clipboard history
/// Floating panel with NO title bar, matching design.jpeg
/// All keyboard shortcuts are handled at window level for consistent behavior
class ClipboardPanelWindow: NSPanel {
    // MARK: - Properties

    private let mainPanelViewModel: MainPanelViewModel
    private let previewPanelViewModel: PreviewPanelViewModel
    private var cancellables = Set<AnyCancellable>()

    // UI Components
    private let scrollView = NSScrollView()
    private let tableView: NSTableView
    private let emptyStateView = NSView()

    // Search and filter container (top bar, no title bar)
    private let topBarView = NSView()
    private var searchBarHost: NSHostingController<SearchBarView>?
    private var filterButtonsHost: NSHostingController<FilterButtonsView>?

    // Preview panel container (right side, 60%)
    private let previewContainerView = NSView()
    private var previewHost: NSHostingController<PreviewPanelView>?

    // Divider
    private let dividerView = NSView()
    private let footerView = NSView()

    // MARK: - Window Position Management (In-Memory)

    /// Store window frame in memory (not persisted)
    private var storedWindowFrame: NSRect?
    /// Store screen identifier where window was last shown
    private var lastScreenIdentifier: String?
    /// Store scroll position in memory
    private var storedScrollPosition: CGFloat?
    /// Track panel visibility state (used since hidesOnDeactivate doesn't change isVisible)
    private var panelIsShown = false
    private var previousActiveAppBundleId: String? = nil

    /// Returns true if panel is currently shown (including when hidden via hidesOnDeactivate)
    var isPanelShown: Bool {
        return panelIsShown
    }

    // MARK: - Initialization

    init(mainPanelViewModel: MainPanelViewModel, previewPanelViewModel: PreviewPanelViewModel) {
        self.mainPanelViewModel = mainPanelViewModel
        self.previewPanelViewModel = previewPanelViewModel
        self.tableView = NSTableView(frame: .zero)

        // Initialize panel - 520px width matching HTML design (1.06:0.94 split)
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 560),
            styleMask: [.borderless, .fullSizeContentView, .nonactivatingPanel, .resizable],
            backing: .buffered,
            defer: false
        )

        setupPanel()
        setupUI()
        setupLayout()
        setupBindings()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup

    private func setupPanel() {
        isFloatingPanel = true
        level = .popUpMenu
        isMovableByWindowBackground = true
        hidesOnDeactivate = true  // Hide when clicking outside or losing focus
        worksWhenModal = true

        // ✅ 关键：Window 本体透明（不要用 window.backgroundColor 来画半透明背景）
        isOpaque = false
        backgroundColor = .clear
        alphaValue = 1.0
        hasShadow = true

        if let contentView = contentView {
            contentView.wantsLayer = true
            contentView.layer?.cornerRadius = 16
            contentView.layer?.masksToBounds = true

            let visualEffectView = NSVisualEffectView()
            visualEffectView.material = .popover
            visualEffectView.blendingMode = .behindWindow
            visualEffectView.state = .active
            visualEffectView.wantsLayer = true
            visualEffectView.layer?.cornerRadius = 16
            visualEffectView.layer?.masksToBounds = true

            for subview in contentView.subviews {
                subview.removeFromSuperview()
                visualEffectView.addSubview(subview)
            }

            self.contentView = visualEffectView
        }

        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        isMovable = true
        collectionBehavior = [.fullScreenAuxiliary, .canJoinAllSpaces]
    }

    // Override to allow becoming key window
    override var canBecomeKey: Bool {
        return true
    }

    // Override to accept first responder for keyboard events
    override var acceptsFirstResponder: Bool {
        return true
    }

    private func setupUI() {
        // Setup scroll view and table view
        setupTableView()

        // Setup empty state view
        setupEmptyStateView()

        // Setup top bar (search + filters, NO title bar)
        setupTopBar()

        // Setup SwiftUI hosts
        setupSwiftUIHosts()

        // Setup preview panel
        setupPreviewPanel()

        setupFooterView()

        // Add subviews
        contentView?.addSubview(topBarView)
        contentView?.addSubview(scrollView)
        contentView?.addSubview(emptyStateView)
        contentView?.addSubview(dividerView)
        contentView?.addSubview(previewContainerView)
        contentView?.addSubview(footerView)
    }

    private func setupTableView() {
        // Configure table view - NO custom keyboard handling, we'll do it at window level
        let tv: NSTableView = tableView
        tv.delegate = self
        tv.dataSource = self
        tv.headerView = nil
        tv.intercellSpacing = NSSize(width: 0, height: 8)
        tv.backgroundColor = .clear
        tv.selectionHighlightStyle = .none
//        tv.rowHeight = 100
        tv.usesAutomaticRowHeights = false
        tv.allowsMultipleSelection = true
        tv.style = .plain

        // Add column
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("ClipboardColumn"))
//        column.width = 400
        tv.addTableColumn(column)

        // Configure scroll view
        scrollView.documentView = tv
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.scrollerStyle = .overlay
    }

    private func setupEmptyStateView() {
        emptyStateView.wantsLayer = true
//        emptyStateView.layer?.backgroundColor = NSColor(hex: "#1a1a1a").cgColor
        emptyStateView.isHidden = true

        // Create empty state label
        let label = NSTextField(labelWithString: "No clipboard entries yet")
        label.font = NSFont.systemFont(ofSize: 16, weight: .medium)
        label.textColor = NSColor(hex: "#666666")
        label.alignment = .center
        label.identifier = NSUserInterfaceItemIdentifier("EmptyStateLabel")

        // Create icon
        let imageView = NSImageView()
        if let icon = NSImage(systemSymbolName: "clipboard", accessibilityDescription: "Empty clipboard") {
            imageView.image = icon
            imageView.imageScaling = .scaleProportionallyUpOrDown
            imageView.contentTintColor = NSColor(hex: "#666666")
        }
        imageView.identifier = NSUserInterfaceItemIdentifier("EmptyStateIcon")

        emptyStateView.addSubview(label)
        emptyStateView.addSubview(imageView)

        // Layout with SnapKit
        imageView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalToSuperview().offset(-20)
            make.width.height.equalTo(64)
        }

        label.snp.makeConstraints { make in
            make.top.equalTo(imageView.snp.bottom).offset(16)
            make.centerX.equalToSuperview()
        }
    }

    private func setupTopBar() {
        topBarView.wantsLayer = true
//        topBarView.layer?.backgroundColor = NSColor.DesignColors.mat1.cgColor
    }

    private func setupSwiftUIHosts() {
        // Create search bar view
        let searchBarView = SearchBarView(viewModel: mainPanelViewModel)
        searchBarHost = NSHostingController(rootView: searchBarView)
        topBarView.addSubview(searchBarHost!.view)

        // Create filter buttons view
        let filterButtonsView = FilterButtonsView(viewModel: mainPanelViewModel)
        filterButtonsHost = NSHostingController(rootView: filterButtonsView)
        topBarView.addSubview(filterButtonsHost!.view)

        // Setup constraints for SwiftUI views with SnapKit
        setupSwiftUILayout()
    }

    private func setupSwiftUILayout() {
        guard let searchHostView = searchBarHost?.view,
              let filterHostView = filterButtonsHost?.view else {
            return
        }

        searchHostView.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(14)
            make.centerY.equalToSuperview()
            make.right.equalTo(filterHostView.snp.left).offset(-10)
            make.height.equalTo(36)
        }

        filterHostView.snp.makeConstraints { make in
            make.right.equalToSuperview().offset(-14)
            make.centerY.equalToSuperview()
            make.height.equalTo(32)
        }
    }

    private func setupPreviewPanel() {
        let previewPanelView = PreviewPanelView(viewModel: previewPanelViewModel)
        previewHost = NSHostingController(rootView: previewPanelView)
        previewContainerView.addSubview(previewHost!.view)

        dividerView.wantsLayer = true
        dividerView.layer?.backgroundColor = NSColor(hex: "#2a2a2e").cgColor

        previewHost!.view.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    private func setupFooterView() {
        let shortcuts = [
            ("↑↓", "Navigate"),
            ("↩", "Paste"),
            ("⌘↩", "Copy"),
            ("⌘D", "Delete"),
            ("Esc", "Close")
        ]

        var previousView: NSView?
        for (key, action) in shortcuts {
            let container = NSView()
            footerView.addSubview(container)

            let keyLabel = NSTextField(labelWithString: key)
            keyLabel.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
            keyLabel.textColor = NSColor(hex: "#888888")
            keyLabel.alignment = .center
            container.addSubview(keyLabel)

            let actionLabel = NSTextField(labelWithString: action)
            actionLabel.font = NSFont.systemFont(ofSize: 11)
            actionLabel.textColor = NSColor(hex: "#666666")
            container.addSubview(actionLabel)

            keyLabel.snp.makeConstraints { make in
                make.left.top.bottom.equalToSuperview()
            }

            actionLabel.snp.makeConstraints { make in
                make.left.equalTo(keyLabel.snp.right).offset(4)
                make.right.top.bottom.equalToSuperview()
            }

            if let previous = previousView {
                container.snp.makeConstraints { make in
                    make.left.equalTo(previous.snp.right).offset(16)
                    make.centerY.equalToSuperview()
                }
            } else {
                container.snp.makeConstraints { make in
                    make.left.equalToSuperview()
                    make.centerY.equalToSuperview()
                }
            }

            previousView = container
        }
    }

    private func setupLayout() {
        guard let contentView = contentView else { return }

        // Top bar height matching HTML (padding 14px top/bottom)
        topBarView.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.left.equalToSuperview()
            make.right.equalToSuperview()
            make.height.equalTo(54)
        }

        scrollView.snp.makeConstraints { make in
            make.top.equalTo(topBarView.snp.bottom).offset(12)
            make.left.equalToSuperview().offset(12)
            make.bottom.equalTo(footerView.snp.top).offset(-8)
            make.width.equalTo(contentView.snp.width).multipliedBy(0.40)
        }

        // Divider color matching HTML
        dividerView.layer?.backgroundColor = NSColor.DesignColors.stroke.cgColor

        // Divider (vertical) matching HTML layout
        dividerView.snp.makeConstraints { make in
            make.top.equalTo(scrollView.snp.top)
            make.left.equalTo(scrollView.snp.right).offset(12)
            make.bottom.equalTo(scrollView.snp.bottom)
            make.width.equalTo(1)
        }

        // Preview container (right side, 47% matching HTML layout)
        previewContainerView.snp.makeConstraints { make in
            make.top.equalTo(scrollView.snp.top)
            make.left.equalTo(dividerView.snp.right).offset(12)
            make.right.equalToSuperview().offset(-12)
            make.bottom.equalTo(scrollView.snp.bottom)
        }

        // Empty state view (overlays table view only)
        emptyStateView.snp.makeConstraints { make in
            make.top.equalTo(scrollView.snp.top)
            make.left.equalTo(scrollView.snp.left)
            make.right.equalTo(scrollView.snp.right)
            make.bottom.equalTo(scrollView.snp.bottom)
        }

        footerView.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(12)
            make.right.equalToSuperview().offset(-12)
            make.bottom.equalToSuperview().offset(-8)
            make.height.equalTo(20)
        }
    }

    private func setupBindings() {
        // Reload table view when entries change
        mainPanelViewModel.$filteredEntries
            .receive(on: DispatchQueue.main)
            .sink { [weak self] entries in
                self?.tableView.reloadData()
                self?.updateEmptyStateVisibility()
            }
            .store(in: &cancellables)

        // Update empty state visibility
        mainPanelViewModel.$isLoading
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isLoading in
                self?.updateEmptyStateVisibility()
            }
            .store(in: &cancellables)

        // Load preview when selection changes
        mainPanelViewModel.$selectedEntryId
            .compactMap { $0 }
            .removeDuplicates()
            .sink { [weak self] entryId in
                self?.previewPanelViewModel.loadPreviewContent(for: entryId)
                self?.selectRow(for: entryId)
            }
            .store(in: &cancellables)
    }

    // MARK: - Public Methods

    func showPanel() {
        mainPanelViewModel.handle(.loadEntries)

        // Restore scroll position from memory
        restoreScrollPosition()

        // Position window on mouse screen
        positionWindowOnMouseScreen()

        // Capture previous active app before activating this app
        previousActiveAppBundleId = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        mainPanelViewModel.previousActiveAppBundleId = previousActiveAppBundleId
        previewPanelViewModel.previousActiveAppBundleId = previousActiveAppBundleId

        // Mark panel as shown
        panelIsShown = true

        // Force activate this application BEFORE showing window
        NSApp.activate(ignoringOtherApps: true)

        // Small delay to ensure activation takes effect
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) { [weak self] in
            guard let self = self else { return }

            // Now make window key and front
            self.makeKeyAndOrderFront(nil)

            // Save current frame and screen identifier to memory
            self.storeCurrentPosition()

            // Use a loop to ensure window becomes key
            self.ensureWindowBecomesKey()
        }

        Logger.info("Clipboard panel shown")
    }

    /// Ensure the window becomes key using a retry loop
    /// This is necessary because macOS activation timing is unpredictable
    private func ensureWindowBecomesKey() {
        var attempts = 0
        let maxAttempts = 30  // 300ms max

        // Use DispatchQueue for better main thread handling
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            func checkKeyWindow() {
                attempts += 1

                if self.isKeyWindow {
                    NSLog("✅ Window became key after \(attempts) attempts")
                    Task { [weak self] in
                        await MainActor.run { [weak self] in
                            self?.mainPanelViewModel.handle(.loadEntries)
                            self?.selectFirstRowIfNeeded()
                        }
                    }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        self.focusSearchBar()
                    }
                    return
                }

                if attempts >= maxAttempts {
                    NSLog("⚠️ Could not make window key after \(attempts) attempts")
                    NSLog("   isKeyWindow: \(self.isKeyWindow), isVisible: \(self.isVisible)")
                    NSLog("   app is active: \(NSApp.isActive)")
                    return
                }

                // Force window to be key again
                self.makeKeyAndOrderFront(nil)

                // Retry after 10ms
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                    checkKeyWindow()
                }
            }

            checkKeyWindow()
        }
    }

    func hidePanel() {
        // Save scroll position to memory before closing
        saveScrollPosition()

        // Mark panel as hidden
        panelIsShown = false

        orderOut(nil)

        restorePreviousAppFocus()

        Logger.info("Clipboard panel hidden")
    }

    // MARK: - Focus Management

    /// Focus the search bar text field
    private func focusSearchBar() {
        guard let searchBarHost = searchBarHost else {
            NSLog("⚠️ Search bar host is nil")
            return
        }

        NSLog("🔍 Attempting to focus search bar...")

        // Make the window key first
        makeKey()

        // Try to find the NSTextField in the SwiftUI view hierarchy
        if let textField = findTextField(in: searchBarHost.view) {
            _ = makeFirstResponder(textField)
            NSLog("🔍 Search bar focused successfully: \(textField)")
        } else {
            NSLog("⚠️ Could not find search bar text field, falling back to window")
            // Fallback: print view hierarchy for debugging
            printViewHierarchy(searchBarHost.view, level: 0)
        }
    }

    private func selectFirstRowIfNeeded() {
        let rowCount = mainPanelViewModel.filteredEntries.count
        guard rowCount > 0 else { return }

        let entry = mainPanelViewModel.filteredEntries[0]
        mainPanelViewModel.handle(.selectEntry(id: entry.id))
        NSLog("✅ Auto-selected first row")
    }

    /// Recursively find NSTextField in view hierarchy
    private func findTextField(in view: NSView) -> NSTextField? {
        // Check if this view is an NSTextField
        if let textField = view as? NSTextField {
            // Make sure it's an editable text field (not a label)
            if textField.isEditable {
                NSLog("✅ Found editable NSTextField: \(textField)")
                return textField
            }
        }

        // Check for NSClipView (contains NSTextView for editable fields)
        if let clipView = view as? NSClipView {
            for subview in clipView.subviews {
                if let textView = subview as? NSTextView {
                    NSLog("✅ Found NSTextView in clipView: \(textView)")
                    // Return the clipView's documentView or the textView itself
                    // We need to find the parent field editor
                    return findParentTextField(for: textView)
                }
            }
        }

        // Recursively search subviews
        for subview in view.subviews {
            if let found = findTextField(in: subview) {
                return found
            }
        }

        return nil
    }

    /// Find the parent NSTextField for a given NSTextView
    private func findParentTextField(for textView: NSTextView) -> NSTextField? {
        // Text views are usually embedded in NSScrollView -> NSClipView hierarchy
        // The actual NSTextField might be the delegate or accessible via superview
        var currentView: NSView? = textView
        while let view = currentView {
            if let textField = view as? NSTextField {
                return textField
            }
            currentView = view.superview
        }
        return nil
    }

    /// Print view hierarchy for debugging
    private func printViewHierarchy(_ view: NSView?, level: Int) {
        guard let view = view else { return }
        let indent = String(repeating: "  ", count: level)
        let className = String(describing: type(of: view))
        NSLog("\(indent)\(className) - frame: \(view.frame)")

        for subview in view.subviews {
            printViewHierarchy(subview, level: level + 1)
        }
    }

    // MARK: - Window-Level Keyboard Event Handling

    /// Intercept events to handle keyboard navigation even when TextField has focus
    override func sendEvent(_ event: NSEvent) {
        if handleKeyDown(event) {
            return
        }

        super.sendEvent(event)
    }

    override func keyDown(with event: NSEvent) {
        if handleKeyDown(event) {
            return
        }

        super.keyDown(with: event)
    }

    private func handleKeyDown(_ event: NSEvent) -> Bool {
        guard event.type == .keyDown else {
            return false
        }

        let keyCode = event.keyCode
        let isCommand = event.modifierFlags.contains(.command)
        let characters = event.charactersIgnoringModifiers?.lowercased()

        if isCommand && keyCode == 36 {
            NSLog("⌘⏎ Cmd+Enter - copy only")
            copySelectedAndClose()
            return true
        }

        if isCommand && characters == "d" {
            NSLog("⌘D Cmd+D - deleting selected")
            deleteSelected()
            return true
        }

        switch keyCode {
        case 53: // Escape
            hidePanel()
            return true
        case 125: // Down arrow
            selectNextRow()
            return true
        case 126: // Up arrow
            selectPreviousRow()
            return true
        case 36: // Enter
            pasteSelectedAndClose()
            return true
        default:
            return false
        }
    }

    // MARK: - Keyboard Actions

    private func selectNextRow() {
        let rowCount = mainPanelViewModel.filteredEntries.count
        guard rowCount > 0 else { return }
        let currentIndex = mainPanelViewModel.selectedEntryId
            .flatMap { id in
                mainPanelViewModel.filteredEntries.firstIndex(where: { $0.id == id })
            } ?? -1

        let nextIndex = currentIndex < 0 ? 0 : (currentIndex + 1 >= rowCount ? 0 : currentIndex + 1)
        let entry = mainPanelViewModel.filteredEntries[nextIndex]
        mainPanelViewModel.handle(.selectEntry(id: entry.id))
        NSLog("✅ Selected row: \(nextIndex)")
    }

    private func selectPreviousRow() {
        let rowCount = mainPanelViewModel.filteredEntries.count
        guard rowCount > 0 else { return }
        let currentIndex = mainPanelViewModel.selectedEntryId
            .flatMap { id in
                mainPanelViewModel.filteredEntries.firstIndex(where: { $0.id == id })
            } ?? 0

        let previousIndex = currentIndex <= 0 ? rowCount - 1 : currentIndex - 1
        let entry = mainPanelViewModel.filteredEntries[previousIndex]
        mainPanelViewModel.handle(.selectEntry(id: entry.id))
        NSLog("✅ Selected row: \(previousIndex)")
    }

    private func pasteSelectedAndClose() {
        guard let selectedId = mainPanelViewModel.selectedEntryId else {
            NSLog("⚠️ No row selected")
            return
        }

        hidePanel()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
            self?.mainPanelViewModel.handle(.pasteEntry(id: selectedId))
            NSLog("✅ Copied and pasted: \(selectedId)")
        }
    }

    private func copySelected() {
        guard let selectedId = mainPanelViewModel.selectedEntryId else {
            NSLog("⚠️ No row selected")
            return
        }

        mainPanelViewModel.handle(.copyEntry(id: selectedId))
        NSLog("✅ Copied: \(selectedId)")
    }

    private func copySelectedAndClose() {
        copySelected()
        hidePanel()
    }

    private func deleteSelected() {
        let ids = mainPanelViewModel.selectedEntryIds
        guard !ids.isEmpty else { return }

        if ids.count == 1 {
            mainPanelViewModel.handle(.deleteEntry(id: ids[0]))
        } else {
            mainPanelViewModel.handle(.deleteEntries(ids: ids))
        }

        NSLog("✅ Deleted \(ids.count) entr\(ids.count == 1 ? "y" : "ies")")
    }

    private func selectRow(for entryId: String) {
        guard let index = mainPanelViewModel.filteredEntries.firstIndex(where: { $0.id == entryId }) else {
            return
        }
        tableView.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
        tableView.scrollRowToVisible(index)
    }

    // MARK: - Window Position Management

    /// Reposition panel to mouse screen (for cross-screen scenarios)
    /// This is called by shortcut when panel is already visible
    func repositionToMouseScreen() {
        NSLog("🔔 Repositioning panel to mouse screen")
        positionWindowOnMouseScreen()
        makeKeyAndOrderFront(nil)
    }

    private func saveScrollPosition() {
        let scrollPosition = scrollView.contentView.bounds.origin.y
        storedScrollPosition = scrollPosition
        Logger.debug("Saved scroll position to memory: \(scrollPosition)")
    }

    private func restoreScrollPosition() {
        guard let savedPosition = storedScrollPosition else {
            Logger.debug("No saved scroll position in memory")
            return
        }
        let point = NSPoint(x: 0, y: savedPosition)
        scrollView.contentView.scroll(point)
        Logger.debug("Restored scroll position from memory: \(savedPosition)")
    }

    private func storeCurrentPosition() {
        storedWindowFrame = frame
        lastScreenIdentifier = NSScreen.screens.first(where: { screen in
            screen.frame.contains(frame.origin)
        })?.localizedName

        Logger.debug("Stored window frame to memory: \(frame)")
        Logger.debug("Stored screen identifier: \(lastScreenIdentifier ?? "unknown")")
    }

    private func getMouseScreen() -> NSScreen? {
        let mouseLocation = NSEvent.mouseLocation
        return NSScreen.screens.first { screen in
            screen.frame.contains(mouseLocation)
        }
    }

    private func calculateDefaultPosition(on screen: NSScreen) -> NSRect {
        let screenFrame = screen.visibleFrame
        let windowSize = frame.size

        let x = screenFrame.midX - (windowSize.width / 2)
        let y = screenFrame.midY - (windowSize.height / 4)

        var defaultFrame = NSRect(x: x, y: y, width: windowSize.width, height: windowSize.height)

        // Ensure window stays within screen bounds
        if defaultFrame.maxX > screenFrame.maxX {
            defaultFrame.origin.x = screenFrame.maxX - defaultFrame.width
        }
        if defaultFrame.minX < screenFrame.minX {
            defaultFrame.origin.x = screenFrame.minX
        }
        if defaultFrame.maxY > screenFrame.maxY {
            defaultFrame.origin.y = screenFrame.maxY - defaultFrame.height
        }
        if defaultFrame.minY < screenFrame.minY {
            defaultFrame.origin.y = screenFrame.minY
        }

        let _ = screen.localizedName
        Logger.debug("Calculated default position on screen: \(defaultFrame)")

        return defaultFrame
    }

    private func positionWindowOnMouseScreen() {
        guard let mouseScreen = getMouseScreen() else {
            Logger.warning("Could not determine mouse screen, using default position")
            let mainScreen = NSScreen.main ?? NSScreen.screens[0]
            let defaultPos = calculateDefaultPosition(on: mainScreen)
            setFrame(defaultPos, display: true)
            return
        }

        let currentScreenId = mouseScreen.localizedName

        if let lastScreenId = lastScreenIdentifier,
           lastScreenId == currentScreenId,
           let savedFrame = storedWindowFrame {
            Logger.debug("Same screen as last time, restoring saved position: \(savedFrame)")
            setFrame(savedFrame, display: true)
        } else {
            Logger.debug("Different screen or first show, using default position")
            let defaultPos = calculateDefaultPosition(on: mouseScreen)
            setFrame(defaultPos, display: true)
        }
    }

    // MARK: - Private Methods

    private func updateEmptyStateVisibility() {
        let hasNoResults = mainPanelViewModel.filteredEntries.isEmpty && !mainPanelViewModel.isLoading

        if hasNoResults {
            emptyStateView.isHidden = false
            scrollView.isHidden = true

            if let label = emptyStateView.subviews.first(where: { $0.identifier?.rawValue == "EmptyStateLabel" }) as? NSTextField,
               let imageView = emptyStateView.subviews.first(where: { $0.identifier?.rawValue == "EmptyStateIcon" }) as? NSImageView {

                if mainPanelViewModel.allEntries.isEmpty {
                    label.stringValue = "No clipboard entries yet"
                    if let icon = NSImage(systemSymbolName: "clipboard", accessibilityDescription: "Empty clipboard") {
                        imageView.image = icon
                    }
                } else {
                    label.stringValue = "No results found"
                    if let icon = NSImage(systemSymbolName: "magnifyingglass", accessibilityDescription: "No results") {
                        imageView.image = icon
                    }
                }
            }
        } else {
            emptyStateView.isHidden = true
            scrollView.isHidden = false
        }
    }

    // MARK: - NSWindowDelegate

    override func close() {
        hidePanel()
    }

    /// Called when window resigns key status (including when hidesOnDeactivate triggers)
    /// We need to sync our panelIsShown state since hidesOnDeactivate doesn't call hidePanel()
    override func resignKey() {
        super.resignKey()

        // If hidesOnDeactivate is true and we're still marked as shown, sync the state
        // This happens when user clicks outside the panel
        if panelIsShown {
            NSLog("🔔 Window resigned key while panel marked as shown, syncing state")
            saveScrollPosition()
            panelIsShown = false
            restorePreviousAppFocus()
        }
    }

    private func restorePreviousAppFocus() {
        guard let previousBundleId = previousActiveAppBundleId else { return }
        guard previousBundleId != Bundle.main.bundleIdentifier else { return }

        if let app = NSRunningApplication.runningApplications(withBundleIdentifier: previousBundleId).first {
            app.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
        }
    }
}

// MARK: - NSTableViewDataSource

extension ClipboardPanelWindow: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return mainPanelViewModel.filteredEntries.count
    }
}

// MARK: - NSTableViewDelegate

extension ClipboardPanelWindow: NSTableViewDelegate {
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let identifier = NSUserInterfaceItemIdentifier("ClipboardCellView")

        var cellView = tableView.makeView(withIdentifier: identifier, owner: nil) as? NSTableCellView

        if cellView == nil {
            cellView = ClipboardTableCellView()
            cellView?.identifier = identifier
        }

        guard let cellView = cellView,
              row < mainPanelViewModel.filteredEntries.count else {
            return nil
        }

        let entry = mainPanelViewModel.filteredEntries[row]

        if let clipboardCell = cellView as? ClipboardTableCellView {
            clipboardCell.viewModel = mainPanelViewModel
            clipboardCell.configure(with: entry)
            // Set selected state based on current table view selection
            clipboardCell.isSelected = mainPanelViewModel.selectedEntryIds.contains(entry.id)
        }

        return cellView
    }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        return 72
    }

    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        guard row < mainPanelViewModel.filteredEntries.count else {
            return false
        }

        let entry = mainPanelViewModel.filteredEntries[row]
        mainPanelViewModel.handle(.selectEntry(id: entry.id))

        return true
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        var selectedIds: [String] = []
        for row in tableView.selectedRowIndexes {
            guard row >= 0, row < mainPanelViewModel.filteredEntries.count else { continue }
            selectedIds.append(mainPanelViewModel.filteredEntries[row].id)
        }
        mainPanelViewModel.setSelectedEntryIds(selectedIds)

        let visibleRows = tableView.visibleRows
        for row in visibleRows {
            if let cellView = tableView.view(atColumn: 0, row: row, makeIfNecessary: false) as? ClipboardTableCellView,
               row < mainPanelViewModel.filteredEntries.count {
                let entry = mainPanelViewModel.filteredEntries[row]
                cellView.isSelected = mainPanelViewModel.selectedEntryIds.contains(entry.id)
            }
        }
    }
}

// MARK: - NSTableView Extension

extension NSTableView {
    var visibleRows: IndexSet {
        guard let visibleRect = superview?.visibleRect else { return IndexSet() }
        let rows = rows(in: visibleRect)
        return IndexSet(rows.lowerBound..<rows.upperBound)
    }
}

// MARK: - NSColor Extension for Hex Support

extension NSColor {
    convenience init(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)

        let r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
        let g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
        let b = CGFloat(rgb & 0x0000FF) / 255.0

        self.init(red: r, green: g, blue: b, alpha: 1.0)
    }
}
