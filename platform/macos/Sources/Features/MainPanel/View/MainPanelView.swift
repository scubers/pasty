import SwiftUI

struct MainPanelView: View {
    @EnvironmentObject var viewModel: MainPanelViewModel
    @EnvironmentObject var appCoordinator: AppCoordinator

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

            MainPanelFooterView(totalItemCount: viewModel.state.totalItemCount)
        }
        .background {
            MainPanelTokens.Colors.backgroundGradient
            MainPanelVisualEffectView(
                material: MainPanelTokens.Effects.materialHudWindow,
                blendingMode: .behindWindow
            )
            .opacity(appCoordinator.settings.appearance.blurIntensity)
            MainPanelTokens.Colors.surface
        }
        .clipShape(RoundedRectangle(cornerRadius: MainPanelTokens.Layout.cornerRadius))
        .shadow(
            color: MainPanelTokens.Effects.panelShadow.color,
            radius: MainPanelTokens.Effects.panelShadow.radius,
            x: MainPanelTokens.Effects.panelShadow.x,
            y: MainPanelTokens.Effects.panelShadow.y
        )
        .sheet(isPresented: Binding(
            get: { viewModel.state.isTagEditorPresented },
            set: { _ in viewModel.send(.closeTagEditor) }
        )) {
            TagEditorSheet(focusToken: Binding(
                get: { viewModel.state.tagEditorFocusToken },
                set: { _ in }
            ))
                .environmentObject(viewModel)
        }
    }
}
