import SwiftUI

struct MainPanelSearchBar: View {
    @Binding var text: String
    @Binding var focusRequest: Bool
    @Binding var filterType: ClipboardItemRow.ItemType?
    @EnvironmentObject var appCoordinator: AppCoordinator
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

            // Filter buttons
            HStack(spacing: 8) {
                FilterPillButton(
                    title: "All",
                    isSelected: filterType == nil,
                    action: { filterType = nil }
                )

                FilterPillButton(
                    title: "Text",
                    isSelected: filterType == .text,
                    action: { filterType = .text }
                )

                FilterPillButton(
                    title: "Image",
                    isSelected: filterType == .image,
                    action: { filterType = .image }
                )
            }
        }
        .padding(.horizontal, MainPanelTokens.Layout.padding)
        .padding(.vertical, 12)
        .background(focused ? Color.black.opacity(0.40) : Color.black.opacity(0.30))
        .overlay {
            RoundedRectangle(cornerRadius: MainPanelTokens.Layout.cornerRadius)
                .stroke(
                    focused ? MainPanelTokens.Colors.accentPrimary(theme: appCoordinator.settings.appearance.themeColor) : Color.white.opacity(0.10),
                    lineWidth: 1
                )
        }
        .clipShape(RoundedRectangle(cornerRadius: MainPanelTokens.Layout.cornerRadius))
        .shadow(
            color: focused ? MainPanelTokens.Colors.accentPrimary(theme: appCoordinator.settings.appearance.themeColor).opacity(0.20) : .clear,
            radius: focused ? 6 : 0,
            x: 0,
            y: 0
        )
        .padding(MainPanelTokens.Layout.padding)
        .onChange(of: focusRequest) { _, _ in
            focused = true
        }
        .onAppear {
            focused = true
        }
    }
}

private struct FilterPillButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    @EnvironmentObject var appCoordinator: AppCoordinator
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(MainPanelTokens.Typography.body)
                .foregroundStyle(isSelected ? Color.white : (isHovering ? MainPanelTokens.Colors.textPrimary : MainPanelTokens.Colors.textSecondary))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background {
                    Capsule()
                        .fill(
                            isSelected
                                ? MainPanelTokens.Colors.accentPrimary(theme: appCoordinator.settings.appearance.themeColor)
                                : (isHovering ? Color.white.opacity(0.1) : Color.clear)
                        )
                }
                .overlay {
                    if !isSelected {
                        Capsule()
                            .strokeBorder(MainPanelTokens.Colors.border, lineWidth: 1)
                    }
                }
        }
        .buttonStyle(.plain)
        .onHover { hover in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hover
            }
        }
    }
}
