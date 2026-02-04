import Foundation

/// Service for searching and filtering clipboard entries
/// Stateless, pure functions - no @Published properties
@MainActor
class SearchService {
    // MARK: - Search

    /// Search entries by query string (case-insensitive)
    func search(entries: [ClipboardEntryListItem], query: String) -> [ClipboardEntryListItem] {
        guard !query.isEmpty else {
            return entries
        }

        return entries.filter { entry in
            // Search in title
            if entry.title.localizedCaseInsensitiveContains(query) {
                return true
            }

            // Search in text preview
            if case .text(let text) = entry.preview {
                return text.localizedCaseInsensitiveContains(query)
            }

            return false
        }
    }

    // MARK: - Filters

    /// Filter entries by content type
    func filterByContentType(entries: [ClipboardEntryListItem], filter: ContentFilter) -> [ClipboardEntryListItem] {
        switch filter {
        case .all:
            return entries
        case .text:
            return entries.filter { $0.contentType == .text }
        case .images:
            return entries.filter { $0.contentType == .image }
        }
    }

    /// Filter entries by pinned status
    func filterByPinned(entries: [ClipboardEntryListItem], showPinnedOnly: Bool) -> [ClipboardEntryListItem] {
        guard showPinnedOnly else {
            return entries
        }
        return entries.filter { $0.isPinned }
    }

    // MARK: - Combined Filters

    /// Apply all filters (search, content type, pinned)
    func applyFilters(
        entries: [ClipboardEntryListItem],
        searchText: String,
        contentFilter: ContentFilter,
        showPinnedOnly: Bool
    ) -> [ClipboardEntryListItem] {
        var filtered = entries

        // Apply search filter
        if !searchText.isEmpty {
            filtered = search(entries: filtered, query: searchText)
        }

        // Apply content type filter
        filtered = filterByContentType(entries: filtered, filter: contentFilter)

        // Apply pinned filter
        filtered = filterByPinned(entries: filtered, showPinnedOnly: showPinnedOnly)

        // Sort: pinned first, then by timestamp descending
        return sortEntries(filtered)
    }

    // MARK: - Sorting

    /// Sort entries with pinned first, then by timestamp descending
    func sortEntries(_ entries: [ClipboardEntryListItem]) -> [ClipboardEntryListItem] {
        entries.sorted { lhs, rhs in
            // Pinned entries always come first
            if lhs.isPinned && !rhs.isPinned {
                return true
            }
            if !lhs.isPinned && rhs.isPinned {
                return false
            }

            // Within pinned/unpinned groups, sort by pinned timestamp if available, else by copy time
            if let lhsPinned = lhs.pinnedTimestamp, let rhsPinned = rhs.pinnedTimestamp {
                return lhsPinned > rhsPinned
            } else if let lhsPinned = lhs.pinnedTimestamp {
                return true
            } else if let rhsPinned = rhs.pinnedTimestamp {
                return false
            }

            // Finally, sort by copy time descending
            return lhs.sortTimestamp > rhs.sortTimestamp
        }
    }
}
