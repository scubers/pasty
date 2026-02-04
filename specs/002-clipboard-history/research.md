# Research: Clipboard History Manager

**Feature**: 002-clipboard-history
**Date**: 2026-02-04
**Status**: Complete

## Overview

This document consolidates technical research and decision-making for the Clipboard History Manager feature. All technical unknowns from the Implementation Plan have been resolved through research into best practices, available technologies, and platform-specific considerations.

## Research Topics

### 1. macOS Clipboard Monitoring (NSPasteboard)

**Decision**: Use NSPasteboard polling with NSTimer

**Rationale**:
- NSPasteboard does not provide push-based notifications for clipboard changes
- Standard approach is periodic polling (every 0.5-1 second) to check for changes
- Polling interval of 500ms provides acceptable responsiveness while minimizing CPU usage
- Change detection: Compare `changeCount` property - increments on each clipboard modification
- This approach is used by popular clipboard managers (PasteBot, CopyLess, Maccy)

**Alternatives Considered**:
1. **NSDistributedNotificationCenter**: Does not provide reliable clipboard change notifications
2. **NSEvent monitoring**: Only works for keyboard shortcuts (Cmd+C), not all clipboard changes
3. **Carbon Events**: Deprecated API, not recommended for modern macOS apps

**Implementation Notes**:
- Monitor `NSPasteboard.Name.general` pasteboard
- Store previous `changeCount` value and compare on each poll
- Run timer on background thread to avoid blocking main thread
- Respect macOS 14+ privacy permissions - requires "Clipboard Access" permission

**References**:
- [NSPasteboard Documentation](https://developer.apple.com/documentation/appkit/nspasteboard)
- [Maccy Clipboard Manager Implementation](https://github.com/p0deje/Maccy)

---

### 2. Content Type Detection on macOS

**Decision**: Multi-tier UTI (Uniform Type Identifier) checking

**Rationale**:
- NSPasteboard supports multiple types simultaneously (e.g., text + rich text + HTML)
- Must check types in priority order: UTTypePNG, UTTypeImage → Image; UTTypeText, UTTypeUTF8PlainText → Text; UTTypeFileURL → File/Folder
- Some clipboard items have multiple representations - prefer highest fidelity type
- UTI-based checking is more reliable than MIME type or string matching

**Detection Logic**:
```swift
if pasteboard.types?.contains(UTTypeImage.identifier) == true {
    return .image
} else if pasteboard.types?.contains(UTTypeText.identifier) == true {
    return .text
} else if pasteboard.types?.contains(UTTypeFileURL.identifier) == true {
    return .fileReference
} else {
    return .unsupported
}
```

**Alternatives Considered**:
1. **String-based type checking**: Less reliable, depends on legacy type strings
2. **Data-based inspection**: More complex, slower performance

**Edge Cases Handled**:
- Rich text (RTF, HTML) - treated as text type
- Multiple image formats (PNG, JPEG, TIFF) - unified as image type
- File lists - treated as file reference type (logged only)
- Custom application types - treated as unsupported (ignored)

---

### 3. Source Application Detection

**Decision**: Use NSRunningApplication with frontmost application tracking

**Rationale**:
- When clipboard changes, track the currently active (frontmost) application
- NSWorkspace.shared.frontmostApplication reliably provides current app
- Capture bundle identifier, application name, and process ID at time of copy
- Bundle identifier is more reliable than app name (e.g., "com.apple.Safari" vs "Safari")

**Implementation Notes**:
- Record application info at clipboard change detection time
- If application terminates before clipboard processing, bundle ID and name remain valid
- Process ID may be stale if app quits, but this is acceptable for historical records

**Alternatives Considered**:
1. **Accessibility API**: More complex, requires additional permissions
2. **CGEvent tracking**: Only works for keyboard events, not programmatic copies

**References**:
- [NSWorkspace Documentation](https://developer.apple.com/documentation/appkit/nsworkspace)

---

### 4. SQLite Database for Rust

**Decision**: Use rusqlite crate with WAL mode

**Rationale**:
- rusqlite is the most mature and widely-used SQLite binding for Rust
- Supports synchronous and asynchronous operations
- WAL (Write-Ahead Logging) mode enables concurrent reads and writes
- Compiled SQL statements provide good performance for prepared queries
- Active maintenance and comprehensive documentation

**Configuration**:
```rust
Connection::open_with_flags(
    db_path,
    OpenFlags::SQLITE_OPEN_READ_WRITE | OpenFlags::SQLITE_OPEN_CREATE
)?;

// Enable WAL mode for better concurrency
conn.pragma_update(None, "journal_mode", "WAL")?;
conn.pragma_update(None, "synchronous", "NORMAL")?;
```

**Alternatives Considered**:
1. **sqlx**: Compile-time query verification, but heavier dependency
2. **diesel**: ORM layer - unnecessary complexity for this use case
3. **sled**: Pure Rust key-value store - lacks SQL query capabilities

**Performance Considerations**:
- WAL mode allows reads during writes (important for concurrent clipboard monitoring + queries)
- Index on content_hash column for fast duplicate detection
- Index on timestamp column for efficient history retrieval

**Dependencies**:
```toml
[dependencies]
rusqlite = { version = "0.30", features = ["bundled"] }
```

---

### 5. Content Hashing (SHA-256)

**Decision**: Use sha2 crate with SHA-256 algorithm

**Rationale**:
- SHA-256 provides 256-bit hash - extremely low collision probability
- Fast enough for clipboard content (typically < 1MB per item)
- Deterministic output - same content always produces same hash
- Widely available and battle-tested algorithm

**Implementation**:
```rust
use sha2::{Sha256, Digest};
use std::io::Read;

fn hash_text(text: &str) -> String {
    let mut hasher = Sha256::new();
    hasher.update(text.as_bytes());
    format!("{:x}", hasher.finalize())
}

fn hash_image(image_data: &[u8]) -> String {
    let mut hasher = Sha256::new();
    hasher.update(image_data);
    format!("{:x}", hasher.finalize())
}
```

**Alternatives Considered**:
1. **xxHash**: Faster, but non-cryptographic - acceptable for deduplication but less standard
2. **BLAKE3**: Modern and fast, but less widely adopted than SHA-256
3. **MD5/SHA-1**: Faster but cryptographically broken - not recommended

**Edge Cases**:
- Text normalization: Strip leading/trailing whitespace before hashing (user expectation)
- Binary data: Hash raw bytes for images
- Unicode text: Use UTF-8 bytes for deterministic hashing

---

### 6. FFI Interface Design (Swift ↔ Rust)

**Decision**: Use C FFI with extern "C" functions

**Rationale**:
- Swift can directly call C functions using `import` or `@_cdecl`
- Rust's `extern "C"` creates stable C ABI-compatible functions
- Simple types (pointers, integers, bools) transfer easily across FFI boundary
- Avoids complexity of heavier FFI frameworks (e.g., SwiftKit, cxx)

**Design Pattern**:
```rust
// Rust side
#[no_mangle]
pub extern "C" fn pasty_store_clipboard_entry(
    content_type: ContentType,
    content_ptr: *const u8,
    content_len: usize,
    source_app: *const c_char,
    timestamp_ms: i64,
) -> *mut ClipboardEntry {
    // Implementation
}
```

```swift
// Swift side
let result = pasty_store_clipboard_entry(
    contentType: PASTY_CONTENT_TYPE_TEXT,
    contentPtr: textBytes,
    contentLen: textBytes.count,
    sourceApp: bundleId,
    timestampMs: Date().timeIntervalSince1970 * 1000
)
```

**Memory Management**:
- Rust allocates and owns returned structs
- Swift calls cleanup function to free Rust-allocated memory
- Use `Box::into_raw` / `Box::from_raw` for struct transfer

**Alternatives Considered**:
1. **SwiftKit**: Higher-level Swift-Rust interop - less mature
2. **cbindgen**: Generate C headers from Rust - adds build complexity
3. **JSON serialization**: Simpler but slower runtime performance

---

### 7. Image Storage Strategy

**Decision**: File system storage with hash-based filenames

**Rationale**:
- Images can be large (1-10MB) - not suitable for database BLOB storage
- Hash-based filename (`sha256hash.png`) enables natural deduplication
- File system provides efficient access and caching
- Easy to backup and manage outside of application

**Directory Structure**:
```
~/Library/Application Support/Pasty/
├── clipboard.db              # SQLite database
└── images/
    ├── a1b2c3d4...          # Image files named by content hash
    ├── e5f6g7h8...
    └── ...
```

**Implementation Details**:
- Use two-level directory sharding for performance (first 4 chars of hash): `images/a1b2/a1b2c3d4...`
- This prevents directories with thousands of files
- Store relative path in database (not full path)
- Support PNG, JPEG, GIF, TIFF formats

**Alternatives Considered**:
1. **Database BLOB**: Simpler but poor performance for large images
2. **Object storage**: Overkill for local application
3. **Flat directory**: Performance degrades with many files

---

### 8. High-Frequency Clipboard Change Handling

**Decision**: Debounce + sequential queue processing

**Rationale**:
- Rapid clipboard changes (< 100ms apart) should not overwhelm the system
- Debounce window of 200ms captures rapid changes and processes them as a batch
- Sequential queue ensures data consistency (no race conditions)
- Background queue prevents blocking main thread

**Implementation Strategy**:
```swift
class ClipboardMonitor {
    private var debounceTimer: Timer?
    private var processingQueue = DispatchQueue(label: "com.pasty.clipboard")

    func onClipboardChange() {
        // Cancel existing timer
        debounceTimer?.invalidate()

        // Schedule new processing
        debounceTimer = Timer.scheduledTimer(
            withTimeInterval: 0.2,
            repeats: false
        ) { [weak self] _ in
            self?.processClipboardChange()
        }
    }
}
```

**Edge Cases**:
- If user copies 10 items rapidly, only process the last one (most recent)
- Queue prevents concurrent database writes
- Timeout handling: If processing takes > 1 second, log warning but continue

**Alternatives Considered**:
1. **Process every change**: Can overwhelm system with rapid copies
2. **Batch all changes**: Loses intermediate clipboard states

---

### 9. Error Handling Strategy

**Decision**: Result types with graceful degradation

**Rationale**:
- Rust: Use `Result<T, E>` and `thiserror` for structured errors
- Swift: Use `Result<T, Error>` and custom error types
- Never crash or lose data due to transient errors
- Log all errors for debugging

**Error Categories**:
1. **Transient errors**: Retry with exponential backoff
   - Database locked
   - File system busy
2. **Permanent errors**: Log and skip current clipboard item
   - Invalid data format
   - Insufficient disk space
3. **Permission errors**: Prompt user to grant permissions
   - Clipboard access denied
   - File system write denied

**Example**:
```rust
#[derive(Debug, thiserror::Error)]
pub enum ClipboardStoreError {
    #[error("Database error: {0}")]
    Database(#[from] rusqlite::Error),

    #[error("IO error: {0}")]
    Io(#[from] std::io::Error),

    #[error("Insufficient disk space")]
    InsufficientDiskSpace,
}
```

---

### 10. Performance Optimization Strategy

**Decision**: Measure first, optimize second (YAGNI)

**Rationale**:
- Premature optimization wastes time
- Success criteria provide measurable targets (100ms detection, 50ms queries)
- Profile before optimizing to identify actual bottlenecks

**Performance Targets**:
- Clipboard change detection: < 100ms (SC-001)
- Hash calculation: < 10ms for 1MB content
- Database insert: < 20ms
- Database query (10k entries): < 50ms (SC-006)
- Image file write: < 100ms for 5MB image

**Optimization Techniques (if needed)**:
1. **Hashing**: Use SIMD-optimized SHA-256 implementation
2. **Database**: Add indexes on frequently queried columns
3. **Concurrency**: Use background queues for I/O operations
4. **Caching**: Cache recent clipboard entries in memory

**Profiling Tools**:
- Rust: `cargo flamegraph`, `heaptrack`
- Swift: Instruments Time Profiler
- Database: `EXPLAIN QUERY PLAN` for SQL queries

---

## Summary

All technical unknowns have been resolved through research. Key decisions:

| Area | Decision | Rationale |
|------|----------|-----------|
| Clipboard Monitoring | NSPasteboard polling (500ms) | Standard approach, reliable |
| Content Type Detection | UTI-based checking | Modern, reliable |
| Source App Detection | NSWorkspace.frontmostApplication | Simple, accurate |
| Database | rusqlite with WAL mode | Mature, concurrent access |
| Hashing | SHA-256 via sha2 crate | Fast, collision-resistant |
| FFI | C ABI with extern "C" | Simple, stable |
| Image Storage | File system with hash names | Efficient, deduplicates |
| Rapid Changes | Debounce (200ms) + queue | Prevents overwhelm |
| Error Handling | Result types, graceful degrade | No crashes, good UX |
| Performance | Measure first, optimize second | YAGNI principle |

**Next Steps**:
- ✅ Phase 0 complete: All research documented
- ➡️ Phase 1: Generate data-model.md and contracts/
- ➡️ Phase 1: Generate quickstart.md
