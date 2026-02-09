import SwiftUI

struct AppearanceSettingsView: View {
    @ObservedObject var settingsManager = SettingsManager.shared
    
    let accentColors: [(Color, String)] = [
        (Color(hex: "2DD4BF"), "system"), // Default/Teal
        (.blue, "blue"),
        (.purple, "purple"),
        (.pink, "pink"),
        (.red, "red"),
        (.orange, "orange"),
        (.yellow, "yellow"),
        (.green, "green")
    ]
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                SettingsSection(title: "Theme") {
                    SettingsRow(title: "Mode", icon: "circle.lefthalf.filled") {
                        ThemePicker(selection: Binding(
                            get: { settingsManager.settings.appearance.themeMode },
                            set: { settingsManager.settings.appearance.themeMode = $0 }
                        ))
                    }
                }
                
                SettingsSection(title: "Style") {
                    SettingsRow(title: "Accent Color", icon: "paintpalette") {
                        HStack(spacing: 8) {
                            ForEach(accentColors, id: \.1) { color, name in
                                ColorOption(color: color, isSelected: settingsManager.settings.appearance.themeColor == name)
                                    .onTapGesture {
                                        settingsManager.settings.appearance.themeColor = name
                                    }
                            }
                        }
                    }
                    
                    SettingsRow(title: "Window Blur", icon: "drop.triangle") {
                         VStack(alignment: .trailing) {
                            Text("\(Int(settingsManager.settings.appearance.blurIntensity * 100))%")
                                .font(DesignSystem.Typography.caption)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                            
                            PastySlider(
                                value: Binding(
                                    get: { settingsManager.settings.appearance.blurIntensity },
                                    set: { settingsManager.settings.appearance.blurIntensity = $0 }
                                ),
                                range: 0.0...1.0
                            )
                        }
                    }
                }
                
                Spacer()
            }
            .padding(32)
        }
    }
}

struct ColorOption: View {
    let color: Color
    let isSelected: Bool
    
    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 20, height: 20)
            .overlay(
                Circle()
                    .stroke(Color.white, lineWidth: isSelected ? 2 : 0)
            )
            .shadow(radius: 2)
    }
}
