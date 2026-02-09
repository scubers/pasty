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

                Spacer()
            }
            .padding(32)
        }
    }
}
