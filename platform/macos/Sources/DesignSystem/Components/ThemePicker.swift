import SwiftUI

struct ThemePicker: View {
    @Binding var selection: String
    
    var body: some View {
        HStack(spacing: 16) {
            ThemeCard(title: "System", icon: "circle.lefthalf.filled", isSelected: selection == "system")
                .onTapGesture { selection = "system" }
            
            ThemeCard(title: "Dark", icon: "moon.fill", isSelected: selection == "dark")
                .onTapGesture { selection = "dark" }
            
            ThemeCard(title: "Light", icon: "sun.max.fill", isSelected: selection == "light")
                .onTapGesture { selection = "light" }
        }
    }
}

struct ThemeCard: View {
    let title: String
    let icon: String
    let isSelected: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(DesignSystem.Colors.controlBackground)
                    .frame(width: 100, height: 60)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? DesignSystem.Colors.accent : DesignSystem.Colors.border, lineWidth: isSelected ? 2 : 1)
                    )
                
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(isSelected ? DesignSystem.Colors.accent : DesignSystem.Colors.textSecondary)
            }
            
            HStack(spacing: 4) {
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(DesignSystem.Colors.accent)
                        .font(.system(size: 12))
                }
                Text(title)
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(isSelected ? DesignSystem.Colors.textPrimary : DesignSystem.Colors.textSecondary)
            }
        }
        .contentShape(Rectangle())
    }
}
