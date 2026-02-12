import SwiftUI

struct PastyToggle: View {
    @Binding var isOn: Bool
    var activeColor: Color = DesignSystem.Colors.accent
    var title: String? = nil

    var body: some View {
        HStack {
            if let title = title {
                Text(title)
                    .font(DesignSystem.Typography.body)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                Spacer()
            }

            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(isOn ? activeColor : DesignSystem.Colors.controlBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(DesignSystem.Colors.border, lineWidth: 0.5)
                    )
                    .animation(.easeInOut(duration: 0.2), value: isOn)
                
                Circle()
                    .fill(Color.white)
                    .padding(3)
                    .offset(x: isOn ? 10 : -10)
                    .shadow(radius: 1)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isOn)
            }
            .frame(width: 44, height: 24)
            .contentShape(Rectangle())
            .onTapGesture {
                isOn.toggle()
            }
        }
    }
}
