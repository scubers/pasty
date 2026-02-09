import SwiftUI
import AppKit

struct StorageLocationSettingsView: View {
    @ObservedObject var settingsManager = SettingsManager.shared
    @State private var showingRestartAlert = false
    @State private var errorMessage: String?
    @State private var showingErrorAlert = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsRow(title: "Data Location", icon: "folder") {
                Text(settingsManager.settingsDirectory.path)
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .textSelection(.enabled)
            }

            SettingsRow(title: "", icon: "") {
                HStack(spacing: 8) {
                    Button("Show in Finder") {
                        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: settingsManager.settingsDirectory.path)
                    }

                    Button("Change...") {
                        selectNewDirectory()
                    }
                }
            }
        }
        .alert("Restart Required", isPresented: $showingRestartAlert) {
            Button("Restart Now") {
                restartApp()
            }
            Button("Later", role: .cancel) {}
        } message: {
            Text("Pasty2 needs to restart to use the new storage location.")
        }
        .alert("Error", isPresented: $showingErrorAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "Unknown error")
        }
    }

    private func selectNewDirectory() {
        StorageLocationHelper.selectNewDirectory(settingsManager: settingsManager) { url in
            if let url = url {
                migrateAndSetDirectory(url)
            }
        }
    }

    private func migrateAndSetDirectory(_ url: URL) {
        StorageLocationHelper.migrateAndSetDirectory(url, settingsManager: settingsManager, showError: { message in
            errorMessage = message
            showingErrorAlert = true
        }, showRestart: {
            showingRestartAlert = true
        })
    }

    private func restartApp() {
        let url = URL(fileURLWithPath: Bundle.main.bundlePath)
        NSWorkspace.shared.open(url)
        NSApp.terminate(nil)
    }
}
