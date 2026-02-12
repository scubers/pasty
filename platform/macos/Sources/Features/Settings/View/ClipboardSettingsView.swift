import SwiftUI

struct ClipboardSettingsView: View {
    @EnvironmentObject var viewModel: SettingsViewModel
    @State private var showingClearConfirm = false
    private var themeColor: Color { viewModel.settings.appearance.themeColor.toColor() }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                SettingsSection(title: "History") {
                    SettingsRow(title: "Max History Items", icon: "list.bullet") {
                        VStack(alignment: .trailing) {
                            Text("\(viewModel.settings.history.maxCount) items")
                                .font(DesignSystem.Typography.caption)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                            
                            PastySlider(
                                value: Binding(
                                    get: { Double(viewModel.settings.history.maxCount) },
                                    set: { newValue in
                                        viewModel.updateSettings { $0.history.maxCount = Int(newValue) }
                                    }
                                ),
                                accentColor: themeColor,
                                range: 50...5000
                            )
                        }
                    }
                }
                
                SettingsSection(title: "Performance") {
                     SettingsRow(title: "Polling Interval", icon: "timer") {
                        VStack(alignment: .trailing) {
                            Text("\(viewModel.settings.clipboard.pollingIntervalMs) ms")
                                .font(DesignSystem.Typography.caption)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                            
                            PastySlider(
                                value: Binding(
                                    get: { Double(viewModel.settings.clipboard.pollingIntervalMs) },
                                    set: { newValue in
                                        viewModel.updateSettings { $0.clipboard.pollingIntervalMs = Int(newValue) }
                                    }
                                ),
                                accentColor: themeColor,
                                range: 100...2000
                            )
                        }
                    }
                    
                    SettingsRow(title: "Max Content Size", icon: "arrow.up.arrow.down.square") {
                        VStack(alignment: .trailing) {
                            Text("\(viewModel.settings.clipboard.maxContentSizeBytes / 1024 / 1024) MB")
                                .font(DesignSystem.Typography.caption)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                            
                            PastySlider(
                                value: Binding(
                                    get: { Double(viewModel.settings.clipboard.maxContentSizeBytes) },
                                    set: { newValue in
                                        viewModel.updateSettings { $0.clipboard.maxContentSizeBytes = Int(newValue) }
                                    }
                                ),
                                accentColor: themeColor,
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
