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
        level = .normal
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

        // Collection behavior - allow keyboard input
        collectionBehavior = [.fullScreenAuxiliary, .ignoresCycle]
    }

    // Override to allow becoming key window
    override var canBecomeKey: Bool {
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

        makeKeyAndOrderFront(nil)

        // Focus on search bar initially
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self else { return }

            // Always focus on search bar when panel opens
            if let searchBarHost = self.searchBarHost,
               let textField = self.findTextField(in: searchBarHost.view) {
                self.makeFirstResponder(textField)
                NSLog("🔍 Search bar focused")
            }
        }

        Logger.info("Clipboard panel shown")
    }

    func hidePanel() {
        // Save window frame before closing
        saveWindowFrame()

        orderOut(nil)
        Logger.info("Clipboard panel hidden")
    }

    // MARK: - Window-Level Keyboard Event Handling

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

    // Helper to find NSTextField in SwiftUI view hierarchy
    private func findTextField(in view: NSView) -> NSTextField? {
        if let textField = view as? NSTextField {
            return textField
        }
        for subview in view.subviews {
            if let found = findTextField(in: subview) {
                return found
            }
        }
        return nil
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
