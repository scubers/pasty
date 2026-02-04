import Cocoa

/// Custom NSTableView that handles keyboard navigation
class KeyboardHandlingTableView: NSTableView {
    // MARK: - Properties

    /// ViewModel for handling keyboard actions
    weak var keyboardDelegate: KeyboardTableViewDelegate?

    // MARK: - Initialization

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupKeyMonitoring()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupKeyMonitoring()
    }

    // MARK: - Setup

    private func setupKeyMonitoring() {
        // Keyboard events will be handled via keyDown override
    }

    // MARK: - Keyboard Events

    override var acceptsFirstResponder: Bool {
        return true
    }

    override var canBecomeKeyView: Bool {
        return true
    }

    override func becomeFirstResponder() -> Bool {
        let result = super.becomeFirstResponder()
        NSLog("🎯 TableView became first responder: \(result)")
        return result
    }

    override func keyDown(with event: NSEvent) {
        NSLog("⌨️ keyDown: keyCode \(event.keyCode), characters \(event.characters ?? "none")")

        // Handle special keys
        switch event.keyCode {
        case 125: // Down arrow
            handleDownArrow()
            return
        case 126: // Up arrow
            handleUpArrow()
            return
        case 36: // Return/Enter key
            handleEnterKey()
            return
        case 51: // Delete key
            handleDeleteKey()
            return
        case 117: // Forward Delete key
            handleDeleteKey()
            return
        case 53: // Escape key
            handleEscapeKey()
            return
        default:
            // Pass other keys to super
            super.keyDown(with: event)
        }
    }

    // MARK: - Keyboard Handlers

    private func handleDownArrow() {
        NSLog("⬇️ Down arrow pressed")
        guard let ds = dataSource else { return }
        let rowCount = ds.numberOfRows?(in: self) ?? 0
        guard rowCount > 0 else { return }

        let currentRow = selectedRow
        let nextRow: Int

        if currentRow < 0 {
            nextRow = 0
        } else {
            nextRow = min(currentRow + 1, rowCount - 1)
        }

        selectRowIndexes(IndexSet(integer: nextRow), byExtendingSelection: false)
        scrollRowToVisible(nextRow)
        notifySelectionChanged(row: nextRow)
        NSLog("✅ Selected row: \(nextRow)")
    }

    private func handleUpArrow() {
        NSLog("⬆️ Up arrow pressed")
        guard let ds = dataSource else { return }
        let rowCount = ds.numberOfRows?(in: self) ?? 0
        guard rowCount > 0 else { return }

        let currentRow = selectedRow
        let previousRow: Int

        if currentRow <= 0 {
            previousRow = rowCount - 1
        } else {
            previousRow = currentRow - 1
        }

        selectRowIndexes(IndexSet(integer: previousRow), byExtendingSelection: false)
        scrollRowToVisible(previousRow)
        notifySelectionChanged(row: previousRow)
        NSLog("✅ Selected row: \(previousRow)")
    }

    private func handleEnterKey() {
        NSLog("⏎ Enter pressed, selectedRow: \(selectedRow)")
        guard selectedRow >= 0,
              let delegate = keyboardDelegate else { return }

        delegate.tableViewDidPressEnter(self)
    }

    private func handleEscapeKey() {
        NSLog("⎋ Escape pressed")
        guard let delegate = keyboardDelegate else { return }

        delegate.tableViewDidPressEscape(self)
    }

    private func handleDeleteKey() {
        NSLog("🗑️ Delete pressed")
        guard let delegate = keyboardDelegate else { return }

        delegate.tableViewDidPressDelete(self)
    }

    private func notifySelectionChanged(row: Int) {
        guard let delegate = keyboardDelegate else { return }

        delegate.tableViewDidChangeSelection(self, selectedRow: row)
    }
}

// MARK: - Keyboard Table View Delegate

protocol KeyboardTableViewDelegate: AnyObject {
    func tableViewDidChangeSelection(_ tableView: NSTableView, selectedRow: Int)
    func tableViewDidPressEnter(_ tableView: NSTableView)
    func tableViewDidPressEscape(_ tableView: NSTableView)
    func tableViewDidPressDelete(_ tableView: NSTableView)
}
