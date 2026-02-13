import SwiftUI

struct StorageLocationSettingsView: View {
    @EnvironmentObject var viewModel: SettingsViewModel
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsRow(title: "Data Location", icon: "folder") {
                VStack(alignment: .trailing, spacing: 8) {
                    Text("App Data: " + viewModel.appData.path)
                        .font(.system(size: 10, weight: .regular))
                        .foregroundColor(DesignSystem.Colors.textTertiary)
                        .textSelection(.enabled)
                    
                    Button(action: {
                        NSWorkspace.shared.open(viewModel.appData)
                    }) {
                        Text("Open")
                            .font(DesignSystem.Typography.captionBold)
                            .foregroundColor(viewModel.settings.appearance.themeColor.toColor())
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(viewModel.settings.appearance.themeColor.toColor().opacity(0.1))
                            .cornerRadius(4)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(viewModel.settings.appearance.themeColor.toColor().opacity(0.3), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .onHover { inside in
                        if inside {
                            NSCursor.pointingHand.push()
                        } else {
                            NSCursor.pop()
                        }
                    }
                }
            }
        }
    }
}
