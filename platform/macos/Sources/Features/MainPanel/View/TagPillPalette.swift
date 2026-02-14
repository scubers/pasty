import SwiftUI

/// Style configuration for tag pills/chips
struct TagPillStyle {
    let background: Color
    let foreground: Color
}

enum TagPillPalette {
    /// Palette of 16 tag styles with coordinated background and foreground colors
    static let styles: [TagPillStyle] = [
        // Light backgrounds (need dark text #212529)
        TagPillStyle(background: Color(hex: 0xFCC419), foreground: Color(hex: 0xFFFFFF)), // 3 Yellow
        TagPillStyle(background: Color(hex: 0x51CF66), foreground: Color(hex: 0xFFFFFF)), // 4 Green
        TagPillStyle(background: Color(hex: 0x20C997), foreground: Color(hex: 0xFFFFFF)), // 5 Teal
        TagPillStyle(background: Color(hex: 0xFFD8A8), foreground: Color(hex: 0xFFFFFF)), // 16 Peach

        // Dark/saturated backgrounds (need white text #FFFFFF)
        TagPillStyle(background: Color(hex: 0xFF6B6B), foreground: Color(hex: 0xFFFFFF)), // 1 Red
        TagPillStyle(background: Color(hex: 0xFF922B), foreground: Color(hex: 0xFFFFFF)), // 2 Orange
        TagPillStyle(background: Color(hex: 0x08A045), foreground: Color(hex: 0xFFFFFF)), // 6 Forest Green
        TagPillStyle(background: Color(hex: 0x339AF0), foreground: Color(hex: 0xFFFFFF)), // 7 Blue
        TagPillStyle(background: Color(hex: 0x5C7CFA), foreground: Color(hex: 0xFFFFFF)), // 8 Indigo
        TagPillStyle(background: Color(hex: 0x845EF7), foreground: Color(hex: 0xFFFFFF)), // 9 Violet
        TagPillStyle(background: Color(hex: 0xBE4BDB), foreground: Color(hex: 0xFFFFFF)), // 10 Magenta
        TagPillStyle(background: Color(hex: 0xF06595), foreground: Color(hex: 0xFFFFFF)), // 11 Pink
        TagPillStyle(background: Color(hex: 0xA47148), foreground: Color(hex: 0xFFFFFF)), // 12 Brown
        TagPillStyle(background: Color(hex: 0x868E96), foreground: Color(hex: 0xFFFFFF)), // 13 Gray
        TagPillStyle(background: Color(hex: 0x343A40), foreground: Color(hex: 0xFFFFFF)), // 14 Dark Gray
        TagPillStyle(background: Color(hex: 0x15AABF), foreground: Color(hex: 0xFFFFFF)), // 15 Cyan
    ]

    /// Returns the complete style (background + foreground) for a tag
    static func style(for tag: String) -> TagPillStyle {
        let hash = fnv1a32(tag)
        let index = Int(hash % UInt32(styles.count))
        return styles[index]
    }

    /// Returns just the background color for a tag (convenience accessor)
    static func color(for tag: String) -> Color {
        style(for: tag).background
    }

    private static func fnv1a32(_ string: String) -> UInt32 {
        let fnvPrime: UInt32 = 16777619
        let fnvOffset: UInt32 = 2166136261

        var hash = fnvOffset
        for byte in string.utf8 {
            hash ^= UInt32(byte)
            hash = hash &* fnvPrime
        }
        return hash
    }
}

private extension Color {
    init(hex: UInt32) {
        let red = Double((hex >> 16) & 0xFF) / 255.0
        let green = Double((hex >> 8) & 0xFF) / 255.0
        let blue = Double(hex & 0xFF) / 255.0
        self.init(red: red, green: green, blue: blue)
    }
}
