import Foundation

extension Date {
    /// Format date as relative time ago (e.g., "2 min ago", "Today at 3:45 PM")
    func formatAsTimeAgo() -> String {
        let now = Date()
        let interval = now.timeIntervalSince(self)

        if interval < 60 {
            return "just now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return minutes == 1 ? "1 min ago" : "\(minutes) mins ago"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return hours == 1 ? "1 hour ago" : "\(hours) hours ago"
        } else if interval < 604800 {
            let days = Int(interval / 86400)
            return days == 1 ? "yesterday" : "\(days) days ago"
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            return formatter.string(from: self)
        }
    }

    /// Format date as date and time
    func formatAsDateTime() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: self)
    }
}
