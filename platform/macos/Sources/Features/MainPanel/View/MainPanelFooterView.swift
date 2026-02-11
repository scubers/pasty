import SwiftUI

struct MainPanelFooterView: View {
    var body: some View {
        HStack(spacing: MainPanelTokens.Layout.paddingCompact) {
            Text("Cmd+Shift+V to toggle panel")
            Spacer()
            Text("Enter to paste")
            Text("Esc to close")
        }
        .font(MainPanelTokens.Typography.small)
        .foregroundStyle(MainPanelTokens.Colors.textMuted)
        .padding(.horizontal, MainPanelTokens.Layout.padding)
        .padding(.vertical, 8)
        .background(MainPanelTokens.Colors.card)
    }
}
