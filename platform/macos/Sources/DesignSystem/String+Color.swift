import SwiftUI

extension String {
    func toColor() -> Color {
        switch self {
        case "blue":
            return .blue
        case "purple":
            return .purple
        case "pink":
            return .pink
        case "red":
            return .red
        case "orange":
            return .orange
        case "yellow":
            return .yellow
        case "green":
            return .green
        default:
            return Color(red: 0.176, green: 0.831, blue: 0.749)
        }
    }
}
