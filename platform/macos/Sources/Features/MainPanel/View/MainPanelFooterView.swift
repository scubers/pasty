import SwiftUI

struct MainPanelFooterView: View {
    let totalItemCount: Int

    var body: some View {
        HStack(spacing: MainPanelTokens.Layout.paddingCompact) {
            Text("↑↓ select ·")
            Text("⌘+D delete ·")
            Text("⌘+↩ copy ·")
            Text("↩ paste ·")
            Text("Esc close")
            Spacer()
            Text("Total \(totalItemCount)")
        }
        .font(MainPanelTokens.Typography.small)
        .foregroundStyle(MainPanelTokens.Colors.textMuted)
        .padding(.horizontal, MainPanelTokens.Layout.padding)
        .padding(.vertical, 8)
        .background(MainPanelTokens.Colors.card)
    }
}
