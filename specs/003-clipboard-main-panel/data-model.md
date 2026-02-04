# Data Model: Clipboard Main Panel UI

**Feature**: 003-clipboard-main-panel
**Date**: 2026-02-04
**Status**: Complete

## Overview

This document defines the **Model layer** for the clipboard main panel UI feature following **strict MVVM architecture**. The Model layer contains only immutable data structures (value types) with no business logic or UI dependencies.

### MVVM Architecture Context

```
┌─────────────────────────────────────────────────┐
│  VIEW (SwiftUI)                                 │
│  - Observes ViewModel via @ObservedObject       │
│  - Renders UI based on data state               │
│  - Sends user actions to ViewModel              │
└────────────────┬────────────────────────────────┘
                 │ User Actions
                 ↓
┌─────────────────────────────────────────────────┐
│  VIEWMODEL (Combine)                            │
│  - Contains @Published properties               │
│  - Handles user actions                         │
│  - Coordinates Service calls                    │
│  - Updates state (triggers UI updates)          │
└────────────────┬────────────────────────────────┘
                 │ Service Calls
                 ↓
┌─────────────────────────────────────────────────┐
│  SERVICE (Stateless)                            │
│  - Fetches/modifies data                        │
│  - Returns Combine publishers                   │
└────────────────┬────────────────────────────────┘
                 │ Data Access
                 ↓
┌─────────────────────────────────────────────────┐
│  MODEL (This Document)                          │
│  - Immutable data structs                       │
│  - Value types (no reference types)             │
│  - No logic, no state, no UI dependencies       │
└─────────────────────────────────────────────────┘
```

**Model Layer Responsibilities**:
- ✅ Define data structures (structs, enums)
- ✅ Represent domain entities (ClipboardEntry, filters, etc.)
- ✅ Provide type safety and validation
- ❌ NO business logic (that's ViewModel's job)
- ❌ NO UI code (that's View's job)
- ❌ NO @Published properties (that's ViewModel's job)
- ❌ NO Combine publishers (that's ViewModel's job)

---

## Entity Relationship Diagram

```
┌─────────────────────────┐
│  ClipboardEntry         │ (from feature 002, read-only access)
│  ─────────────────      │
│  id: String (UUID)      │
│  content: Data          │
│  content_type: Enum     │
│  timestamp: DateTime    │
│  source_app: String     │
│  is_pinned: Boolean     │
│  pinned_timestamp: DateTime? │
│  sensitive_type: String?│
│  is_encrypted: Boolean  │
└─────────────────────────┘
           │
           │ (Swift mapping layer)
           ▼
┌─────────────────────────┐
│  ClipboardEntryListItem │ (Swift UI model)
│  ─────────────────      │
│  id: String             │
│  title: String          │
│  preview: String/NSImage│
│  timestamp: String      │ (formatted "2 min ago")
│  sourceApp: String      │
│  sourceIcon: NSImage    │
│  contentType: ContentType│
│  isPinned: Bool         │
│  isSelected: Bool       │
│  isSensitive: Bool      │
└─────────────────────────┘
           │
           │ Used by
           ▼
┌─────────────────────────┐
│  MainPanelState         │ (Swift view state)
│  ─────────────────      │
│  entries: [ClipboardEntryListItem] │
│  filteredEntries: [ClipboardEntryListItem] │
│  searchText: String     │
│  contentFilter: ContentFilter │
│  selectedEntryId: String?│
│  scrollPosition: CGFloat│
│  isPinnedFilterActive: Bool │
└─────────────────────────┘
           │
           │ Manages
           ▼
┌─────────────────────────┐
│  PreviewPanel           │ (Swift view state)
│  ─────────────────      │
│  selectedEntryId: String?│
│  previewContent: PreviewContent│
│  copyButtonState: Bool  │
│  pasteButtonState: Bool │
└─────────────────────────┘
```

---

## Core Entities

### 1. ClipboardEntryListItem

**Purpose**: Lightweight UI model for displaying clipboard entries in the list view. Maps from database `ClipboardEntry` with computed properties for UI.

**Fields**:
```swift
struct ClipboardEntryListItem: Identifiable, Equatable {
    let id: String                    // UUID from database
    let title: String                 // First ~50 chars of content
    let preview: PreviewKind          // .text(String) or .image(NSImage)
    let timestamp: String             // Formatted "2 min ago", "Today at 3:45 PM"
    let sourceApp: String             // App name (e.g., "Safari", "Terminal")
    let sourceIcon: NSImage           // 16×16px app icon
    let contentType: ContentType      // .text or .image
    let isPinned: Bool                // Pinned status
    let isSelected: Bool              // Selection state (UI only)
    let isSensitive: Bool             // True if contains sensitive content
}
```

**Relationships**:
- Mapped from `ClipboardEntry` (1:1 relationship)
- Used by `MainPanelState.entries` (1:N aggregation)
- Selected by `PreviewPanel.selectedEntryId` (1:1 reference)

**Validation Rules**:
- `title`: Max 50 characters, truncated with ellipsis if longer
- `timestamp`: Cannot be empty, always formatted
- `sourceApp`: Required, defaults to "Unknown" if app metadata missing
- `contentType`: Must be .text or .image

**State Transitions**: None (immutable view model, recreated when data changes)

---

### 2. MainPanelState

**Purpose**: Observable state object managing the main panel's data and filter state.

**Fields**:
```swift
@MainActor
class MainPanelState: ObservableObject {
    // Data
    @Published var allEntries: [ClipboardEntryListItem] = []
    @Published var filteredEntries: [ClipboardEntryListItem] = []

    // Filters
    @Published var searchText: String = ""
    @Published var contentFilter: ContentFilter = .all
    @Published var isPinnedFilterActive: Bool = false

    // Selection
    @Published var selectedEntryId: String? = nil
    @Published var scrollPosition: CGFloat = 0

    // Loading state
    @Published var isLoading: Bool = false
    @Published var loadError: Error? = nil
}
```

**Enums**:
```swift
enum ContentFilter: String, CaseIterable {
    case all = "All"
    case text = "Text"
    case images = "Images"
}
```

**Relationships**:
- Contains `ClipboardEntryListItem` (1:N aggregation)
- Provides filtered entries to `ClipboardListView` (view binding)
- Selected entry ID consumed by `PreviewPanel` (1:1 reference)

**Validation Rules**:
- `searchText`: Max 200 characters (prevent abuse)
- `filteredEntries`: Always subset of `allEntries`
- `selectedEntryId`: If set, must exist in `filteredEntries`

**State Transitions**:
```
[Initial] → [Loading] → [Loaded]
              ↓            ↓
           [Error] ←─────┘

Filter changes (searchText, contentFilter, isPinnedFilterActive):
[Loaded] → [Filtering] → [Loaded]
```

**Business Logic**:
```swift
func updateFilters() {
    filteredEntries = allEntries.filter { entry in
        // Search filter
        if !searchText.isEmpty && !entry.title.localizedCaseInsensitiveContains(searchText) {
            return false
        }

        // Content type filter
        switch contentFilter {
        case .all: break
        case .text: guard entry.contentType == .text else { return false }
        case .images: guard entry.contentType == .image else { return false }
        }

        // Pinned filter
        if isPinnedFilterActive && !entry.isPinned {
            return false
        }

        return true
    }

    // Preserve pinned entries at top
    if !isPinnedFilterActive {
        filteredEntries.sort { lhs, rhs in
            if lhs.isPinned && !rhs.isPinned { return true }
            if !lhs.isPinned && rhs.isPinned { return false }
            return lhs.id > rhs.id  // Reverse chronological by ID
        }
    }
}
```

---

### 3. PreviewPanel

**Purpose**: State object managing the right preview panel content and actions.

**Fields**:
```swift
@MainActor
class PreviewPanel: ObservableObject {
    @Published var selectedEntryId: String? = nil
    @Published var previewContent: PreviewContent? = nil
    @Published var copyButtonEnabled: Bool = false
    @Published var pasteButtonEnabled: Bool = false
}
```

**Associated Types**:
```swift
enum PreviewContent {
    case text(String)
    case image(NSImage)
    case empty  // No entry selected
}
```

**Relationships**:
- Binds to `MainPanelState.selectedEntryId` (1:1 observation)
- Loads full content from `ClipboardEntry` database (read operation)

**Validation Rules**:
- `previewContent`: Nil if no entry selected
- Button states reflect entry availability (enabled when `selectedEntryId != nil`)

**State Transitions**:
```
[None Selected] → [Entry Selected] → [Content Loaded] → [Entry Selected]
                            ↓              ↓
                         [Loading]    [Load Error]
```

---

### 4. ThumbnailCache

**Purpose**: In-memory cache for image thumbnails to avoid regenerating on each render.

**Fields**:
```swift
@MainActor
class ThumbnailCache: ObservableObject {
    private var cache: [String: NSImage] = [:]
    private var maxSize: Int = 100  // Max cached thumbnails
    private var accessOrder: [String] = []  // LRU tracking

    func get(entryId: String) -> NSImage?
    func set(entryId: String, image: NSImage)
    func clear()
}
```

**Relationships**:
- Used by `ClipboardEntryListItem.preview.image` (1:N caching)
- Persists for duration of app session (not saved to disk)

**Validation Rules**:
- Max 100 cached entries (memory limit)
- LRU eviction when limit exceeded

**State Transitions**:
```
[Cache Miss] → [Generate Thumbnail] → [Cache Hit] → [LRU Eviction]
                              ↓
                         [Cache Store]
```

---

### 5. EncryptionService

**Purpose**: Manages encryption/decryption of sensitive clipboard entries.

**Fields**:
```swift
@MainActor
class EncryptionService {
    func encryptEntry(_ entry: ClipboardEntry) throws -> (encryptedData: Data, keyId: String)
    func decryptEntry(encryptedData: Data, keyId: String) throws -> Data
    func isEntryEncrypted(_ entry: ClipboardEntry) -> Bool
}
```

**Relationships**:
- Stores encryption keys in macOS Keychain (1:N key management)
- Operates on `ClipboardEntry.content` (transformation)

**Validation Rules**:
- Keys stored in Keychain with access control (kSecAttrAccessibleWhenUnlocked)
- 256-bit AES encryption (default)
- Throws if key not found in Keychain

---

### 6. SearchService

**Purpose**: Performs search queries on clipboard entries.

**Fields**:
```swift
@MainActor
class SearchService {
    func search(entries: [ClipboardEntryListItem], query: String) -> [ClipboardEntryListItem]
}
```

**Relationships**:
- Consumes `ClipboardEntryListItem` array (read-only)
- Returns filtered array (transformation)

**Validation Rules**:
- Case-insensitive search
- Searches in `title` and `content` fields
- Empty query returns all entries
- Max 200 character query length

---

## Database Schema (from Feature 002)

The Swift layer reads from this existing schema:

```sql
CREATE TABLE clipboard_entries (
    id TEXT PRIMARY KEY,              -- UUID
    content BLOB NOT NULL,            -- Encrypted or plaintext data
    content_type TEXT NOT NULL,       -- 'text' or 'image'
    timestamp INTEGER NOT NULL,       -- Unix timestamp (milliseconds)
    source_app TEXT NOT NULL,         -- Bundle identifier
    is_pinned INTEGER DEFAULT 0,      -- 0 or 1
    pinned_timestamp INTEGER,         -- Unix timestamp, nullable
    sensitive_type TEXT,              -- Pattern name if sensitive, nullable
    is_encrypted INTEGER DEFAULT 0    -- 0 or 1
);

CREATE INDEX idx_timestamp ON clipboard_entries(timestamp DESC);
CREATE INDEX idx_pinned ON clipboard_entries(is_pinned, pinned_timestamp DESC);
```

**Access Pattern**: Read-only queries from Swift layer:
```sql
-- Load entries with pagination
SELECT * FROM clipboard_entries
ORDER BY
    CASE WHEN is_pinned = 1 THEN 0 ELSE 1 END,  -- Pinned first
    timestamp DESC
LIMIT 100 OFFSET ?;

-- Get single entry by ID
SELECT * FROM clipboard_entries WHERE id = ?;

-- Search (text content only)
SELECT * FROM clipboard_entries
WHERE content_type = 'text'
  AND content LIKE ?
ORDER BY timestamp DESC
LIMIT 100;
```

---

## Data Flow Diagrams

### 1. Initial Load Flow

```
[App Launch]
    ↓
[MainPanelState.init]
    ↓
[ClipboardService.loadEntries()]
    ↓
[SQLite Query] → [ClipboardEntry] (Rust schema)
    ↓
[Map to ClipboardEntryListItem]
    ↓
[Apply filters (empty initially)]
    ↓
[Populate filteredEntries]
    ↓
[UI Renders ClipboardListView]
```

### 2. Search Flow

```
[User types in search box]
    ↓
[Debounce 300ms]
    ↓
[SearchService.search()]
    ↓
[Filter allEntries by searchText]
    ↓
[Update filteredEntries]
    ↓
[UI re-renders with filtered list]
```

### 3. Entry Selection Flow

```
[User clicks entry in list]
    ↓
[MainPanelState.selectedEntryId = entry.id]
    ↓
[PreviewPanel observes selection]
    ↓
[ClipboardService.loadFullContent(entryId)]
    ↓
[Decrypt if encrypted (EncryptionService)]
    ↓
[Update PreviewPanel.previewContent]
    ↓
[UI renders preview in right panel]
```

### 4. Copy Action Flow

```
[User clicks Copy button]
    ↓
[PreviewPanel.selectedEntryId used]
    ↓
[ClipboardService.copyToClipboard(entryId)]
    ↓
[Load full content from DB]
    ↓
[Decrypt if encrypted]
    ↓
[NSPasteboard.general.setContent()]
    ↓
[Show success notification]
```

---

## Performance Considerations

### Pagination Strategy
- Load entries in chunks of 100
- Pre-load next chunk when scrolling to 80% of current chunk
- Keep maximum 1000 entries in memory (app-level cache)

### Caching Strategy
- ThumbnailCache: In-memory LRU cache (max 100 images)
- AppIconCache: Persistent cache to disk (~500 icons, ~2MB)
- Avoid reloading from database on repeated access

### Memory Usage Estimates
- 1000 entries × 500 bytes/entry = ~500KB (text data)
- 100 thumbnails × 50KB = ~5MB (image cache)
- 100 app icons × 20KB = ~2MB (icon cache)
- **Total**: ~8MB RAM (well within limits)

---

## Concurrency Model

- **Main Actor**: All `@Published` state updates must happen on `@MainActor`
- **Background Queue**: Database queries run on background queue via `Task.detached`
- **Actor Isolation**: `ClipboardService`, `SearchService` marked as `@MainActor` for UI thread safety

```swift
@MainActor
class ClipboardService {
    func loadEntries() async throws {
        let entries = await Task.detached(priority: .userInitiated) {
            // Database query on background thread
            return try await database.query(...)
        }.value

        // Update UI state on main actor
        self.allEntries = entries.map { mapToListItem($0) }
    }
}
```

---

## Security Model

### Sensitive Content Handling
1. **Detection**: Pattern matching on clipboard insert (feature 002)
2. **Storage**: `sensitive_type` column stores matched pattern name
3. **UI**: Warning icon displayed for `isSensitive == true`
4. **Encryption**: Optional per-entry encryption via `EncryptionService`
5. **Keys**: Stored in macOS Keychain with `kSecAttrAccessibleWhenUnlocked`

### Data Protection
- Database file permissions: User read/write only
- Encryption keys: Never logged (FR-078)
- Clipboard content: Cleared from NSPasteboard after 60 seconds (macOS default)

---

## Migration Strategy

This feature builds on feature 002's database schema. No migration needed for initial implementation. Future migrations will be handled by Rust layer (feature 002) with Swift layer adapting to schema changes.

---

## Testing Considerations

### Unit Tests
- `MainPanelState.filterLogic`: Verify filter combinations
- `SearchService`: Test search patterns (empty, case-insensitive, partial match)
- `EncryptionService`: Mock Keychain, verify encrypt/decrypt

### Integration Tests
- Database queries: Use test database fixture
- End-to-end: Load → Search → Select → Copy flow

### Snapshot Tests
- `ClipboardListItemView`: Verify visual regression
- `PreviewPanel`: Test text/image preview rendering

---

## Next Steps

1. Generate service contracts (contracts/)
2. Create quickstart guide (quickstart.md)
3. Run `/speckit.tasks` to generate implementation task breakdown
