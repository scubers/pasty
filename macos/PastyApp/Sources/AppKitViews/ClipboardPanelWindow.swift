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

    // Window persistence keys
    private let windowFrameKey = "clipboardPanelWindowFrame"

    // MARK: - Initialization

    init(mainPanelViewModel: MainPanelViewModel, previewPanelViewModel: PreviewPanelViewModel) {
        self.mainPanelViewModel = mainPanelViewModel
        self.previewPanelViewModel = previewPanelViewModel
        self.tableView = NSTableView(frame: .zero)

        // Initialize panel - 40/60 split layout
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 1000, height: 600),
            styleMask: [.borderless, .fullSizeContentView],
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
        // Floating panel behavior - but allow keyboard input
        isFloatingPanel = true
        level = .popUpMenu  // Use popUpMenu level for highest priority
        isMovableByWindowBackground = true
        hidesOnDeactivate = false

        // IMPORTANT: Allow panel to become key window for keyboard input
        worksWhenModal = true

        // Appearance - Dark theme matching design
        backgroundColor = NSColor(hex: "#1a1a1a")
        alphaValue = 0.98
        if let contentView = contentView {
            contentView.wantsLayer = true
            contentView.layer?.cornerRadius = 12
        }

        // NO title bar
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        isMovable = true

        // Collection behavior - allow keyboard input and participate in window cycle
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

        // Add subviews
        contentView?.addSubview(topBarView)
        contentView?.addSubview(scrollView)
        contentView?.addSubview(emptyStateView)
        contentView?.addSubview(dividerView)
        contentView?.addSubview(previewContainerView)
    }

    private func setupTableView() {
        // Configure table view - NO custom keyboard handling, we'll do it at window level
        let tv: NSTableView = tableView
        tv.delegate = self
        tv.dataSource = self
        tv.headerView = nil
        tv.intercellSpacing = NSSize(width: 0, height: 8)
        tv.backgroundColor = .clear
        tv.selectionHighlightStyle = .regular
        tv.rowHeight = 64
        tv.usesAutomaticRowHeights = false
        tv.allowsMultipleSelection = true
        tv.style = .plain

        // Add column
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("ClipboardColumn"))
        column.width = 400
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
        emptyStateView.layer?.backgroundColor = NSColor(hex: "#1a1a1a").cgColor
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
        topBarView.layer?.backgroundColor = NSColor(hex: "#1a1a1a").cgColor
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
            make.left.equalToSuperview().offset(16)
            make.centerY.equalToSuperview()
            make.height.equalTo(36)
        }

        filterHostView.snp.makeConstraints { make in
            make.left.equalTo(searchHostView.snp.right).offset(12)
            make.right.lessThanOrEqualToSuperview().offset(-16)
            make.centerY.equalToSuperview()
            make.height.equalTo(32)
        }
    }

    private func setupPreviewPanel() {
        // Create preview panel view
        let previewPanelView = PreviewPanelView(viewModel: previewPanelViewModel)
        previewHost = NSHostingController(rootView: previewPanelView)
        previewContainerView.addSubview(previewHost!.view)

        // Setup divider
        dividerView.wantsLayer = true
        dividerView.layer?.backgroundColor = NSColor(hex: "#333333").cgColor

        // Layout with SnapKit
        previewHost!.view.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    private func setupLayout() {
        guard let contentView = contentView else { return }

        // Top bar (search + filters, full width)
        topBarView.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.left.equalToSuperview()
            make.right.equalToSuperview()
            make.height.equalTo(48)
        }

        // Table view (left side, 40%)
        scrollView.snp.makeConstraints { make in
            make.top.equalTo(topBarView.snp.bottom).offset(12)
            make.left.equalToSuperview().offset(16)
            make.bottom.equalToSuperview().offset(-16)
            make.width.equalTo(contentView.snp.width).multipliedBy(0.40).offset(-32)  // 40% minus margins
        }

        // Divider (vertical)
        dividerView.snp.makeConstraints { make in
            make.top.equalTo(scrollView.snp.top)
            make.left.equalTo(scrollView.snp.right).offset(12)
            make.bottom.equalTo(scrollView.snp.bottom)
            make.width.equalTo(1)
        }

        // Preview container (right side, 60%)
        previewContainerView.snp.makeConstraints { make in
            make.top.equalTo(scrollView.snp.top)
            make.left.equalTo(dividerView.snp.right).offset(12)
            make.right.equalToSuperview().offset(-16)
            make.bottom.equalTo(scrollView.snp.bottom)
        }

        // Empty state view (overlays table view only)
        emptyStateView.snp.makeConstraints { make in
            make.top.equalTo(scrollView.snp.top)
            make.left.equalTo(scrollView.snp.left)
            make.right.equalTo(scrollView.snp.right)
            make.bottom.equalTo(scrollView.snp.bottom)
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
            }
            .store(in: &cancellables)
    }

    // MARK: - Public Methods

    func showPanel() {
        mainPanelViewModel.handle(.loadEntries)

        // Restore saved window frame if available
        restoreWindowFrame()

        // CRITICAL: Temporarily switch to .regular activation policy to receive keyboard events
        // This is REQUIRED for NSPanel to receive keyboard events (Alfred, Maccy do this)
        NSApp.setActivationPolicy(.regular)

        // Force activate this application BEFORE showing the window
        // Using both methods for maximum compatibility
        NSApp.activate(ignoringOtherApps: true)

        // Small delay to ensure activation takes effect
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) { [weak self] in
            guard let self = self else { return }

            // Now make the window key and front
            self.makeKeyAndOrderFront(nil)

            // Use a loop to ensure window becomes key (standard approach from research)
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
                    // Focus search bar after window is key
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
        // Save window frame before closing
        saveWindowFrame()

        orderOut(nil)

        // Restore .accessory activation policy after hiding panel
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            NSApp.setActivationPolicy(.accessory)
            Logger.info("Activation policy restored to .accessory")
        }

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
        if event.type == .keyDown {
            let keyCode = event.keyCode

            // Handle navigation keys even when TextField is focused
            switch keyCode {
            case 53: // Escape
                hidePanel()
                return
            case 125: // Down arrow
                selectNextRow()
                return
            case 126: // Up arrow
                selectPreviousRow()
                return
            case 36: // Enter
                copyAndPasteSelected()
                return
            default:
                break
            }
        }

        super.sendEvent(event)
    }

    override func keyDown(with event: NSEvent) {
        let keyCode = event.keyCode
        NSLog("⌨️ Window keyDown: keyCode \(keyCode)")

        switch keyCode {
        case 53: // Escape - close panel
            NSLog("⎋ Escape - hiding panel")
            hidePanel()
            return

        case 125: // Down arrow
            NSLog("⬇️ Down arrow - selecting next row")
            selectNextRow()
            return

        case 126: // Up arrow
            NSLog("⬆️ Up arrow - selecting previous row")
            selectPreviousRow()
            return

        case 36: // Enter - copy and paste
            NSLog("⏎ Enter - copy and paste")
            copyAndPasteSelected()
            return

        case 51, 117: // Delete, Forward Delete
            NSLog("🗑️ Delete - deleting selected")
            deleteSelected()
            return

        default:
            // Pass through to search bar for typing
            super.keyDown(with: event)
        }
    }

    // MARK: - Keyboard Actions

    private func selectNextRow() {
        let rowCount = tableView.numberOfRows
        guard rowCount > 0 else { return }

        let currentRow = tableView.selectedRow
        let nextRow: Int

        if currentRow < 0 {
            nextRow = 0
        } else {
            nextRow = min(currentRow + 1, rowCount - 1)
        }

        tableView.selectRowIndexes(IndexSet(integer: nextRow), byExtendingSelection: false)
        tableView.scrollRowToVisible(nextRow)

        // Update selection in view model
        if nextRow < mainPanelViewModel.filteredEntries.count {
            let entry = mainPanelViewModel.filteredEntries[nextRow]
            mainPanelViewModel.handle(.selectEntry(id: entry.id))
        }

        NSLog("✅ Selected row: \(nextRow)")
    }

    private func selectPreviousRow() {
        let rowCount = tableView.numberOfRows
        guard rowCount > 0 else { return }

        let currentRow = tableView.selectedRow
        let previousRow: Int

        if currentRow <= 0 {
            previousRow = rowCount - 1
        } else {
            previousRow = currentRow - 1
        }

        tableView.selectRowIndexes(IndexSet(integer: previousRow), byExtendingSelection: false)
        tableView.scrollRowToVisible(previousRow)

        // Update selection in view model
        if previousRow < mainPanelViewModel.filteredEntries.count {
            let entry = mainPanelViewModel.filteredEntries[previousRow]
            mainPanelViewModel.handle(.selectEntry(id: entry.id))
        }

        NSLog("✅ Selected row: \(previousRow)")
    }

    private func copyAndPasteSelected() {
        guard tableView.selectedRow >= 0,
              tableView.selectedRow < mainPanelViewModel.filteredEntries.count else {
            NSLog("⚠️ No row selected")
            return
        }

        let entry = mainPanelViewModel.filteredEntries[tableView.selectedRow]
        mainPanelViewModel.handle(.pasteEntry(id: entry.id))
        hidePanel()
        NSLog("✅ Copied and pasted: \(entry.title)")
    }

    private func deleteSelected() {
        let selectedRows = tableView.selectedRowIndexes
        guard !selectedRows.isEmpty else { return }

        let ids = selectedRows.compactMap { rowIndex -> String? in
            guard rowIndex < mainPanelViewModel.filteredEntries.count else { return nil }
            return mainPanelViewModel.filteredEntries[rowIndex].id
        }

        if ids.count == 1 {
            mainPanelViewModel.handle(.deleteEntry(id: ids[0]))
        } else {
            mainPanelViewModel.handle(.deleteEntries(ids: ids))
        }

        NSLog("✅ Deleted \(ids.count) entr\(ids.count == 1 ? "y" : "ies")")
    }

    // MARK: - Window Persistence

    private func saveWindowFrame() {
        let frame = frame
        UserDefaults.standard.set(NSStringFromRect(frame), forKey: windowFrameKey)
        Logger.debug("Saved window frame: \(frame)")
    }

    private func restoreWindowFrame() {
        guard let frameString = UserDefaults.standard.string(forKey: windowFrameKey) else {
            Logger.debug("No saved window frame found")
            return
        }

        let frame = NSRectFromString(frameString)
        self.setFrame(frame, display: true)
        Logger.debug("Restored window frame: \(frame)")
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
        }

        return cellView
    }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        return 64
    }

    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        guard row < mainPanelViewModel.filteredEntries.count else {
            return false
        }

        let entry = mainPanelViewModel.filteredEntries[row]
        mainPanelViewModel.handle(.selectEntry(id: entry.id))

        return true
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
