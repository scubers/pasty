import SwiftUI
import KeyboardShortcuts
import ServiceManagement

struct GeneralSettingsView: View {
    @ObservedObject var settingsManager = SettingsManager.shared
    
    var body: some View {
        Form {
            Section {
                Toggle("Launch at Login", isOn: Binding(
                    get: { settingsManager.settings.general.launchAtLogin },
                    set: { newValue in
                        settingsManager.settings.general.launchAtLogin = newValue
                        setLaunchAtLogin(newValue)
                    }
                ))
            }
            
            Section(header: Text("Keyboard Shortcuts")) {
                HStack {
                    Text("Toggle Panel")
                    Spacer()
                    KeyboardShortcuts.Recorder(for: .togglePanel)
                }
            }
            
            Section {
                Button("Restore Default Settings") {
                    settingsManager.settings = .default
                    settingsManager.saveSettings()
                }
            }
        }
        .padding()
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
