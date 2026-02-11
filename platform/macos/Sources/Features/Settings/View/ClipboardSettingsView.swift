import SwiftUI

struct ClipboardSettingsView: View {
    @ObservedObject var settingsManager = SettingsManager.shared
    @State private var showingClearConfirm = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                SettingsSection(title: "History") {
                    SettingsRow(title: "Max History Items", icon: "list.bullet") {
                        VStack(alignment: .trailing) {
                            Text("\(settingsManager.settings.history.maxCount) items")
                                .font(DesignSystem.Typography.caption)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                            
                            PastySlider(
                                value: Binding(
                                    get: { Double(settingsManager.settings.history.maxCount) },
                                    set: { settingsManager.settings.history.maxCount = Int($0) }
                                ),
                                range: 50...5000
                            )
                        }
                    }
                }
                
                SettingsSection(title: "Performance") {
                     SettingsRow(title: "Polling Interval", icon: "timer") {
                        VStack(alignment: .trailing) {
                            Text("\(settingsManager.settings.clipboard.pollingIntervalMs) ms")
                                .font(DesignSystem.Typography.caption)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                            
                            PastySlider(
                                value: Binding(
                                    get: { Double(settingsManager.settings.clipboard.pollingIntervalMs) },
                                    set: { settingsManager.settings.clipboard.pollingIntervalMs = Int($0) }
                                ),
                                range: 100...2000
                            )
                        }
                    }
                    
                    SettingsRow(title: "Max Content Size", icon: "arrow.up.arrow.down.square") {
                        VStack(alignment: .trailing) {
                            Text("\(settingsManager.settings.clipboard.maxContentSizeBytes / 1024 / 1024) MB")
                                .font(DesignSystem.Typography.caption)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                            
                            PastySlider(
                                value: Binding(
                                    get: { Double(settingsManager.settings.clipboard.maxContentSizeBytes) },
                                    set: { settingsManager.settings.clipboard.maxContentSizeBytes = Int($0) }
                                ),
                                range: 1024*1024...100*1024*1024
                            )
                        }
                    }
                }
                
                SettingsSection(title: "Data") {
                     SettingsRow(title: "Clear History", icon: "trash") {
                        DangerButton(title: "Clear All") {
                            showingClearConfirm = true
                        }
                    }
                }
                .alert("Confirm Clear All History", isPresented: $showingClearConfirm) {
                    Button("Cancel", role: .cancel) {}
                    Button("Clear", role: .destructive) {
                        clearAllHistory()
                    }
                } message: {
                    Text("This will permanently delete all clipboard history items.")
                }
            }
            .padding(32)
        }
    }

    private func clearAllHistory() {
    }
}
