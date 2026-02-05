import Cocoa
import SnapKit

class ClipboardTableCellView: NSTableCellView {
    var entryId: String?
    weak var viewModel: MainPanelViewModel?
    var isPinned: Bool = false
    var isSensitive: Bool = false

    private var _isSelected: Bool = false

    var isSelected: Bool {
        get { return _isSelected }
        set {
            _isSelected = newValue
            updateSelectionState()
        }
    }

    private let typeIconImageView: NSImageView = {
        let imageView = NSImageView()
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        return imageView
    }()

    private let titleLabel: NSTextField = {
        let textField = NSTextField(labelWithString: "")
        textField.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        textField.textColor = NSColor.DesignColors.text0
        textField.lineBreakMode = .byTruncatingTail
        textField.maximumNumberOfLines = 1
        textField.isEditable = false
        textField.isSelectable = false
        textField.setContentHuggingPriority(.defaultLow, for: .horizontal)
        textField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        if let cell = textField.cell as? NSTextFieldCell {
            cell.wraps = false
            cell.truncatesLastVisibleLine = true
        }
        return textField
    }()

    private let appIconImageView: NSImageView = {
        let imageView = NSImageView()
        imageView.wantsLayer = true
        imageView.layer?.cornerRadius = 3
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        return imageView
    }()

    private let metaLabel: NSTextField = {
        let textField = NSTextField(labelWithString: "")
        textField.font = NSFont.systemFont(ofSize: 11)
        textField.textColor = NSColor.DesignColors.text1
        textField.isEditable = false
        textField.isSelectable = false
        textField.setContentHuggingPriority(.defaultLow, for: .horizontal)
        return textField
    }()

    private let sensitiveIconView: NSImageView = {
        let imageView = NSImageView()
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.contentTintColor = NSColor.DesignColors.pin
        imageView.isHidden = true
        if let icon = NSImage(systemSymbolName: "exclamationmark.triangle.fill", accessibilityDescription: "Sensitive Content") {
            imageView.image = icon
        }
        return imageView
    }()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }

    private func setupUI() {
        wantsLayer = true
        layer?.cornerRadius = 10
        layer?.masksToBounds = true
        layer?.backgroundColor = NSColor.DesignColors.mat2.cgColor
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.DesignColors.stroke.cgColor

        addSubview(typeIconImageView)
        addSubview(titleLabel)
        addSubview(appIconImageView)
        addSubview(metaLabel)
        addSubview(sensitiveIconView)

        setupLayout()
    }

    private func setupLayout() {
        typeIconImageView.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(12)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(20)
        }

        titleLabel.snp.makeConstraints { make in
            make.left.equalTo(typeIconImageView.snp.right).offset(12)
            make.top.equalToSuperview().offset(14)
            make.right.equalToSuperview().offset(-12)
            make.height.equalTo(17)
        }

        appIconImageView.snp.makeConstraints { make in
            make.left.equalTo(typeIconImageView.snp.right).offset(12)
            make.top.equalTo(titleLabel.snp.bottom).offset(8)
            make.width.height.equalTo(14)
        }

        metaLabel.snp.makeConstraints { make in
            make.left.equalTo(appIconImageView.snp.right).offset(6)
            make.centerY.equalTo(appIconImageView.snp.centerY)
            make.right.lessThanOrEqualToSuperview().offset(-12)
        }

        sensitiveIconView.snp.makeConstraints { make in
            make.right.equalToSuperview().offset(-12)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(14)
        }
    }

    func configure(with entry: ClipboardEntryListItem) {
        self.entryId = entry.id
        self.isPinned = entry.isPinned
        self.isSensitive = entry.isSensitive

        if entry.contentType == .image {
            if let imageIcon = NSImage(systemSymbolName: "photo", accessibilityDescription: "Image") {
                typeIconImageView.image = imageIcon
                typeIconImageView.contentTintColor = NSColor.DesignColors.icon
            }
        } else {
            if let textIcon = NSImage(systemSymbolName: "text.alignleft", accessibilityDescription: "Text") {
                typeIconImageView.image = textIcon
                typeIconImageView.contentTintColor = NSColor.DesignColors.icon
            }
        }

        titleLabel.stringValue = entry.title

        if let appIcon = entry.sourceIcon {
            appIconImageView.image = appIcon
            appIconImageView.isHidden = false
        } else {
            appIconImageView.isHidden = true
        }

        var metaText = entry.sourceApp
        metaText += " · "
        metaText += entry.timestamp
        if isPinned {
            metaText += " 📌"
        }
        metaLabel.stringValue = metaText

        updateSelectionState()
    }

    private func updateSelectionState() {
        if isSelected {
            layer?.backgroundColor = NSColor.DesignColors.selected.cgColor
            layer?.borderColor = NSColor.DesignColors.accent.cgColor
            layer?.borderWidth = 1
        } else {
            layer?.backgroundColor = NSColor.DesignColors.mat2.cgColor
            layer?.borderColor = NSColor.DesignColors.stroke.cgColor
            layer?.borderWidth = 1
        }

        sensitiveIconView.isHidden = !isSensitive
    }

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

    override func updateLayer() {
        super.updateLayer()
        wantsLayer = true
        layer?.masksToBounds = true
    }
}

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
