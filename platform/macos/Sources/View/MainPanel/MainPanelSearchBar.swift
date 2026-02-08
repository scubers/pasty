import SwiftUI

struct MainPanelSearchBar: View {
    @Binding var text: String
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: MainPanelTokens.Layout.paddingCompact) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(MainPanelTokens.Colors.textSecondary)

            TextField("Search clipboard history...", text: $text)
                .textFieldStyle(.plain)
                .font(MainPanelTokens.Typography.body)
                .foregroundStyle(MainPanelTokens.Colors.textPrimary)
                .focused($focused)

            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(MainPanelTokens.Colors.textSecondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, MainPanelTokens.Layout.padding)
        .padding(.vertical, 12)
        .background(focused ? Color.black.opacity(0.40) : Color.black.opacity(0.30))
        .overlay {
            RoundedRectangle(cornerRadius: MainPanelTokens.Layout.cornerRadius)
                .stroke(focused ? MainPanelTokens.Colors.accentPrimary : Color.white.opacity(0.10), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: MainPanelTokens.Layout.cornerRadius))
        .shadow(
            color: focused ? MainPanelTokens.Colors.accentPrimary.opacity(0.20) : .clear,
            radius: focused ? 6 : 0,
            x: 0,
            y: 0
        )
        .padding(MainPanelTokens.Layout.padding)
    }
}
