import SwiftUI

struct CloudSyncSettingsView: View {
    @EnvironmentObject var viewModel: SettingsViewModel
    @State private var isShowingPassphraseSheet = false
    
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

                SettingsRow(title: "Include Source App", icon: "app") {
                    VStack(alignment: .trailing, spacing: 2) {
                        PastyToggle(isOn: viewModel.binding(\.cloudSync.includeSourceAppId), activeColor: themeColor)
                        Text("Hides app attribution when off")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }

                Divider()
                    .padding(.vertical, 12)

                SettingsRow(title: "End-to-End Encryption", icon: "key") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            if viewModel.e2eeUnlocked {
                                Label("Encrypted", systemImage: "checkmark.shield.fill")
                                    .foregroundColor(.green)
                            } else {
                                Label("Not Encrypted", systemImage: "exclamationmark.shield")
                                    .foregroundColor(.orange)
                            }
                            
                            Spacer()
                            
                            if viewModel.e2eeUnlocked {
                                Menu {
                                    Button("Change Passphrase...") {
                                        isShowingPassphraseSheet = true
                                    }
                                    Button("Remove Passphrase", role: .destructive) {
                                        viewModel.deletePassphrase()
                                    }
                                } label: {
                                    Text("Manage")
                                }
                                .fixedSize()
                            } else {
                                Button("Set Passphrase...") {
                                    isShowingPassphraseSheet = true
                                }
                            }
                        }
                        
                        if let keyId = viewModel.e2eeKeyId {
                            Text("Key ID: \(keyId)")
                                .font(.caption2)
                                .monospaced()
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .sheet(isPresented: $isShowingPassphraseSheet) {
                    CloudSyncE2eePassphraseSheet { passphrase in
                        viewModel.savePassphrase(passphrase)
                    }
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
