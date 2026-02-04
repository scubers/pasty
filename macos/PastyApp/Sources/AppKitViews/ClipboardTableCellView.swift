import Cocoa
import SnapKit

/// Table cell view for clipboard entries with dark theme matching design.jpeg
class ClipboardTableCellView: NSTableCellView {
    // MARK: - UI Components

    var entryId: String?
    weak var viewModel: MainPanelViewModel?
    var isPinned: Bool = false

    private var _isSelected: Bool = false

    var isSelected: Bool {
        get { return _isSelected }
        set {
            _isSelected = newValue
            updateSelectionState()
        }
    }

    private let iconImageView: NSImageView = {
        let imageView = NSImageView()
        imageView.wantsLayer = true
        imageView.layer?.cornerRadius = 6
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        return imageView
    }()

    private let titleLabel: NSTextField = {
        let textField = NSTextField(labelWithString: "")
        textField.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        textField.textColor = NSColor(hex: "#ffffff")
        textField.lineBreakMode = .byTruncatingTail
        textField.maximumNumberOfLines = 1
        textField.isEditable = false
        textField.isSelectable = false
        textField.setContentHuggingPriority(.defaultLow, for: .horizontal)
        return textField
    }()

    private let timestampLabel: NSTextField = {
        let textField = NSTextField(labelWithString: "")
        textField.font = NSFont.systemFont(ofSize: 12, weight: .regular)
        textField.textColor = NSColor(hex: "#888888")
        textField.alignment = .right
        textField.isEditable = false
        textField.isSelectable = false
        return textField
    }()

    private let enterIconView: NSImageView = {
        let imageView = NSImageView()
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.contentTintColor = NSColor(hex: "#888888")
        imageView.isHidden = true
        if let icon = NSImage(systemSymbolName: "return", accessibilityDescription: "Enter") {
            imageView.image = icon
        }
        return imageView
    }()

    // MARK: - Initialization

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }

    // MARK: - Setup

    private func setupUI() {
        wantsLayer = true
        layer?.cornerRadius = 10
        layer?.masksToBounds = true
        layer?.backgroundColor = NSColor(hex: "#1e1e22").cgColor

        // Add subviews
        addSubview(iconImageView)
        addSubview(titleLabel)
        addSubview(timestampLabel)
        addSubview(enterIconView)

        setupLayout()
    }

    private func setupLayout() {
        iconImageView.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(12)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(24)
        }

        titleLabel.snp.makeConstraints { make in
            make.left.equalTo(iconImageView.snp.right).offset(10)
            make.centerY.equalToSuperview()
            make.right.lessThanOrEqualTo(timestampLabel.snp.left).offset(-12)
        }

        timestampLabel.snp.makeConstraints { make in
            make.right.equalTo(enterIconView.snp.left).offset(-10)
            make.centerY.equalToSuperview()
            make.width.lessThanOrEqualTo(70)
        }

        enterIconView.snp.makeConstraints { make in
            make.right.equalToSuperview().offset(-16)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(14)
        }
    }

    // MARK: - Configuration

    func configure(with entry: ClipboardEntryListItem) {
        self.entryId = entry.id
        self.isPinned = entry.isPinned

        // Configure icon
        if let icon = entry.sourceIcon {
            iconImageView.image = icon
            iconImageView.isHidden = false
        } else {
            if let defaultIcon = NSImage(systemSymbolName: "app.dashed", accessibilityDescription: "Application") {
                iconImageView.image = defaultIcon
                iconImageView.contentTintColor = NSColor(hex: "#666666")
            }
            iconImageView.isHidden = false
        }

        // Configure title
        titleLabel.stringValue = entry.title

        // Configure timestamp
        timestampLabel.stringValue = entry.timestamp

        // Update background for selected state
        updateSelectionState()
    }

    // MARK: - Mouse Events

    override func rightMouseDown(with event: NSEvent) {
        super.rightMouseDown(with: event)

        let menu = NSMenu()

        let pinTitle = isPinned ? "Unpin Entry" : "Pin Entry"
        let pinItem = NSMenuItem(
            title: pinTitle,
            action: #selector(handlePinAction),
            keyEquivalent: ""
        )
        pinItem.target = self
        menu.addItem(pinItem)

        menu.addItem(NSMenuItem.separator())

        let deleteItem = NSMenuItem(
            title: "Delete",
            action: #selector(handleDeleteAction),
            keyEquivalent: ""
        )
        deleteItem.target = self
        menu.addItem(deleteItem)

        menu.popUp(positioning: nil, at: convert(event.locationInWindow, from: nil), in: self)
    }

    private func updateSelectionState() {
        if isSelected {
            // Selected state with orange/yellow border matching design
            layer?.backgroundColor = NSColor(hex: "#2a2520").cgColor
            layer?.borderColor = NSColor(hex: "#f59e0b").cgColor
            layer?.borderWidth = 2
            enterIconView.isHidden = false
        } else if isPinned {
            // Pinned state with subtle orange tint
            layer?.backgroundColor = NSColor(hex: "#2a2520").withAlphaComponent(0.6).cgColor
            layer?.borderColor = NSColor(hex: "#f59e0b").cgColor
            layer?.borderWidth = 1
            enterIconView.isHidden = true
        } else {
            // Normal state
            layer?.backgroundColor = NSColor(hex: "#1e1e22").cgColor
            layer?.borderWidth = 0
            enterIconView.isHidden = true
        }
    }
}

// MARK: - Context Menu Actions

extension ClipboardTableCellView {
    @objc private func handlePinAction(_ sender: NSMenuItem) {
        guard let entryId = entryId else { return }
        viewModel?.handle(.togglePin(id: entryId))
    }

    @objc private func handleDeleteAction(_ sender: NSMenuItem) {
        guard let entryId = entryId else { return }
        viewModel?.handle(.deleteEntry(id: entryId))
    }
}
