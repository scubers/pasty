import AppKit
import SnapKit

final class MainPanelItemTableCellView: NSTableCellView {
    private let markerView = NSView()
    private let iconView = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let appIconView = NSImageView()
    private let subtitleLabel = NSTextField(labelWithString: "")

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
            let fallback = "Image[\(item.imageWidth ?? 0) x \(item.imageHeight ?? 0)]"
            if let ocrText = item.ocrText?.trimmingCharacters(in: .whitespacesAndNewlines), !ocrText.isEmpty {
                titleLabel.stringValue = "[OCR] \(String(ocrText.prefix(50)))"
            } else {
                titleLabel.stringValue = fallback
            }
        } else {
            titleLabel.stringValue = item.content
                .replacingOccurrences(of: "\r\n", with: " ")
                .replacingOccurrences(of: "\n", with: " ")
                .replacingOccurrences(of: "\r", with: " ")
        }

        let appInfo = AppInfoProvider.shared.info(for: item.sourceAppId)
        let timestamp = item.timestamp.formatted(date: .omitted, time: .shortened)

        appIconView.image = appInfo.icon
        appIconView.isHidden = (appInfo.icon == nil)
        subtitleLabel.stringValue = "\(appInfo.name) • \(timestamp)"

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

        appIconView.imageScaling = .scaleProportionallyUpOrDown
        appIconView.isHidden = true

        addSubview(markerView)
        addSubview(iconView)
        addSubview(titleLabel)
        addSubview(appIconView)
        addSubview(subtitleLabel)

        markerView.snp.makeConstraints { make in
            make.leading.top.bottom.equalToSuperview()
            make.width.equalTo(3)
        }

        iconView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(8)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(18)
        }

        titleLabel.snp.makeConstraints { make in
            make.leading.equalTo(iconView.snp.trailing).offset(8)
            make.trailing.equalToSuperview().inset(8)
            make.height.equalTo(18)
            make.bottom.equalTo(self.snp.centerY)
        }

        appIconView.snp.makeConstraints { make in
            make.leading.equalTo(iconView.snp.trailing).offset(8)
            make.centerY.equalTo(subtitleLabel.snp.centerY)
            make.width.height.equalTo(12)
        }

        subtitleLabel.snp.makeConstraints { make in
            make.leading.equalTo(appIconView.snp.trailing).offset(4)
            make.trailing.equalToSuperview().inset(8)
            make.top.equalTo(self.snp.centerY).offset(4)
            make.height.equalTo(14)
        }
    }
}
