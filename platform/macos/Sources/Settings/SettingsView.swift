import SwiftUI

struct SettingsView: View {
    @State private var selectedTab: SettingsTab = .general
    
    enum SettingsTab: String, CaseIterable, Identifiable {
        case general = "General"
        case clipboard = "Clipboard"
        case ocr = "OCR"
        case appearance = "Appearance"
        case storage = "Storage"
        
        var id: String { rawValue }
        
        var icon: String {
            switch self {
            case .general: return "gearshape"
            case .clipboard: return "doc.on.clipboard"
            case .ocr: return "text.viewfinder"
            case .appearance: return "paintpalette"
            case .storage: return "externaldrive"
            }
        }
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }
                .tag(SettingsTab.general)
            
            ClipboardSettingsView()
                .tabItem {
                    Label("Clipboard", systemImage: "doc.on.clipboard")
                }
                .tag(SettingsTab.clipboard)
            
            OCRSettingsView()
                .tabItem {
                    Label("OCR", systemImage: "text.viewfinder")
                }
                .tag(SettingsTab.ocr)
            
            AppearanceSettingsView()
                .tabItem {
                    Label("Appearance", systemImage: "paintpalette")
                }
                .tag(SettingsTab.appearance)
            
            SettingsDirectoryView()
                .tabItem {
                    Label("Storage", systemImage: "externaldrive")
                }
                .tag(SettingsTab.storage)
        }
        .frame(width: 500, height: 400)
        .padding()
    }
}
