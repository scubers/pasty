import SwiftUI

struct SettingsDirectoryView: View {
    @EnvironmentObject var viewModel: SettingsViewModel
    var body: some View {
        Form {
            Section(header: Text("App Data Location")) {
                Text(viewModel.appData.path)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .textSelection(.enabled)
            }
        }
        .padding()
    }
}
