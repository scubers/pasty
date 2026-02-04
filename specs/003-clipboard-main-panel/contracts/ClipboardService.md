# ClipboardService Contract

**Type**: Internal Service Contract
**Version**: 1.0.0
**Language**: Swift 5.9+

## Overview

`ClipboardService` provides read-only access to clipboard history database (managed by Rust layer in feature 002). This service abstracts database queries and maps Rust data models to Swift UI models.

### MVVM Layer Positioning

```
ViewModel (observes @Published state)
         ↓ calls Service methods
Service (stateless, returns data)
         ↓ accesses
Database (SQLite)
```

**Service Layer Rules** (enforced during implementation):
- ✅ **Stateless**: No @Published properties, no internal state
- ✅ **Pure functions**: Same input → same output (except I/O)
- ✅ **Combine publishers**: Return `AnyPublisher<T, Error>` for async operations
- ✅ **async/await**: Alternative to Combine for simple operations
- ❌ NO UI dependencies (don't import SwiftUI)
- ❌ NO @Published properties (that's ViewModel's job)
- ❌ NO view lifecycle code

**Data Flow**:
```
ViewModel: "Load entries for me"
    ↓
Service: Query database → Return Publisher<[Entry], Error>
    ↓
ViewModel: Subscribe to publisher → Update @Published entries
    ↓
View: Automatically re-renders when entries change
```

---

## Public Interface

```swift
// Service protocol (stateless, no @Published properties)
protocol ClipboardServiceProtocol {
    /// Load clipboard entries from database with pagination
    /// - Parameters:
    ///   - limit: Maximum number of entries to return (default: 100)
    ///   - offset: Number of entries to skip (for pagination, default: 0)
    /// - Returns: Publisher that emits array of entries or error
    func loadEntries(limit: Int, offset: Int) -> AnyPublisher<[ClipboardEntry], ClipboardServiceError>

    /// Load a single clipboard entry by ID
    /// - Parameter id: Entry UUID
    /// - Returns: Publisher that emits entry or error
    func loadEntry(id: String) -> AnyPublisher<ClipboardEntry, ClipboardServiceError>

    /// Copy entry content to system clipboard
    /// - Parameter id: Entry UUID
    /// - Returns: Publisher that completes on success or emits error
    func copyToClipboard(id: String) -> AnyPublisher<Void, ClipboardServiceError>

    /// Copy entry and paste into active application
    /// - Parameter id: Entry UUID
    /// - Returns: Publisher that completes on success or emits error
    func copyAndPaste(id: String) -> AnyPublisher<Void, ClipboardServiceError>

    /// Delete entry from database
    /// - Parameter id: Entry UUID
    /// - Returns: Publisher that completes on success or emits error
    func deleteEntry(id: String) -> AnyPublisher<Void, ClipboardServiceError>

    /// Delete multiple entries
    /// - Parameter ids: Array of entry UUIDs
    /// - Returns: Publisher that completes on success or emits error
    func deleteEntries(ids: [String]) -> AnyPublisher<Void, ClipboardServiceError>

    /// Toggle pinned status of an entry
    /// - Parameters:
    ///   - id: Entry UUID
    ///   - pinned: New pinned state
    /// - Returns: Publisher that completes on success or emits error
    func setPinned(id: String, pinned: Bool) -> AnyPublisher<Void, ClipboardServiceError>

    /// Encrypt a sensitive entry
    /// - Parameter id: Entry UUID
    /// - Returns: Publisher that emits (encryptedData, keyId) or error
    func encryptEntry(id: String) -> AnyPublisher<(Data, String), ClipboardServiceError>

    /// Decrypt an encrypted entry
    /// - Parameters:
    ///   - encryptedData: Encrypted content
    ///   - keyId: Key identifier for Keychain lookup
    /// - Returns: Publisher that emits decrypted content or error
    func decryptEntry(encryptedData: Data, keyId: String) -> AnyPublisher<Data, ClipboardServiceError>
}
```

### Usage Example in ViewModel

```swift
@MainActor
class ClipboardListViewModel: ObservableObject {
    @Published var entries: [ClipboardEntryListItem] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private let clipboardService: ClipboardServiceProtocol
    private var cancellables = Set<AnyCancellable>()

    init(clipboardService: ClipboardServiceProtocol) {
        self.clipboardService = clipboardService
    }

    func loadEntries() {
        isLoading = true
        errorMessage = nil

        // Service returns Publisher, ViewModel subscribes and updates state
        clipboardService.loadEntries(limit: 100, offset: 0)
            .receive(on: DispatchQueue.main)  // Ensure UI updates on main thread
            .sink { [weak self] completion in
                self?.isLoading = false
                if case .failure(let error) = completion {
                    self?.errorMessage = error.localizedDescription
                }
            } receiveValue: { [weak self] entries in
                // Update @Published property → View automatically re-renders
                self?.entries = entries.map { ClipboardEntryListItem(from: $0) }
            }
            .store(in: &cancellables)  // Keep subscription alive
    }
}
```

**Key Points**:
- Service methods return `AnyPublisher<T, Error>` (Combine framework)
- ViewModel uses `.sink` to subscribe and update `@Published` properties
- UI automatically updates when `@Published` properties change (data-driven)
- Service has NO internal state (stateless)
- Service has NO `@Published` properties (that's ViewModel's job)

## Data Types

```swift
// Database models (mirroring Rust schema)
struct ClipboardEntry {
    let id: String
    let content: Data  // Encrypted or plaintext
    let contentType: ContentType
    let timestamp: Date
    let sourceApp: String
    let isPinned: Bool
    let pinnedTimestamp: Date?
    let sensitiveType: String?
    let isEncrypted: Bool
}

enum ContentType: String, Codable {
    case text
    case image
}

// UI models
struct ClipboardEntryListItem: Identifiable, Equatable {
    let id: String
    let title: String
    let preview: PreviewKind
    let timestamp: String  // Formatted
    let sourceApp: String
    let sourceIcon: NSImage
    let contentType: ContentType
    let isPinned: Bool
    let isSelected: Bool
    let isSensitive: Bool
}

enum PreviewKind: Equatable {
    case text(String)
    case image(NSImage)
}

// Errors
enum ClipboardServiceError: LocalizedError {
    case databaseError(underlying: Error)
    case notFound(entryId: String)
    case clipboardAccessDenied
    case encryptionError(underlying: Error)
    case invalidData(reason: String)

    var errorDescription: String? {
        switch self {
        case .databaseError(let err): return "Database error: \(err.localizedDescription)"
        case .notFound(let id): return "Entry not found: \(id)"
        case .clipboardAccessDenied: return "Clipboard access denied"
        case .encryptionError(let err): return "Encryption error: \(err.localizedDescription)"
        case .invalidData(let reason): return "Invalid data: \(reason)"
        }
    }
}
```

## Implementation Requirements

### Database Access
- Use SQLite.swift wrapper for type-safe queries
- Open database in read-only mode (writes happen via Rust layer)
- Handle database locks with retry logic (max 3 retries, 100ms backoff)
- Use WAL mode for concurrent read access

### Performance
- `loadEntries`: Must return within 500ms for 100 entries
- Implement pagination: Load in chunks of 100
- Cache queries: Avoid reloading recent entries
- Background queue: All queries on `Task.detached(priority: .userInitiated)`

### Security
- Never log clipboard content (only entry IDs and metadata)
- Use macOS Keychain for encryption key storage (via `EncryptionService`)
- Respect `is_encrypted` flag, decrypt on-demand
- Clear sensitive data from memory after use (set to nil)

### Thread Safety
- All public methods marked `@MainActor`
- Internal database queries run on background queue
- Ensure all `@Published` properties updated on main actor

## Testing Contract

### Unit Tests
```swift
final class ClipboardServiceTests: XCTestCase {
    func testLoadEntries_Pagination()
    func testLoadEntries_EmptyDatabase()
    func testLoadEntry_NotFound()
    func testLoadEntry_Success()
    func testCopyToClipboard_Success()
    func testDeleteEntry_Success()
    func testSetPinned_True()
    func testSetPinned_False()
}
```

### Integration Tests
- Use test database with fixture data
- Verify SQL query correctness
- Test concurrent read access (multiple services)
- Validate database lock retry behavior

### Performance Tests
```swift
func testLoadEntries_Performance() {
    measure {
        // Load 1000 entries in chunks of 100
        // Must complete within 1 second total
    }
}
```

## Dependencies

- **SQLite.swift**: `>=0.14.0` (database wrapper)
- **Feature 002 Rust layer**: Clipboard history database schema
- **macOS Security framework**: For encryption key storage (via EncryptionService)
- **AppKit**: NSPasteboard for clipboard operations

## Open Questions

None - contract fully specified.
