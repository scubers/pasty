import SwiftUI

struct DangerButton: View {
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(DesignSystem.Typography.bodyBold)
                .foregroundColor(DesignSystem.Colors.danger)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(DesignSystem.Colors.danger.opacity(0.1))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(DesignSystem.Colors.danger.opacity(0.3), lineWidth: 1)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
