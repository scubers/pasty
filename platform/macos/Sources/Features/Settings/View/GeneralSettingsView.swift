import SwiftUI
import ServiceManagement
import KeyboardShortcuts

struct GeneralSettingsView: View {
    @EnvironmentObject var viewModel: SettingsViewModel
    @State private var showingRestoreConfirm = false
    private var themeColor: Color { viewModel.settings.appearance.themeColor.toColor() }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                SettingsSection(title: "Startup") {
                    SettingsRow(title: "Launch at Login", icon: "power") {
                        PastyToggle(isOn: Binding(
                            get: { viewModel.settings.general.launchAtLogin },
                            set: { newValue in
                                viewModel.updateSettings { $0.general.launchAtLogin = newValue }
                                setLaunchAtLogin(newValue)
                            }
                        ), activeColor: themeColor)
                    }
                }

                SettingsSection(title: "Storage") {
                    StorageLocationSettingsView()
                }

                SettingsSection(title: "Shortcuts") {
                    SettingsRow(title: "Toggle Pasty Panel", icon: "command") {
                        KeyboardShortcuts.Recorder(for: .togglePanel)
                            .padding(.vertical, 4)
                    }
                }

                SettingsSection(title: "Reset") {
                    SettingsRow(title: "Restore Default Settings", icon: "arrow.counterclockwise") {
                        DangerButton(title: "Restore") {
                            showingRestoreConfirm = true
                        }
                    }
                }
                .alert("Confirm Restore Default Settings", isPresented: $showingRestoreConfirm) {
                    Button("Cancel", role: .cancel) {}
                    Button("Restore", role: .destructive) {
                        viewModel.restoreDefaults()
                    }
                } message: {
                    Text("This will reset all settings to default values and cannot be undone.")
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
                LoggerService.error("Failed to update launch at login: \(error)")
            }
        }
    }
}
