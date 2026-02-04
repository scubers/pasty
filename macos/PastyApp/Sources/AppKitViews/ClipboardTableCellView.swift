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
        textField.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        textField.textColor = NSColor(hex: "#ffffff")
        textField.lineBreakMode = .byTruncatingTail
        textField.isEditable = false
        textField.isSelectable = false
        textField.setContentHuggingPriority(.defaultLow, for: .horizontal)
        return textField
    }()

    private let subtitleLabel: NSTextField = {
        let textField = NSTextField(labelWithString: "")
        textField.font = NSFont.systemFont(ofSize: 11, weight: .regular)
        textField.textColor = NSColor(hex: "#999999")
        textField.lineBreakMode = .byTruncatingTail
        textField.isEditable = false
        textField.isSelectable = false
        return textField
    }()

    private let timestampLabel: NSTextField = {
        let textField = NSTextField(labelWithString: "")
        textField.font = NSFont.systemFont(ofSize: 10, weight: .regular)
        textField.textColor = NSColor(hex: "#666666")
        textField.isEditable = false
        textField.isSelectable = false
        return textField
    }()

    private let typeIndicatorView: TypeIndicatorView = {
        let view = TypeIndicatorView()
        return view
    }()

    private let pinnedIndicatorView: PinnedIndicatorView = {
        let view = PinnedIndicatorView()
        view.isHidden = true
        return view
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
        layer?.cornerRadius = 8
        layer?.backgroundColor = NSColor(hex: "#252525").withAlphaComponent(0.5).cgColor

        // Add subviews
        addSubview(iconImageView)
        addSubview(titleLabel)
        addSubview(subtitleLabel)
        addSubview(timestampLabel)
        addSubview(typeIndicatorView)
        addSubview(pinnedIndicatorView)

        setupLayout()
    }

    private func setupLayout() {
        iconImageView.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(12)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(32)
        }

        titleLabel.snp.makeConstraints { make in
            make.left.equalTo(iconImageView.snp.right).offset(12)
            make.top.equalToSuperview().offset(10)
            make.right.lessThanOrEqualTo(typeIndicatorView.snp.left).offset(-8)
        }

        subtitleLabel.snp.makeConstraints { make in
            make.left.equalTo(iconImageView.snp.right).offset(12)
            make.top.equalTo(titleLabel.snp.bottom).offset(2)
            make.right.lessThanOrEqualTo(typeIndicatorView.snp.left).offset(-8)
        }

        timestampLabel.snp.makeConstraints { make in
            make.left.equalTo(iconImageView.snp.right).offset(12)
            make.bottom.equalToSuperview().offset(-10)
        }

        typeIndicatorView.snp.makeConstraints { make in
            make.right.equalTo(pinnedIndicatorView.snp.left).offset(-6)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(20)
        }

        pinnedIndicatorView.snp.makeConstraints { make in
            make.right.equalToSuperview().offset(-12)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(16)
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
            // Default app icon
            if let defaultIcon = NSImage(systemSymbolName: "app.dashed", accessibilityDescription: "Application") {
                iconImageView.image = defaultIcon
                iconImageView.contentTintColor = NSColor(hex: "#666666")
            }
            iconImageView.isHidden = false
        }

        // Configure title
        titleLabel.stringValue = entry.title

        // Configure subtitle (source app + content type)
        let contentTypeStr = entry.contentType == .text ? "Text" : "Image"
        subtitleLabel.stringValue = "\(entry.sourceApp) • \(contentTypeStr)"

        // Configure timestamp
        timestampLabel.stringValue = entry.timestamp

        // Configure type indicator
        typeIndicatorView.setContentType(entry.contentType)

        // Configure pinned indicator
        pinnedIndicatorView.isHidden = !entry.isPinned

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
            layer?.backgroundColor = NSColor(hex: "#3a3a3a").cgColor
        } else if isPinned {
            layer?.backgroundColor = NSColor(hex: "#2a2a20").withAlphaComponent(0.8).cgColor
            layer?.borderColor = NSColor(hex: "#ff9500").cgColor
            layer?.borderWidth = 1
        } else {
            layer?.backgroundColor = NSColor(hex: "#252525").withAlphaComponent(0.5).cgColor
            layer?.borderWidth = 0
        }
    }
}

// MARK: - Type Indicator View

class TypeIndicatorView: NSView {
    private var contentType: ContentType = .text

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard let context = NSGraphicsContext.current?.cgContext else { return }

        let rect = bounds
        let color: NSColor

        switch contentType {
        case .text:
            color = NSColor(hex: "#5856d6")  // Purple
        case .image:
            color = NSColor(hex: "#34c759")  // Green
        }

        context.setFillColor(color.cgColor)
        context.fillEllipse(in: rect.insetBy(dx: 2, dy: 2))
    }

    func setContentType(_ type: ContentType) {
        self.contentType = type
        needsDisplay = true
    }
}

// MARK: - Pinned Indicator View

class PinnedIndicatorView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard let context = NSGraphicsContext.current?.cgContext else { return }

        let rect = bounds

        context.setFillColor(NSColor(hex: "#ff9500").cgColor)  // Orange

        // Pin head (square with checkmark, matching design)
        let headRect = NSRect(
            x: rect.minX + 2,
            y: rect.minY + 2,
            width: rect.width - 4,
            height: rect.height - 4
        )

        // Draw rounded rectangle
        let path = NSBezierPath(roundedRect: headRect, xRadius: 2, yRadius: 2)
        path.fill()

        // Draw checkmark
        context.setStrokeColor(NSColor.white.cgColor)
        context.setLineWidth(1.5)
        let checkPath = NSBezierPath()
        checkPath.move(to: NSPoint(x: headRect.minX + 3, y: headRect.midY))
        checkPath.line(to: NSPoint(x: headRect.midX - 1, y: headRect.maxY - 3))
        checkPath.line(to: NSPoint(x: headRect.maxX - 3, y: headRect.minY + 3))
        checkPath.stroke()
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
