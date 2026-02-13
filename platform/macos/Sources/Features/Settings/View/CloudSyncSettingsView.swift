import SwiftUI

struct CloudSyncSettingsView: View {
    @EnvironmentObject var viewModel: SettingsViewModel
    
    private var themeColor: Color { viewModel.settings.appearance.themeColor.toColor() }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsRow(title: "Enable Sync", icon: "icloud") {
                PastyToggle(isOn: viewModel.binding(\.cloudSync.enabled), activeColor: themeColor)
            }
            
            if viewModel.settings.cloudSync.enabled {
                SettingsRow(title: "Sync Directory", icon: "folder") {
                    HStack {
                        Text(viewModel.settings.cloudSync.rootPath.isEmpty ? "Not set" : viewModel.settings.cloudSync.rootPath)
                            .font(.caption)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: 200, alignment: .leading)
                            .help(viewModel.settings.cloudSync.rootPath)
                        
                        Button("Choose...") {
                            viewModel.selectCloudSyncDirectory()
                        }
                    }
                }
                
                if !viewModel.cloudSyncIsDirectoryValid && !viewModel.settings.cloudSync.rootPath.isEmpty {
                    Text("Directory is not accessible or writable")
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.leading, 40)
                        .padding(.bottom, 8)
                }
                
                SettingsRow(title: "Include Sensitive Data", icon: "lock.open") {
                    PastyToggle(isOn: viewModel.binding(\.cloudSync.includeSensitive), activeColor: .red)
                }
                
                Divider()
                    .padding(.vertical, 12)
                
                VStack(alignment: .leading, spacing: 6) {
                    statusRow(label: "Device ID", value: viewModel.deviceId ?? "Unknown")
                    statusRow(label: "Last Sync", value: viewModel.cloudSyncLastSync?.formatted(date: .abbreviated, time: .shortened) ?? "Never")
                    
                    if viewModel.cloudSyncErrorCount > 0 {
                        statusRow(label: "Sync Errors", value: "\(viewModel.cloudSyncErrorCount)", color: .red)
                    } else {
                        statusRow(label: "Sync Status", value: "Healthy", color: .green)
                    }
                }
                .padding(.leading, 4)
            }
        }
        .onAppear {
            viewModel.refreshCloudSyncStatus()
        }
    }
    
    private func statusRow(label: String, value: String, color: Color = .secondary) -> some View {
        HStack {
            Text(label + ":")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .leading)
            Text(value)
                .font(.caption)
                .foregroundColor(color)
        }
    }
}
