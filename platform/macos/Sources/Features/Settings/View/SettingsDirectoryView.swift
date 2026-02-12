import SwiftUI
import AppKit

struct SettingsDirectoryView: View {
    @EnvironmentObject var viewModel: SettingsViewModel
    @State private var showingRestartAlert = false
    @State private var newDirectoryURL: URL?
    @State private var errorMessage: String?
    @State private var showingErrorAlert = false
    
    var body: some View {
        Form {
            Section(header: Text("Storage Location")) {
                Text(viewModel.clipboardData.path)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .textSelection(.enabled)
                
                HStack {
                    Button("Show in Finder") {
                        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: viewModel.clipboardData.path)
                    }
                    
                    Button("Change Location...") {
                        selectNewDirectory()
                    }

                    Button("恢复默认路径") {
                        viewModel.restoreDefaultClipboardDataDirectory()
                        showingRestartAlert = true
                    }
                }
            }
            
            Section(footer: Text("Changing the storage location requires restarting the application.")) {
                EmptyView()
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
        .padding()
    }
    
    private func selectNewDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.prompt = "Select"
        panel.message = "Select a new location for Pasty settings and data"
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                self.validateAndSetDirectory(url)
            }
        }
    }
    
    private func validateAndSetDirectory(_ url: URL) {
        StorageLocationHelper.validateAndSetDirectory(url, settingsViewModel: viewModel, showError: { message in
            errorMessage = message
            showingErrorAlert = true
        }, showRestart: {
            showingRestartAlert = true
            newDirectoryURL = url
        })
    }
    
    private func restartApp() {
        let url = URL(fileURLWithPath: Bundle.main.bundlePath)
        NSWorkspace.shared.open(url)
        NSApp.terminate(nil)
    }
}
