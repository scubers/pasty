import SwiftUI
import KeyboardShortcuts

struct ShortcutsSettingsView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                SettingsSection(title: "Global Shortcuts") {
                    SettingsRow(title: "Toggle Pasty Panel", icon: "command") {
                        KeyboardShortcuts.Recorder(for: .togglePanel)
                            .padding(.vertical, 4)
                    }
                }
                
                SettingsSection(title: "In-App Shortcuts") {
                    SettingsRow(title: "Clear All History", icon: "trash") {
                        Text("Cmd + Shift + Backspace")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(DesignSystem.Colors.controlBackground)
                            .cornerRadius(4)
                    }
                    
                    SettingsRow(title: "Search", icon: "magnifyingglass") {
                        Text("Cmd + F")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(DesignSystem.Colors.controlBackground)
                            .cornerRadius(4)
                    }
                }
                
                Spacer()
            }
            .padding(32)
        }
    }
}
