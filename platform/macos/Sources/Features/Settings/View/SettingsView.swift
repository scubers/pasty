import SwiftUI

struct SettingsView: View {
    @State private var selectedTab: SettingsTab = .general
    @State private var sidebarWidth: CGFloat = 200
    @EnvironmentObject var viewModel: SettingsViewModel
    @EnvironmentObject var appCoordinator: AppCoordinator

    var body: some View {
        HStack(spacing: 0) {
            SettingsSidebarView(selection: $selectedTab)
                .frame(width: sidebarWidth)

            Rectangle()
                .fill(DesignSystem.Colors.border)
                .frame(width: 1)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { gesture in
                            let newWidth = sidebarWidth + gesture.translation.width
                            sidebarWidth = max(150, min(newWidth, 400))
                        }
                )

            SettingsContentContainer(selection: selectedTab)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
//        .frame(width: 800, height: 550)
        .background {
            DesignSystem.Colors.backgroundStart
            VisualEffectBlur(
                material: .hudWindow,
                blendingMode: .behindWindow
            )
            .opacity(viewModel.blurIntensity)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(DesignSystem.Colors.border, lineWidth: 1)
        )
        .ignoresSafeArea()
        // Handle Cmd+W to close window
        .background(
            Button("") {
                NSApp.keyWindow?.close()
            }
            .keyboardShortcut("w", modifiers: .command)
            .hidden()
        )
    }
}
