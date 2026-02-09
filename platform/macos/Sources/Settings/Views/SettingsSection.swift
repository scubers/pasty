import SwiftUI

struct SettingsSection<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(DesignSystem.Typography.bodyBold)
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .padding(.leading, 4)
            
            VStack(spacing: 0) {
                content
            }
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(DesignSystem.Colors.controlBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(DesignSystem.Colors.border, lineWidth: 0.5)
            )
        }
        .padding(.bottom, 20)
    }
}

struct SettingsRow<Content: View>: View {
    let title: String
    let icon: String?
    let content: Content
    
    init(title: String, icon: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }
    
    var body: some View {
        HStack {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .frame(width: 24)
            }
            
            Text(title)
                .font(DesignSystem.Typography.body)
                .foregroundColor(DesignSystem.Colors.textPrimary)
            
            Spacer()
            
            content
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}
