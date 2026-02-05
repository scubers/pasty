import SwiftUI

/// Design color system matching HTML UI mockup (ui-mock-v5.html)
enum DesignColors {
    static var isDarkMode: Bool {
        #if os(macOS)
        let appearance = NSApp.effectiveAppearance.name
        if appearance.rawValue.contains("Dark") {
            return true
        }
        #endif
        return false
    }

    // MARK: - Background Colors

    /// Primary background color (light: #f5f5f7, dark: #0b0b0d)
    static var bg0: Color {
        isDarkMode ? Color(red: 0.043, green: 0.043, blue: 0.051) : Color(red: 0.961, green: 0.961, blue: 0.969)
    }

    /// Glass material layer 1 (light: rgba(255,255,255,0.62), dark: rgba(28,28,30,0.58))
    static var mat1: Color {
        if isDarkMode {
            Color(red: 0.110, green: 0.110, blue: 0.118, opacity: 0.58)
        } else {
            Color(red: 1.0, green: 1.0, blue: 1.0, opacity: 0.62)
        }
    }

    /// Glass material layer 2 (light: rgba(255,255,255,0.40), dark: rgba(28,28,30,0.40))
    static var mat2: Color {
        if isDarkMode {
            Color(red: 0.110, green: 0.110, blue: 0.118, opacity: 0.40)
        } else {
            Color(red: 1.0, green: 1.0, blue: 1.0, opacity: 0.40)
        }
    }

    // MARK: - Text Colors

    /// Primary text color (light: rgba(0,0,0,0.90), dark: rgba(255,255,255,0.92))
    static var text0: Color {
        isDarkMode ? Color(red: 1.0, green: 1.0, blue: 1.0, opacity: 0.92) : Color(red: 0, green: 0, blue: 0, opacity: 0.90)
    }

    /// Secondary text color (light: rgba(0,0,0,0.60), dark: rgba(255,255,255,0.56))
    static var text1: Color {
        isDarkMode ? Color(red: 1.0, green: 1.0, blue: 1.0, opacity: 0.56) : Color(red: 0, green: 0, blue: 0, opacity: 0.60)
    }

    /// Tertiary text color (light: rgba(0,0,0,0.42), dark: rgba(255,255,255,0.38))
    static var text2: Color {
        isDarkMode ? Color(red: 1.0, green: 1.0, blue: 1.0, opacity: 0.38) : Color(red: 0, green: 0, blue: 0, opacity: 0.42)
    }

    // MARK: - Stroke and Border Colors

    /// Stroke/border color (light: rgba(0,0,0,0.10), dark: rgba(255,255,255,0.12))
    static var stroke: Color {
        isDarkMode ? Color(red: 1.0, green: 1.0, blue: 1.0, opacity: 0.12) : Color(red: 0, green: 0, blue: 0, opacity: 0.10)
    }

    // MARK: - Accent Colors

    /// Accent blue color (#0A84FF)
    static var accent: Color {
        Color(red: 0.039, green: 0.518, blue: 1.0)
    }

    // MARK: - State Colors

    /// Pill button background (light: rgba(0,0,0,0.06), dark: rgba(255,255,255,0.08))
    static var pill: Color {
        isDarkMode ? Color(red: 1.0, green: 1.0, blue: 1.0, opacity: 0.08) : Color(red: 0, green: 0, blue: 0, opacity: 0.06)
    }

    /// Selected state background (light: rgba(10,132,255,0.16), dark: rgba(10,132,255,0.22))
    static var selected: Color {
        if isDarkMode {
            Color(red: 0.039, green: 0.518, blue: 1.0, opacity: 0.22)
        } else {
            Color(red: 0.039, green: 0.518, blue: 1.0, opacity: 0.16)
        }
    }

    /// Hover state background (light: rgba(10,132,255,0.08), dark: rgba(10,132,255,0.12))
    static var hover: Color {
        if isDarkMode {
            Color(red: 0.039, green: 0.518, blue: 1.0, opacity: 0.12)
        } else {
            Color(red: 0.039, green: 0.518, blue: 1.0, opacity: 0.08)
        }
    }

    /// Pin color (light: rgba(255,204,0,0.92), dark: rgba(255,214,10,0.96))
    static var pin: Color {
        isDarkMode ? Color(red: 1.0, green: 0.839, blue: 0.039, opacity: 0.96) : Color(red: 1.0, green: 0.8, blue: 0, opacity: 0.92)
    }

    /// Icon color (light: rgba(0,0,0,0.58), dark: rgba(255,255,255,0.62))
    static var icon: Color {
        isDarkMode ? Color(red: 1.0, green: 1.0, blue: 1.0, opacity: 0.62) : Color(red: 0, green: 0, blue: 0, opacity: 0.58)
    }
}

extension NSColor {
    enum DesignColors {
        static var isDarkMode: Bool {
            #if os(macOS)
            let appearance = NSApp.effectiveAppearance.name
            if appearance.rawValue.contains("Dark") {
                return true
            }
            #endif
            return false
        }

        static var bg0: NSColor {
            isDarkMode ? NSColor(red: 0.043, green: 0.043, blue: 0.051, alpha: 1.0) : NSColor(red: 0.961, green: 0.961, blue: 0.969, alpha: 1.0)
        }

        static var mat1: NSColor {
            if isDarkMode {
                NSColor(red: 0.110, green: 0.110, blue: 0.118, alpha: 0.58)
            } else {
                NSColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.62)
            }
        }

        static var mat2: NSColor {
            if isDarkMode {
                NSColor(red: 0.110, green: 0.110, blue: 0.118, alpha: 0.40)
            } else {
                NSColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.40)
            }
        }

        static var text0: NSColor {
            isDarkMode ? NSColor(white: 1.0, alpha: 0.92) : NSColor(white: 0.0, alpha: 0.90)
        }

        static var text1: NSColor {
            isDarkMode ? NSColor(white: 1.0, alpha: 0.56) : NSColor(white: 0.0, alpha: 0.60)
        }

        static var text2: NSColor {
            isDarkMode ? NSColor(white: 1.0, alpha: 0.38) : NSColor(white: 0.0, alpha: 0.42)
        }

        static var stroke: NSColor {
            isDarkMode ? NSColor(white: 1.0, alpha: 0.12) : NSColor(white: 0.0, alpha: 0.10)
        }

        static var accent: NSColor {
            NSColor(red: 0.039, green: 0.518, blue: 1.0, alpha: 1.0)
        }

        static var selected: NSColor {
            if isDarkMode {
                NSColor(red: 0.039, green: 0.518, blue: 1.0, alpha: 0.22)
            } else {
                NSColor(red: 0.039, green: 0.518, blue: 1.0, alpha: 0.16)
            }
        }

        static var hover: NSColor {
            if isDarkMode {
                NSColor(red: 0.039, green: 0.518, blue: 1.0, alpha: 0.12)
            } else {
                NSColor(red: 0.039, green: 0.518, blue: 1.0, alpha: 0.08)
            }
        }

        static var pin: NSColor {
            if isDarkMode {
                NSColor(red: 1.0, green: 0.839, blue: 0.039, alpha: 0.96)
            } else {
                NSColor(red: 1.0, green: 0.8, blue: 0, alpha: 0.92)
            }
        }

        static var icon: NSColor {
            isDarkMode ? NSColor(white: 1.0, alpha: 0.62) : NSColor(white: 0.0, alpha: 0.58)
        }
    }
}
