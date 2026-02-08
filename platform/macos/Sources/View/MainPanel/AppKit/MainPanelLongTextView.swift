import AppKit
import SnapKit

final class MainPanelLongTextView: NSView {
    private let scrollView = NSScrollView()
    private let textView = NSTextView()
    private var currentText: String = ""
    private var currentItemId: String?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(itemId: String?, text: String) {
        guard currentItemId != itemId || currentText != text else {
            return
        }

        currentItemId = itemId
        currentText = text
        textView.textStorage?.setAttributedString(makeHighlightedText(text))
    }

    private func setupView() {
        textView.isEditable = false
        textView.isSelectable = true
        textView.isRichText = false
        textView.importsGraphics = false
        textView.usesFindBar = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticDataDetectionEnabled = false
        textView.isAutomaticLinkDetectionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.drawsBackground = false
        textView.textColor = NSColor(calibratedWhite: 0.92, alpha: 1)

        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.documentView = textView

        addSubview(scrollView)
        scrollView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    private func makeHighlightedText(_ text: String) -> NSAttributedString {
        let baseColor = NSColor(calibratedWhite: 0.92, alpha: 1)
        let attributed = NSMutableAttributedString(
            string: text,
            attributes: [
                .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .regular),
                .foregroundColor: baseColor,
            ]
        )

        let keywordColor = NSColor(calibratedRed: 192.0 / 255.0, green: 132.0 / 255.0, blue: 252.0 / 255.0, alpha: 1)
        let stringColor = NSColor(calibratedRed: 74.0 / 255.0, green: 222.0 / 255.0, blue: 128.0 / 255.0, alpha: 1)
        let functionColor = NSColor(calibratedRed: 253.0 / 255.0, green: 224.0 / 255.0, blue: 71.0 / 255.0, alpha: 1)

        applyPattern("\"[^\"]*\"|'[^']*'", color: stringColor, in: attributed)
        applyPattern("\\b(function|func|class|struct|enum|let|var|if|else|for|while|return|import|final|private|public)\\b", color: keywordColor, in: attributed)
        applyPattern("\\b([A-Za-z_][A-Za-z0-9_]*)\\s*(?=\\()", color: functionColor, in: attributed)
        return attributed
    }

    private func applyPattern(_ pattern: String, color: NSColor, in text: NSMutableAttributedString) {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return
        }
        let range = NSRange(location: 0, length: text.length)
        let matches = regex.matches(in: text.string, options: [], range: range)
        for match in matches {
            text.addAttribute(.foregroundColor, value: color, range: match.range)
        }
    }
}
