import SwiftUI

enum MainPanelTokens {
    enum Colors {
        /// Main panel background gradient from the design spec.
        static let backgroundGradient = LinearGradient(
            colors: [Color(hex: 0x1A1A2E), Color(hex: 0x16213E), Color(hex: 0x0F0F23)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        /// Main panel surface overlay used by the root container.
        static let surface = Color(red: 30.0 / 255.0, green: 30.0 / 255.0, blue: 46.0 / 255.0, opacity: 0.3)
        /// Card-level glass layer for sections.
        static let card = Color.white.opacity(0.03)
        /// Light border used for dividers and section outlines.
        static let border = Color.white.opacity(0.10)
        /// Primary text color for title-level content.
        static let textPrimary = Color(hex: 0xE5E7EB)
        /// Secondary text color for metadata and helper labels.
        static let textSecondary = Color(hex: 0x9CA3AF)
        /// Muted text color for low-emphasis hints and footer labels.
        static let textMuted = Color(hex: 0x6B7280)
        /// Accent color for focus ring, selected markers, and emphasis.
        static let accentPrimary = Color(hex: 0x2DD4BF)
        /// Primary button gradient used for main action buttons.
        static let accentGradient = LinearGradient(
            colors: [Color(hex: 0x0D9488), Color(hex: 0x14B8A6)],
            startPoint: .leading,
            endPoint: .trailing
        )
        static let keyword = Color(hex: 0xC084FC)
        static let string = Color(hex: 0x4ADE80)
        static let function = Color(hex: 0xFDE047)
    }

    enum Typography {
        /// Standard body text for list and metadata rows.
        static let body = Font.system(size: 13, weight: .regular, design: .default)
        /// Emphasized body text for active titles.
        static let bodyBold = Font.system(size: 13, weight: .medium, design: .default)
        /// Small text for timestamps and supporting metadata.
        static let small = Font.system(size: 11, weight: .regular, design: .default)
        /// Small uppercase section labels.
        static let smallBold = Font.system(size: 11, weight: .semibold, design: .default)
        /// Monospaced content font for snippet preview.
        static let code = Font.system(size: 12, weight: .regular, design: .monospaced)
    }

    enum Effects {
        /// Material for panel-level glass background in AppKit.
        static let materialHudWindow = NSVisualEffectView.Material.hudWindow
        /// Material for thin SwiftUI cards and sections.
        static let materialUltraThin = Material.ultraThin
        /// Material for regular SwiftUI sections.
        static let materialRegular = Material.regular
        /// Panel-level shadow from design spec.
        static let panelShadow = ShadowToken(color: .black.opacity(0.4), radius: 32, x: 0, y: 8)
        /// Primary button shadow from design spec.
        static let buttonShadow = ShadowToken(color: Color(hex: 0x0D9488).opacity(0.4), radius: 8, x: 0, y: 2)
    }

    enum Layout {
        /// Base corner radius for cards and sections.
        static let cornerRadius: CGFloat = 12
        /// Small corner radius for list row containers.
        static let cornerRadiusSmall: CGFloat = 8
        /// Default container padding.
        static let padding: CGFloat = 16
        /// Compact spacing used inside list rows and metadata groups.
        static let paddingCompact: CGFloat = 8
        /// Split ratio for main content area: list / preview.
        static let splitRatio: CGFloat = 0.45
    }
}

struct ShadowToken {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}

private extension Color {
    init(hex: UInt32) {
        let red = Double((hex >> 16) & 0xFF) / 255.0
        let green = Double((hex >> 8) & 0xFF) / 255.0
        let blue = Double(hex & 0xFF) / 255.0
        self.init(red: red, green: green, blue: blue)
    }
}
