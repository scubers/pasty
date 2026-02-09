import SwiftUI

struct SettingsContentContainer: View {
    let selection: SettingsTab
    
    var body: some View {
        ZStack {
            switch selection {
            case .general:
                GeneralSettingsView()
            case .clipboard:
                Text("Clipboard Settings")
                    .font(DesignSystem.Typography.title)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
            case .appearance:
                AppearanceSettingsView()
            case .ocr:
                Text("OCR Settings")
                    .font(DesignSystem.Typography.title)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
            case .shortcuts:
                ShortcutsSettingsView()
            case .about:
                AboutSettingsView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
