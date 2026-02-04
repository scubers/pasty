# SearchService Contract

**Type**: Internal Service Contract
**Version**: 1.0.0
**Language**: Swift 5.9+

## Overview

`SearchService` provides in-memory search and filtering functionality for clipboard entries. Implements debounced search with background execution.

## Public Interface

```swift
@MainActor
protocol SearchServiceProtocol {
    /// Search entries by text query
    /// - Parameters:
    ///   - entries: Array of clipboard entries to search
    ///   - query: Search query string (case-insensitive)
    /// - Returns: Filtered array of matching entries
    func search(entries: [ClipboardEntryListItem], query: String) -> [ClipboardEntryListItem]

    /// Filter entries by content type
    /// - Parameters:
    ///   - entries: Array of clipboard entries
    ///   - filter: Content filter (.all, .text, .images)
    /// - Returns: Filtered array
    func filterByContentType(entries: [ClipboardEntryListItem], filter: ContentFilter) -> [ClipboardEntryListItem]

    /// Filter entries by pinned status
    /// - Parameters:
    ///   - entries: Array of clipboard entries
    ///   - pinnedOnly: If true, return only pinned entries
    /// - Returns: Filtered array
    func filterByPinned(entries: [ClipboardEntryListItem], pinnedOnly: Bool) -> [ClipboardEntryListItem]

    /// Combine all filters (search + content type + pinned)
    /// - Parameters:
    ///   - entries: Array of clipboard entries
    ///   - searchText: Search query
    ///   - contentFilter: Content type filter
    ///   - pinnedOnly: Pinned filter toggle
    /// - Returns: Filtered and sorted array
    func applyFilters(
        entries: [ClipboardEntryListItem],
        searchText: String,
        contentFilter: ContentFilter,
        pinnedOnly: Bool
    ) -> [ClipboardEntryListItem]
}
```

## Data Types

```swift
enum ContentFilter: String, CaseIterable {
    case all = "All"
    case text = "Text"
    case images = "Images"
}
```

## Implementation Requirements

### Search Algorithm
```swift
func search(entries: [ClipboardEntryListItem], query: String) -> [ClipboardEntryListItem] {
    guard !query.isEmpty else { return entries }

    return entries.filter { entry in
        // Search in title (first 50 chars)
        if entry.title.localizedCaseInsensitiveContains(query) {
            return true
        }

        // Search in full text content (if text type)
        if case .text(let text) = entry.preview {
            return text.localizedCaseInsensitiveContains(query)
        }

        return false
    }
}
```

### Performance Requirements
- Search 1000 entries within 300ms
- Case-insensitive matching
- Empty query returns all entries (no filtering)
- Max query length: 200 characters (enforced at UI layer)

### Debouncing Strategy
```swift
class Debouncer {
    private var task: Task<Void, Never>?

    func debounce(delay: Duration, operation: @escaping () async -> Void) {
        task?.cancel()
        task = Task {
            try? await Task.sleep(for: delay)
            await operation()
        }
    }
}

// Usage in MainPanelState:
@Published var searchText: String = "" {
    didSet {
        Debouncer().debounce(delay: .milliseconds(300)) {
            self.updateFilters()
        }
    }
}
```

### Sorting Requirements
From spec FR-028: Pinned entries must appear at top:
```swift
func applyFilters(/* ... */) -> [ClipboardEntryListItem] {
    var filtered = entries

    // Apply filters
    if !searchText.isEmpty {
        filtered = search(entries: filtered, query: searchText)
    }
    filtered = filterByContentType(entries: filtered, filter: contentFilter)
    filtered = filterByPinned(entries: filtered, pinnedOnly: pinnedOnly)

    // Sort: pinned first, then reverse chronological
    filtered.sort { lhs, rhs in
        if lhs.isPinned && !rhs.isPinned { return true }
        if !lhs.isPinned && rhs.isPinned { return false }
        return lhs.id > rhs.id  // UUIDs are time-ordered, so reverse = newest first
    }

    return filtered
}
```

## Testing Contract

### Unit Tests
```swift
final class SearchServiceTests: XCTestCase {
    func testSearch_EmptyQuery_ReturnsAll()
    func testSearch_MatchingText_ReturnsResults()
    func testSearch_NonMatchingText_ReturnsEmpty()
    func testSearch_CaseInsensitive()
    func testSearch_ImageEntries_NotSearched()
    func testFilterByContentType_All()
    func testFilterByContentType_TextOnly()
    func testFilterByContentType_ImagesOnly()
    func testFilterByPinned_PinnedOnly()
    func testFilterByPinned_All()
    func testApplyFilters_CombinesAllFilters()
    func testApplyFilters_PinnedEntriesAtTop()
}
```

### Performance Tests
```swift
func testSearchPerformance_1000Entries() {
    let entries = generateClipboardEntries(count: 1000)
    measure {
        _ = searchService.search(entries: entries, query: "test")
    }
    // Must complete within 300ms
}
```

## Dependencies

- None (pure Swift, in-memory operations)

## Integration Points

- **MainPanelState**: Consumes SearchService to update `filteredEntries`
- **SearchBar UI**: Debounces input, triggers search on 300ms delay
- **FilterButtons**: Trigger `filterByContentType` and `filterByPinned`

## Edge Cases

1. **Empty query**: Return all entries (no filtering)
2. **Special characters**: Support regex special chars (no pattern matching, literal search only)
3. **Unicode/Emoji**: Use `localizedCaseInsensitiveContains` for proper Unicode handling
4. **Very long query**: Truncate to 200 chars (enforced at UI layer)
5. **All entries filtered out**: Return empty array, UI shows "no results found" message

## Open Questions

None - contract fully specified.
