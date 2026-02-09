import SwiftUI

enum DesignSystem {
    struct Colors {
        // Main Background Gradient
        static let backgroundStart = Color(hex: "1a1a2e") // Deep Blue
        static let backgroundEnd = Color(hex: "16213e")   // Slightly lighter/purple-ish

        // Accent
        static let accent = Color(hex: "2DD4BF") // Teal
        
        // Backgrounds
        static let background = Color(hex: "1a1a2e")
        static let panelBackground = Color.black.opacity(0.3)
        static let controlBackground = Color.white.opacity(0.1)
        static let controlHover = Color.white.opacity(0.15)
        static let controlPress = Color.white.opacity(0.05)
        
        // Text
        static let textPrimary = Color.white
        static let textSecondary = Color.white.opacity(0.7)
        static let textTertiary = Color.white.opacity(0.4)
        
        // Borders
        static let border = Color.white.opacity(0.1)
        static let borderLight = Color.white.opacity(0.2)
        
        // Semantic
        static let danger = Color(hex: "EF4444")
        static let success = Color(hex: "10B981")
        static let warning = Color(hex: "F59E0B")
    }

    struct Materials {
        static let sidebarBackground = Color.black.opacity(0.2)
    }

    struct Typography {
        static let largeTitle = Font.system(size: 24, weight: .bold)
        static let title = Font.system(size: 16, weight: .semibold)
        static let body = Font.system(size: 13, weight: .regular)
        static let bodyBold = Font.system(size: 13, weight: .semibold)
        static let caption = Font.system(size: 11, weight: .regular)
        static let captionBold = Font.system(size: 11, weight: .semibold)
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
