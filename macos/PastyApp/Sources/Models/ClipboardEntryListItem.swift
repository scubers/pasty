import Foundation
import AppKit

/// Lightweight UI model for displaying clipboard entries in the list view
/// Maps from database ClipboardEntry with computed properties for UI
struct ClipboardEntryListItem: Identifiable, Equatable {
    // MARK: - Properties

    /// UUID from database
    let id: String

    /// First ~50 chars of content
    let title: String

    /// Preview kind for display
    let preview: PreviewKind

    /// Formatted timestamp (e.g., "2 min ago", "Today at 3:45 PM")
    let timestamp: String

    /// App name (e.g., "Safari", "Terminal")
    let sourceApp: String

    /// 16x16px app icon
    let sourceIcon: NSImage?

    /// Content type
    let contentType: ContentType

    /// Pinned status
    let isPinned: Bool

    /// Selection state (UI only)
    let isSelected: Bool

    /// True if contains sensitive content
    let isSensitive: Bool

    /// Timestamp for sorting
    let sortTimestamp: Date

    /// Pinned timestamp (if pinned)
    let pinnedTimestamp: Date?

    // MARK: - Types

    enum PreviewKind: Equatable {
        case text(String)
        case image(NSImage?)

        static func == (lhs: PreviewKind, rhs: PreviewKind) -> Bool {
            switch (lhs, rhs) {
            case (.text(let lText), .text(let rText)):
                return lText == rText
            case (.image, .image):
                return true // NSImage doesn't conform to Equatable, compare by reference
            default:
                return false
            }
        }
    }

    // MARK: - Initialization

    /// Initialize from a ClipboardEntry database model
    init(from entry: ClipboardEntry, isSelected: Bool = false) {
        self.id = entry.id
        self.isSelected = isSelected
        self.isPinned = false // Will be updated from database
        self.pinnedTimestamp = nil
        self.sortTimestamp = entry.latestCopyTime

        // Detect sensitive content
        self.isSensitive = SensitiveContentDetector.isSensitive(entry)

        // Extract content type
        self.contentType = entry.contentType

        // Extract title from content
        switch entry.content {
        case .text(let text):
            var titleText = String(text.prefix(50))
            if text.count > 50 {
                titleText += "..."
            }
            self.title = titleText
            self.preview = .text(String(text.prefix(200)))
        case .image:
            self.title = "Image"
            // Load thumbnail asynchronously
            self.preview = .image(nil) // Will be loaded by ThumbnailCache
        }

        // Format timestamp
        self.timestamp = Self.formatTimeAgo(entry.latestCopyTime)

        // Extract source app info
        self.sourceApp = entry.source.appName.isEmpty ? "Unknown" : entry.source.appName

        // Load app icon
        self.sourceIcon = Self.loadAppIcon(bundleIdentifier: entry.source.bundleId)
    }

    /// Convenience initializer with all properties (for updating state like pinning)
    init(
        id: String,
        title: String,
        preview: PreviewKind,
        timestamp: String,
        sourceApp: String,
        sourceIcon: NSImage?,
        contentType: ContentType,
        isPinned: Bool,
        isSelected: Bool,
        isSensitive: Bool,
        sortTimestamp: Date,
        pinnedTimestamp: Date?
    ) {
        self.id = id
        self.title = title
        self.preview = preview
        self.timestamp = timestamp
        self.sourceApp = sourceApp
        self.sourceIcon = sourceIcon
        self.contentType = contentType
        self.isPinned = isPinned
        self.isSelected = isSelected
        self.isSensitive = isSensitive
        self.sortTimestamp = sortTimestamp
        self.pinnedTimestamp = pinnedTimestamp
    }

    // MARK: - Private Helpers

    private static func formatTimeAgo(_ date: Date) -> String {
        let now = Date()
        let interval = now.timeIntervalSince(date)

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
            return formatter.string(from: date)
        }
    }

    private static func loadAppIcon(bundleIdentifier: String) -> NSImage? {
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else {
            return NSImage(systemSymbolName: "app.fill", accessibilityDescription: "Application")
        }
        return NSWorkspace.shared.icon(forFile: appURL.path)
    }

    // MARK: - Equatable

    static func == (lhs: ClipboardEntryListItem, rhs: ClipboardEntryListItem) -> Bool {
        lhs.id == rhs.id &&
        lhs.title == rhs.title &&
        lhs.timestamp == rhs.timestamp &&
        lhs.sourceApp == rhs.sourceApp &&
        lhs.contentType == rhs.contentType &&
        lhs.isPinned == rhs.isPinned &&
        lhs.isSelected == rhs.isSelected
    }
}
