import SwiftUI
import ServiceManagement

struct GeneralSettingsView: View {
    @ObservedObject var settingsManager = SettingsManager.shared
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                SettingsSection(title: "Startup") {
                    SettingsRow(title: "Launch at Login", icon: "power") {
                        PastyToggle(isOn: Binding(
                            get: { settingsManager.settings.general.launchAtLogin },
                            set: { newValue in
                                settingsManager.settings.general.launchAtLogin = newValue
                                setLaunchAtLogin(newValue)
                            }
                        ))
                    }
                }
                
                SettingsSection(title: "Reset") {
                    SettingsRow(title: "Restore Default Settings", icon: "arrow.counterclockwise") {
                        DangerButton(title: "Restore") {
                            settingsManager.settings = .default
                            settingsManager.saveSettings()
                        }
                    }
                }
                
                Spacer()
            }
            .padding(32)
        }
    }
    
    private func setLaunchAtLogin(_ enabled: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                print("Failed to update launch at login: \(error)")
            }
        }
    }
}
