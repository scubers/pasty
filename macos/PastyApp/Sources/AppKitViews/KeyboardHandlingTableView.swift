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

}

// MARK: - Keyboard Table View Delegate

protocol KeyboardTableViewDelegate: AnyObject {
    func tableViewDidChangeSelection(_ tableView: NSTableView, selectedRow: Int)
    func tableViewDidPressEnter(_ tableView: NSTableView)
    func tableViewDidPressEscape(_ tableView: NSTableView)
    func tableViewDidPressDelete(_ tableView: NSTableView)
}
