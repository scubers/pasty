import SwiftUI

struct AppearanceSettingsView: View {
    @ObservedObject var settingsManager = SettingsManager.shared
    
    var body: some View {
        Form {
            Section(header: Text("Theme")) {
                VStack(alignment: .leading) {
                    Text("Accent Color")
                    HStack {
                        ColorButton(color: .teal, name: "system")
                        ColorButton(color: .blue, name: "blue")
                        ColorButton(color: .purple, name: "purple")
                        ColorButton(color: .pink, name: "pink")
                        ColorButton(color: .red, name: "red")
                        ColorButton(color: .orange, name: "orange")
                        ColorButton(color: .yellow, name: "yellow")
                        ColorButton(color: .green, name: "green")
                    }
                }
                
                VStack(alignment: .leading) {
                    Text("Background Blur: \(Int(settingsManager.settings.appearance.blurIntensity * 100))%")
                    Slider(
                        value: Binding(
                            get: { settingsManager.settings.appearance.blurIntensity },
                            set: { settingsManager.settings.appearance.blurIntensity = $0 }
                        ),
                        in: 0.0...1.0,
                        step: 0.1
                    ) {
                        Text("Blur")
                    } minimumValueLabel: {
                        Text("Off")
                    } maximumValueLabel: {
                        Text("Max")
                    }
                }
            }
            
            Section(header: Text("Panel Size")) {
                HStack {
                    TextField("Width", value: Binding(
                        get: { settingsManager.settings.appearance.panelWidth },
                        set: { settingsManager.settings.appearance.panelWidth = $0 }
                    ), format: .number)
                    .frame(width: 80)
                    
                    Text("×")
                    
                    TextField("Height", value: Binding(
                        get: { settingsManager.settings.appearance.panelHeight },
                        set: { settingsManager.settings.appearance.panelHeight = $0 }
                    ), format: .number)
                    .frame(width: 80)
                }
                Text("Default: 800 × 500")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }
    
    private struct ColorButton: View {
        let color: Color
        let name: String
        @ObservedObject var settingsManager = SettingsManager.shared
        
        var body: some View {
            Button {
                settingsManager.settings.appearance.themeColor = name
            } label: {
                Circle()
                    .fill(color)
                    .frame(width: 20, height: 20)
                    .overlay(
                        Circle()
                            .strokeBorder(Color.primary, lineWidth: settingsManager.settings.appearance.themeColor == name ? 2 : 0)
                    )
            }
            .buttonStyle(.plain)
        }
    }
}
