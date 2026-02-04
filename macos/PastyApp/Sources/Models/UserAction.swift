import Foundation

/// User actions that can be performed on clipboard entries
enum UserAction {
    /// Load all entries from database
    case loadEntries

    /// Select a specific entry
    case selectEntry(id: String)

    /// Copy selected entry to clipboard
    case copyEntry(id: String)

    /// Paste selected entry (copy + paste)
    case pasteEntry(id: String)

    /// Delete a single entry
    case deleteEntry(id: String)

    /// Delete multiple entries
    case deleteEntries(ids: [String])

    /// Toggle pin state for an entry
    case togglePin(id: String)

    /// Search entries with query text
    case search(query: String)

    /// Change content filter
    case filter(ContentFilter)

    /// Toggle pinned filter
    case togglePinnedFilter

    /// Load more entries (pagination)
    case loadMoreEntries
}
