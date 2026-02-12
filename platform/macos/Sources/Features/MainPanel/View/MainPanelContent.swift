import SwiftUI

struct MainPanelContent: View {
    @EnvironmentObject var appCoordinator: AppCoordinator
    let items: [ClipboardItemRow]
    let selectedItem: ClipboardItemRow?
    let onSelect: (ClipboardItemRow) -> Void

    var body: some View {
        GeometryReader { proxy in
            let leftWidth = max(250, proxy.size.width * MainPanelTokens.Layout.splitRatio)
            HStack(spacing: MainPanelTokens.Layout.paddingCompact) {
                MainPanelItemTableRepresentable(
                    items: items,
                    selectedId: selectedItem?.id,
                    appCoordinator: appCoordinator,
                    onSelect: onSelect
                )
                .frame(width: leftWidth)

                MainPanelPreviewPanel(item: selectedItem)
                    .frame(maxWidth: .infinity)
            }
            .padding(.trailing, MainPanelTokens.Layout.padding)
            .padding(.vertical, MainPanelTokens.Layout.paddingCompact)
        }
    }
}
