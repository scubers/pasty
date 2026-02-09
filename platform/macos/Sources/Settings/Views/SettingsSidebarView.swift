import SwiftUI
import Cocoa

struct SettingsSidebarView: View {
    @Binding var selection: SettingsTab

    var body: some View {
        VStack(spacing: 0) {
            Text("Settings")
                .font(DesignSystem.Typography.largeTitle)
                .foregroundColor(DesignSystem.Colors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 40)
                .padding(.bottom, 20)
                .modifier(WindowDraggableArea())
            
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 4) {
                    ForEach(SettingsTab.allCases) { tab in
                        SidebarItem(tab: tab, isSelected: selection == tab)
                            .onTapGesture {
                                selection = tab
                            }
                    }
                }
                .padding(.horizontal, 10)
            }
            
            Spacer()
        }
        .background(DesignSystem.Materials.sidebarBackground)
        .overlay(
            HStack {
                Spacer()
                Rectangle()
                    .fill(DesignSystem.Colors.border)
                    .frame(width: 1)
            }
        )
    }
}

struct SidebarItem: View {
    let tab: SettingsTab
    let isSelected: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: tab.icon)
                .font(.system(size: 14))
                .foregroundColor(isSelected ? DesignSystem.Colors.textPrimary : DesignSystem.Colors.textSecondary)
                .frame(width: 20)
            
            Text(tab.rawValue)
                .font(DesignSystem.Typography.body)
                .foregroundColor(isSelected ? DesignSystem.Colors.textPrimary : DesignSystem.Colors.textSecondary)
            
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? DesignSystem.Colors.controlBackground : Color.clear)
        )
        .contentShape(Rectangle())
    }
}

struct WindowDraggableArea: ViewModifier {
    func body(content: Content) -> some View {
        content
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        guard let window = NSApp.keyWindow else { return }
                        if let event = NSApp.currentEvent {
                            window.performDrag(with: event)
                        }
                    }
            )
    }
}
