import SwiftUI

struct PastyPicker<T: Hashable & CustomStringConvertible>: View {
    var title: String?
    @Binding var selection: T
    let options: [T]
    
    var body: some View {
        HStack {
            if let title = title {
                Text(title)
                    .font(DesignSystem.Typography.body)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                Spacer()
            }
            
            Menu {
                ForEach(options, id: \.self) { option in
                    Button {
                        selection = option
                    } label: {
                        if option == selection {
                            Label(option.description, systemImage: "checkmark")
                        } else {
                            Text(option.description)
                        }
                    }
                }
            } label: {
                HStack {
                    Text(selection.description)
                        .font(DesignSystem.Typography.body)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                        .lineLimit(1)
                    
                    Spacer(minLength: 8)
                    
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 10))
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(DesignSystem.Colors.controlBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(DesignSystem.Colors.border, lineWidth: 0.5)
                )
            }
            .menuStyle(.borderlessButton)
            .frame(minWidth: 120)
            .fixedSize(horizontal: true, vertical: false)
        }
    }
}
