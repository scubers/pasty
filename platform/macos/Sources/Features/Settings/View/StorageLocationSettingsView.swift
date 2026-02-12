import SwiftUI
import AppKit

struct StorageLocationSettingsView: View {
    @EnvironmentObject var viewModel: SettingsViewModel
    @State private var showingRestartAlert = false
    @State private var errorMessage: String?
    @State private var showingErrorAlert = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsRow(title: "Data Location", icon: "folder") {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Clipboard Data: " + viewModel.clipboardData.path)
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .textSelection(.enabled)
                    Text("App Data: " + viewModel.appData.path)
                        .font(.system(size: 10, weight: .regular))
                        .foregroundColor(DesignSystem.Colors.textTertiary)
                        .textSelection(.enabled)
                }
            }

            SettingsRow(title: "", icon: "") {
                HStack(spacing: 8) {
                    Button("Show in Finder") {
                        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: viewModel.clipboardData.path)
                    }

                    Button("Change...") {
                        selectNewDirectory()
                    }

                    Button("恢复默认路径") {
                        viewModel.restoreDefaultClipboardDataDirectory()
                        showingRestartAlert = true
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
            Text("Pasty needs to restart to use the new storage location.")
        }
        .alert("Error", isPresented: $showingErrorAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "Unknown error")
        }
    }

    private func selectNewDirectory() {
        StorageLocationHelper.selectNewDirectory { url in
            if let url = url {
                validateAndSetDirectory(url)
            }
        }
    }

    private func validateAndSetDirectory(_ url: URL) {
        StorageLocationHelper.validateAndSetDirectory(url, settingsViewModel: viewModel, showError: { message in
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
