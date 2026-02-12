import SwiftUI

struct MainPanelView: View {
    @ObservedObject var viewModel: MainPanelViewModel
    @ObservedObject var settingsManager = SettingsManager.shared

    var body: some View {
        VStack(spacing: 0) {
            MainPanelSearchBar(text: Binding(
                get: { viewModel.state.searchQuery },
                set: { viewModel.send(.searchChanged($0)) }
            ), focusToken: Binding(
                get: { viewModel.state.searchFocusToken },
                set: { _ in }
            ), filterType: Binding(
                get: { viewModel.state.filterType },
                set: { viewModel.send(.filterChanged($0)) }
            ))

            Rectangle()
                .fill(MainPanelTokens.Colors.border)
                .frame(height: 1)

            MainPanelContent(
                items: viewModel.state.items,
                selectedItem: viewModel.state.selectedItem,
                onSelect: { viewModel.send(.itemSelected($0)) }
            )

            Rectangle()
                .fill(MainPanelTokens.Colors.border)
                .frame(height: 1)

            MainPanelFooterView()
        }
        .background {
            MainPanelTokens.Colors.backgroundGradient
            MainPanelVisualEffectView(
                material: MainPanelTokens.Effects.materialHudWindow,
                blendingMode: .behindWindow
            )
            .opacity(settingsManager.settings.appearance.blurIntensity)
            MainPanelTokens.Colors.surface
        }
        .clipShape(RoundedRectangle(cornerRadius: MainPanelTokens.Layout.cornerRadius))
        .shadow(
            color: MainPanelTokens.Effects.panelShadow.color,
            radius: MainPanelTokens.Effects.panelShadow.radius,
            x: MainPanelTokens.Effects.panelShadow.x,
            y: MainPanelTokens.Effects.panelShadow.y
        )
    }
}
