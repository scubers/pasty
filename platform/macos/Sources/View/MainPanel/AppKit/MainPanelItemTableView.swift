import AppKit
import SnapKit

private final class MainPanelTableView: NSTableView {
    var onExplicitNavigation: ((Int) -> Void)?

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 115: // Home
            guard numberOfRows > 0 else { return }
            onExplicitNavigation?(0)
        case 119: // End
            guard numberOfRows > 0 else { return }
            onExplicitNavigation?(numberOfRows - 1)
        case 116: // Page Up
            let current = max(selectedRow, 0)
            onExplicitNavigation?(max(current - 10, 0))
        case 121: // Page Down
            guard numberOfRows > 0 else { return }
            let current = max(selectedRow, 0)
            onExplicitNavigation?(min(current + 10, numberOfRows - 1))
        default:
            super.keyDown(with: event)
        }
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

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
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
        guard row >= 0, row < items.count else {
            return
        }
        selectedId = items[row].id
        onSelect?(items[row])

        // Reload both previously selected row and newly selected row to update their visual states
        if previouslySelectedRow != row {
            let rowsToReload = IndexSet([previouslySelectedRow, row].compactMap { $0 >= 0 ? $0 : nil })
            if !rowsToReload.isEmpty {
                tableView.reloadData(forRowIndexes: rowsToReload, columnIndexes: IndexSet(integer: 0))
            }
            previouslySelectedRow = row
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
        tableView.onExplicitNavigation = { [weak self] targetRow in
            guard let self, targetRow >= 0, targetRow < self.items.count else {
                return
            }
            self.tableView.selectRowIndexes(IndexSet(integer: targetRow), byExtendingSelection: false)
            self.tableView.scrollRowToVisible(targetRow)
            self.selectedId = self.items[targetRow].id
            self.onSelect?(self.items[targetRow])
        }

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
