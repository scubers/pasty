import AppKit
import SnapKit

private final class MainPanelTableView: NSTableView {

    // Keep keyboard focus on the search field while still allowing row selection.
    override var acceptsFirstResponder: Bool {
        false
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

}

final class MainPanelItemTableView: NSView, NSTableViewDataSource, NSTableViewDelegate {
    var items: [ClipboardItemRow] = []
    var selectedId: String?
    var onSelect: ((ClipboardItemRow) -> Void)?

    private let scrollView = NSScrollView()
    private let tableView = MainPanelTableView()
    private let column = NSTableColumn(identifier: .init("main-panel-item"))
    private var hoveredRow: Int = -1
    private var previouslySelectedRow: Int = -1
    private var isSyncingSelection = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    func update(items: [ClipboardItemRow], selectedId: String?) {
        let previous = self.items
        self.items = items
        self.selectedId = selectedId

        if previous.count == items.count {
            let previousIDs = previous.map(\.id)
            let currentIDs = items.map(\.id)
            if previousIDs == currentIDs {
                let changedRows = IndexSet(
                    items.indices.filter { idx in
                        previous[idx] != items[idx]
                    }
                )
                if changedRows.isEmpty {
                    // no-op
                } else {
                    tableView.reloadData(forRowIndexes: changedRows, columnIndexes: IndexSet(integer: 0))
                }
            } else {
                tableView.reloadData()
            }
        } else {
            tableView.reloadData()
        }

        selectCurrentRowIfNeeded()
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        items.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row >= 0, row < items.count else {
            return nil
        }
        let item = items[row]
        let identifier = NSUserInterfaceItemIdentifier("main-panel-item-cell")
        let cell: MainPanelItemTableCellView
        if let reused = tableView.makeView(withIdentifier: identifier, owner: self) as? MainPanelItemTableCellView {
            cell = reused
        } else {
            cell = MainPanelItemTableCellView(frame: .zero)
            cell.identifier = identifier
        }
        let isSelected = item.id == selectedId
        let isHovered = row == hoveredRow
        let isFocused = tableView.window?.firstResponder === tableView
        cell.configure(item: item, selected: isSelected, hovered: isHovered, focused: isFocused)
        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        let row = tableView.selectedRow
        let selectedRow = (row >= 0 && row < items.count) ? row : -1
        selectedId = selectedRow >= 0 ? items[selectedRow].id : nil

        if selectedRow >= 0 {
            let selectedItem = items[selectedRow]
            if isSyncingSelection {
                DispatchQueue.main.async { [weak self] in
                    self?.onSelect?(selectedItem)
                }
            } else {
                onSelect?(selectedItem)
            }
        }

        // Reload both previously selected row and newly selected row to update their visual states
        if previouslySelectedRow != selectedRow {
            let rowsToReload = IndexSet([previouslySelectedRow, selectedRow].compactMap { $0 >= 0 ? $0 : nil })
            if !rowsToReload.isEmpty {
                tableView.reloadData(forRowIndexes: rowsToReload, columnIndexes: IndexSet(integer: 0))
            }
            previouslySelectedRow = selectedRow
        }
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for trackingArea in trackingAreas {
            removeTrackingArea(trackingArea)
        }

        let tracking = NSTrackingArea(
            rect: bounds,
            options: [.mouseMoved, .mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(tracking)
    }

    override func mouseMoved(with event: NSEvent) {
        let point = tableView.convert(event.locationInWindow, from: nil)
        updateHoveredRow(to: tableView.row(at: point))
    }

    override func mouseExited(with event: NSEvent) {
        updateHoveredRow(to: -1)
    }

    private func setupView() {
        wantsLayer = true

        column.resizingMask = .autoresizingMask
        tableView.addTableColumn(column)
        tableView.headerView = nil
        tableView.rowHeight = 56
        tableView.selectionHighlightStyle = .none
        tableView.focusRingType = .none
        tableView.intercellSpacing = .zero
        tableView.allowsTypeSelect = true
        tableView.allowsColumnResizing = false
        tableView.allowsColumnReordering = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.backgroundColor = .clear

        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.scrollerStyle = .overlay
        scrollView.documentView = tableView

        addSubview(scrollView)
        scrollView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    private func updateHoveredRow(to newRow: Int) {
        let previousHoveredRow = hoveredRow
        hoveredRow = newRow
        if hoveredRow != previousHoveredRow {
            let rowsToReload = IndexSet([previousHoveredRow, hoveredRow].compactMap { $0 >= 0 ? $0 : nil })
            if !rowsToReload.isEmpty {
                tableView.reloadData(forRowIndexes: rowsToReload, columnIndexes: IndexSet(integer: 0))
            }
        }
    }

    private func selectCurrentRowIfNeeded() {
        isSyncingSelection = true
        defer { isSyncingSelection = false }

        guard let selectedId,
              let row = items.firstIndex(where: { $0.id == selectedId })
        else {
            tableView.deselectAll(nil)
            return
        }

        tableView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
        tableView.scrollRowToVisible(row)
        tableView.reloadData(forRowIndexes: IndexSet(integer: row), columnIndexes: IndexSet(integer: 0))
    }
}
