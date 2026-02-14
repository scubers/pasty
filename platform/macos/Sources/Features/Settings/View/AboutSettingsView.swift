import SwiftUI

struct AboutSettingsView: View {
    @EnvironmentObject var viewModel: SettingsViewModel

    private var versionText: String {
        if let shortVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String {
            return "Version \(shortVersion)"
        } else if let bundleVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String {
            return "Version \(bundleVersion)"
        } else {
            return "Version -"
        }
    }

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(nsImage: NSImage(named: "AppIcon") ?? NSImage())
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .shadow(radius: 10)
            
            VStack(spacing: 8) {
                Text("Pasty")
                    .font(DesignSystem.Typography.largeTitle)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                
                Text(versionText)
                    .font(DesignSystem.Typography.body)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }
            
//            VStack(spacing: 16) {
//                LinkButton(title: "Website", url: "https://pasty.app")
//                LinkButton(title: "GitHub", url: "https://github.com/scubers/pasty")
//                LinkButton(title: "Privacy Policy", url: "https://pasty.app/privacy")
//            }
//            .padding(.top, 20)
            
            Spacer()
            
            Text("Copyright © 2026 Pasty Team")
                .font(DesignSystem.Typography.caption)
                .foregroundColor(DesignSystem.Colors.textTertiary)
                .padding(.bottom, 32)
        }
        .frame(maxWidth: .infinity)
    }
}

struct LinkButton: View {
    let title: String
    let url: String
    @EnvironmentObject var viewModel: SettingsViewModel

    var body: some View {
        Button(action: {
            if let url = URL(string: url) {
                NSWorkspace.shared.open(url)
            }
        }) {
            Text(title)
                .font(DesignSystem.Typography.bodyBold)
                .foregroundColor(viewModel.settings.appearance.themeColor.toColor())
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
