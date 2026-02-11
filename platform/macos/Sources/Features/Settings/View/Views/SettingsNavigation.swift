import SwiftUI

enum SettingsTab: String, CaseIterable, Identifiable {
    case general = "General"
    case clipboard = "Clipboard"
    case appearance = "Appearance"
    case ocr = "OCR"
    case shortcuts = "Shortcuts"
    case about = "About"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .general: return "gearshape.fill"
        case .clipboard: return "doc.on.clipboard.fill"
        case .appearance: return "paintpalette.fill"
        case .ocr: return "text.viewfinder"
        case .shortcuts: return "keyboard.fill"
        case .about: return "info.circle.fill"
        }
    }
}
