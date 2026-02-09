import SwiftUI
import AppKit

struct SettingsDirectoryView: View {
    @ObservedObject var settingsManager = SettingsManager.shared
    @State private var showingRestartAlert = false
    @State private var newDirectoryURL: URL?
    @State private var errorMessage: String?
    @State private var showingErrorAlert = false
    
    var body: some View {
        Form {
            Section(header: Text("Storage Location")) {
                Text(settingsManager.settingsDirectory.path)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .textSelection(.enabled)
                
                HStack {
                    Button("Show in Finder") {
                        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: settingsManager.settingsDirectory.path)
                    }
                    
                    Button("Change Location...") {
                        selectNewDirectory()
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
            Text("Pasty2 needs to restart to use the new storage location.")
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
        panel.message = "Select a new location for Pasty2 settings and data"
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                self.migrateAndSetDirectory(url)
            }
        }
    }
    
    private func migrateAndSetDirectory(_ url: URL) {
        if !FileManager.default.isWritableFile(atPath: url.path) {
            errorMessage = "The selected directory is not writable."
            showingErrorAlert = true
            return
        }
        
        do {
            let oldURL = settingsManager.settingsDirectory
            let fileManager = FileManager.default
            
            let itemsToCopy = ["settings.json", "history.sqlite3", "images"]
            
            for item in itemsToCopy {
                let source = oldURL.appendingPathComponent(item)
                let dest = url.appendingPathComponent(item)
                
                if fileManager.fileExists(atPath: source.path) {
                    if fileManager.fileExists(atPath: dest.path) {
                        try fileManager.removeItem(at: dest)
                    }
                    try fileManager.copyItem(at: source, to: dest)
                }
            }
            
            settingsManager.setSettingsDirectory(url)
            showingRestartAlert = true
            newDirectoryURL = url
        } catch {
            errorMessage = "Migration failed: \(error.localizedDescription)"
            showingErrorAlert = true
        }
    }
    
    private func restartApp() {
        let url = URL(fileURLWithPath: Bundle.main.bundlePath)
        NSWorkspace.shared.open(url)
        NSApp.terminate(nil)
    }
}
