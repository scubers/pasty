import SwiftUI

struct SettingsView: View {
    @State private var selectedTab: SettingsTab = .general
    @ObservedObject var settingsManager = SettingsManager.shared
    
    var colorScheme: ColorScheme? {
        switch settingsManager.settings.appearance.themeMode {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }
    
    var body: some View {
        HStack(spacing: 0) {
            SettingsSidebarView(selection: $selectedTab)
            
            SettingsContentContainer(selection: selectedTab)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 800, height: 550)
        .background(DesignSystem.Colors.backgroundStart)
        .background(
             VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
        )
        .overlay(
            Rectangle()
                .stroke(DesignSystem.Colors.border, lineWidth: 1)
        )
        .ignoresSafeArea()
        .preferredColorScheme(colorScheme)
    }
}
