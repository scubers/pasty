import SwiftUI

struct MainPanelLongTextRepresentable: NSViewRepresentable {
    let itemId: String?
    let text: String

    func makeNSView(context: Context) -> MainPanelLongTextView {
        MainPanelLongTextView(frame: .zero)
    }

    func updateNSView(_ nsView: MainPanelLongTextView, context: Context) {
        nsView.update(itemId: itemId, text: text)
    }
}
