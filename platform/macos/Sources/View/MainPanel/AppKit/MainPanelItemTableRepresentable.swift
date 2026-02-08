import SwiftUI

struct MainPanelItemTableRepresentable: NSViewRepresentable {
    let items: [ClipboardItemRow]
    let selectedId: String?
    let onSelect: (ClipboardItemRow) -> Void

    func makeNSView(context: Context) -> MainPanelItemTableView {
        let view = MainPanelItemTableView(frame: .zero)
        view.onSelect = { item in
            context.coordinator.onSelect(item)
        }
        return view
    }

    func updateNSView(_ nsView: MainPanelItemTableView, context: Context) {
        context.coordinator.onSelect = onSelect
        nsView.onSelect = { item in
            context.coordinator.onSelect(item)
        }
        nsView.update(items: items, selectedId: selectedId)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onSelect: onSelect)
    }

    final class Coordinator {
        var onSelect: (ClipboardItemRow) -> Void

        init(onSelect: @escaping (ClipboardItemRow) -> Void) {
            self.onSelect = onSelect
        }
    }
}
