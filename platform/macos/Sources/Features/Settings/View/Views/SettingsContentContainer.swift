import SwiftUI

struct SettingsContentContainer: View {
    let selection: SettingsTab
    
    var body: some View {
        ZStack {
            switch selection {
            case .general:
                GeneralSettingsView()
            case .clipboard:
                ClipboardSettingsView()
            case .appearance:
                AppearanceSettingsView()
            case .ocr:
                OCRSettingsView()
            case .shortcuts:
                ShortcutsSettingsView()
            case .cloudSync:
                CloudSyncSettingsView()
            case .about:
                AboutSettingsView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
