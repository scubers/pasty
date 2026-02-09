import SwiftUI

struct AboutSettingsView: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            // App Icon Placeholder
            Image(systemName: "doc.on.clipboard.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 80, height: 80)
                .foregroundColor(DesignSystem.Colors.accent)
                .shadow(color: DesignSystem.Colors.accent.opacity(0.5), radius: 10)
            
            VStack(spacing: 8) {
                Text("Pasty")
                    .font(DesignSystem.Typography.largeTitle)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                
                Text("Version 2.0.0")
                    .font(DesignSystem.Typography.body)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }
            
            VStack(spacing: 16) {
                LinkButton(title: "Website", url: "https://pasty.app")
                LinkButton(title: "GitHub", url: "https://github.com/scubers/pasty")
                LinkButton(title: "Privacy Policy", url: "https://pasty.app/privacy")
            }
            .padding(.top, 20)
            
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
    
    var body: some View {
        Button(action: {
            if let url = URL(string: url) {
                NSWorkspace.shared.open(url)
            }
        }) {
            Text(title)
                .font(DesignSystem.Typography.bodyBold)
                .foregroundColor(DesignSystem.Colors.accent)
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
