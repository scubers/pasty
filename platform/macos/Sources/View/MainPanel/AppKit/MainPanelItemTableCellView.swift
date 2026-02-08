import AppKit
import SnapKit

final class MainPanelItemTableCellView: NSTableCellView {
    private let markerView = NSView()
    private let iconView = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let subtitleLabel = NSTextField(labelWithString: "")
    private let stackView = NSStackView()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(item: ClipboardItemRow, selected: Bool, hovered: Bool, focused: Bool) {
        iconView.image = NSImage(systemSymbolName: item.type == .image ? "photo" : "text.alignleft", accessibilityDescription: nil)
        if item.type == .image {
            titleLabel.stringValue = "Image[\(item.imageWidth ?? 0) x \(item.imageHeight ?? 0)]"
        } else {
            titleLabel.stringValue = item.content
                .replacingOccurrences(of: "\r\n", with: " ")
                .replacingOccurrences(of: "\n", with: " ")
                .replacingOccurrences(of: "\r", with: " ")
        }
        subtitleLabel.stringValue = "\(item.sourceAppId) • \(item.timestamp.formatted(date: .omitted, time: .shortened))"

        if selected {
            layer?.backgroundColor = NSColor(calibratedRed: 45.0 / 255.0, green: 212.0 / 255.0, blue: 191.0 / 255.0, alpha: 0.12).cgColor
            markerView.isHidden = false
        } else if hovered {
            layer?.backgroundColor = NSColor.white.withAlphaComponent(0.06).cgColor
            markerView.isHidden = true
        } else {
            layer?.backgroundColor = NSColor.clear.cgColor
            markerView.isHidden = true
        }

        if focused && selected {
            layer?.borderWidth = 1
            layer?.borderColor = NSColor(calibratedRed: 45.0 / 255.0, green: 212.0 / 255.0, blue: 191.0 / 255.0, alpha: 0.8).cgColor
        } else {
            layer?.borderWidth = 0
            layer?.borderColor = nil
        }
    }

    private func setupViews() {
        wantsLayer = true
        layer?.cornerRadius = 8

        markerView.wantsLayer = true
        markerView.layer?.backgroundColor = NSColor(calibratedRed: 45.0 / 255.0, green: 212.0 / 255.0, blue: 191.0 / 255.0, alpha: 1).cgColor
        markerView.isHidden = true

        iconView.contentTintColor = NSColor(calibratedWhite: 0.70, alpha: 1)
        iconView.imageScaling = .scaleProportionallyUpOrDown

        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.font = NSFont.systemFont(ofSize: 15, weight: .medium)
        titleLabel.textColor = NSColor(calibratedWhite: 0.92, alpha: 1)
        titleLabel.maximumNumberOfLines = 1
        titleLabel.cell?.usesSingleLineMode = true
        titleLabel.cell?.wraps = false
        titleLabel.cell?.lineBreakMode = .byTruncatingTail
        titleLabel.setContentHuggingPriority(.required, for: .vertical)
        titleLabel.setContentCompressionResistancePriority(.required, for: .vertical)

        subtitleLabel.lineBreakMode = .byTruncatingTail
        subtitleLabel.font = NSFont.systemFont(ofSize: 11, weight: .regular)
        subtitleLabel.textColor = NSColor(calibratedWhite: 0.62, alpha: 1)
        subtitleLabel.maximumNumberOfLines = 1
        subtitleLabel.cell?.usesSingleLineMode = true
        subtitleLabel.cell?.wraps = false
        subtitleLabel.setContentHuggingPriority(.required, for: .vertical)
        subtitleLabel.setContentCompressionResistancePriority(.required, for: .vertical)

        stackView.orientation = .vertical
        stackView.spacing = 4
        stackView.alignment = .leading
        stackView.distribution = .fillEqually
        stackView.addArrangedSubview(titleLabel)
        stackView.addArrangedSubview(subtitleLabel)

        addSubview(markerView)
        addSubview(iconView)
        addSubview(stackView)

        markerView.snp.makeConstraints { make in
            make.leading.top.bottom.equalToSuperview()
            make.width.equalTo(3)
        }

        iconView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(8)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(18)
        }

        stackView.snp.makeConstraints { make in
            make.leading.equalTo(iconView.snp.trailing).offset(8)
            make.trailing.equalToSuperview().inset(8)
            make.top.equalToSuperview().offset(6)
            make.bottom.equalToSuperview().inset(6)
        }
    }
}
