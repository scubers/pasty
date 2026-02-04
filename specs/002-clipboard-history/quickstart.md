# Developer Quick Start Guide

**Feature**: 002-clipboard-history
**Date**: 2026-02-04
**Target Audience**: Developers implementing the clipboard history feature

## Overview

This guide provides step-by-step instructions for setting up the development environment and implementing the clipboard history manager. It covers both Rust (core layer) and Swift (macOS platform layer) development.

## Prerequisites

### System Requirements

- **Operating System**: macOS 14+ (Sonoma)
- **Xcode**: 15.0 or later
- **Swift**: 5.9+
- **Rust**: 1.70+ (stable)

### Required Tools

```bash
# Install Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# Verify installation
rustc --version  # Should be 1.70+
cargo --version

# Install Swift (comes with Xcode)
swift --version  # Should be 5.9+
```

### Install Xcode Command Line Tools

```bash
xcode-select --install
```

## Project Setup

### 1. Clone Repository

```bash
git clone <repository-url>
cd pasty
```

### 2. Install Rust Dependencies

```bash
cd core
cargo build
cargo test
```

### 3. Open Xcode Project

```bash
cd ../macos/PastyApp
xed .
# Or: open PastyApp.xcodeproj
```

## Project Structure

```
pasty/
├── core/                          # Rust cross-platform layer
│   ├── src/
│   │   ├── models/                # Data models
│   │   │   ├── clipboard_entry.rs # ClipboardEntry model
│   │   │   ├── content_hash.rs    # ContentHash model
│   │   │   ├── source_app.rs      # SourceApplication model
│   │   │   └── image_file.rs      # ImageFile model
│   │   ├── services/              # Business logic
│   │   │   ├── database.rs        # Database operations (SQLite)
│   │   │   ├── storage.rs         # File system operations
│   │   │   ├── deduplication.rs   # Hash calculation and deduplication
│   │   │   └── clipboard_store.rs # High-level clipboard storage API
│   │   ├── ffi/                   # FFI interface
│   │   │   ├── clipboard.rs       # FFI interface for clipboard operations
│   │   │   └── types.rs           # FFI type conversions
│   │   └── lib.rs                 # Library root
│   ├── tests/                     # Rust tests
│   │   ├── unit/                  # Unit tests for services
│   │   └── integration/           # Integration tests for database operations
│   └── Cargo.toml                 # Rust dependencies
│
├── macos/                         # macOS platform-specific layer (Swift)
│   └── PastyApp/
│       ├── Sources/
│       │   ├── ClipboardMonitor/  # Clipboard monitoring
│       │   │   └── Monitor.swift   # System-wide clipboard change detection
│       │   ├── ContentDetectors/   # Content type detection
│       │   │   └── ContentTypeDetector.swift  # Priority-based type detection
│       │   ├── ContentHandlers/    # Type-specific handlers
│       │   │   ├── ContentHandler.swift      # Protocol for handlers
│       │   │   ├── TextHandler.swift         # Handles text content
│       │   │   ├── ImageHandler.swift        # Handles image content
│       │   │   └── FileHandler.swift         # Handles file references (log only)
│       │   ├── PlatformLogic/      # Platform-specific business logic
│       │   │   ├── ClipboardCoordinator.swift  # Coordinates handlers & FFI
│       │   │   └── MetadataExtractor.swift     # Extracts source app & metadata
│       │   ├── Models/              # Data models
│       │   │   ├── ClipboardEvent.swift       # Clipboard event model
│       │   │   └── ContentType.swift          # Content type enum
│       │   ├── FFI/                 # FFI bridge to Rust core
│       │   │   └── RustBridge.swift           # Rust FFI bridge
│       │   └── App/                 # Application entry point
│       │       └── ClipboardMonitorApp.swift  # Main app coordinator
│       └── Tests/                   # Swift tests
│           └── ClipboardMonitorTests/
│
├── tests/                         # Cross-language integration tests
│   └── contract/                  # Contract tests between Swift and Rust
│
└── specs/002-clipboard-history/   # Documentation
    ├── spec.md
    ├── plan.md
    ├── research.md
    ├── data-model.md
    ├── quickstart.md
    └── contracts/
        ├── rust-ffi.md
        └── database-schema.md
```

## Development Workflow

### Phase 1: Rust Core Layer

#### Step 1.1: Add Dependencies

Edit `core/Cargo.toml`:

```toml
[dependencies]
serde = { version = "1.0", features = ["derive"] }
thiserror = "1.0"
uuid = { version = "1.0", features = ["v4", "serde"] }
rusqlite = { version = "0.30", features = ["bundled"] }
sha2 = "0.10"
chrono = { version = "0.4", features = ["serde"] }

[dev-dependencies]
tempfile = "3.8"  # For test databases
```

#### Step 1.2: Define Data Models

Create `core/src/models/clipboard_entry.rs`:

```rust
use serde::{Deserialize, Serialize};
use uuid::Uuid;
use chrono::{DateTime, Utc};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ClipboardEntry {
    pub id: Uuid,
    pub content_hash: String,
    pub content_type: ContentType,
    pub timestamp: DateTime<Utc>,
    pub content: Content,
    pub source: SourceApplication,
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
pub enum ContentType {
    Text,
    Image,
}
```

#### Step 1.3: Implement Database Service

Create `core/src/services/database.rs`:

```rust
use rusqlite::{Connection, Result};
use crate::models::ClipboardEntry;

pub struct ClipboardDatabase {
    conn: Connection,
}

impl ClipboardDatabase {
    pub fn new(db_path: &str) -> Result<Self> {
        let conn = Connection::open(db_path)?;
        // Initialize schema
        conn.execute(
            "CREATE TABLE IF NOT EXISTS clipboard_entries (...)",
            [],
        )?;
        Ok(Self { conn })
    }

    pub fn insert_entry(&self, entry: &ClipboardEntry) -> Result<()> {
        // Implementation
        Ok(())
    }
}
```

#### Step 1.4: Implement FFI Layer

Create `core/src/ffi/clipboard.rs`:

```rust
use std::ffi::{CStr, CString};
use std::os::raw::c_char;

#[no_mangle]
pub extern "C" fn pasty_store_clipboard_entry(
    content_type: ContentType,
    content_ptr: *const u8,
    content_len: usize,
    source_bundle_id: *const c_char,
    source_app_name: *const c_char,
    source_pid: i32,
    timestamp_ms: i64,
) -> *mut ClipboardEntry {
    // Implementation
}
```

#### Step 1.5: Write Tests

Create `core/tests/database_tests.rs`:

```rust
#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_insert_and_retrieve() {
        let db = ClipboardDatabase::new(":memory:").unwrap();
        // Test implementation
    }
}
```

#### Step 1.6: Build and Test

```bash
cd core
cargo build
cargo test
```

---

### Phase 2: Swift Platform Layer

#### Step 2.1: Create Clipboard Monitor

Create `macos/PastyApp/Sources/ClipboardMonitor/Monitor.swift`:

```swift
import Cocoa
import Foundation

/// Monitors system-wide clipboard changes via NSPasteboard polling
class Monitor {
    private var timer: Timer?
    private var lastChangeCount: Int = 0
    private let pasteboard = NSPasteboard.general
    private let detector: ContentTypeDetector
    private let coordinator: ClipboardCoordinator

    init(detector: ContentTypeDetector, coordinator: ClipboardCoordinator) {
        self.detector = detector
        self.coordinator = coordinator
    }

    func startMonitoring() {
        timer = Timer.scheduledTimer(
            withTimeInterval: 0.5,
            repeats: true
        ) { [weak self] _ in
            self?.checkForChanges()
        }
    }

    private func checkForChanges() {
        let currentChangeCount = pasteboard.changeCount

        if currentChangeCount != lastChangeCount {
            lastChangeCount = currentChangeCount
            processClipboardChange()
        }
    }

    private func processClipboardChange() {
        // 1. Detect content type with priority
        let detectedType = detector.detectContentType(from: pasteboard)

        // 2. Get appropriate handler
        guard let handler = ContentHandlerFactory.handler(for: detectedType) else {
            return // Unsupported type, ignore
        }

        // 3. Extract source application
        let sourceApp = SourceApplication.current()

        // 4. Handle content via coordinator (platform logic layer)
        handler.handle(pasteboard: pasteboard, source: sourceApp, coordinator: coordinator)
    }
}
```

#### Step 2.2: Create Content Type Detector

Create `macos/PastyApp/Sources/ContentDetectors/ContentTypeDetector.swift`:

```swift
import UniformTypeIdentifiers

enum ClipboardContentType {
    case text
    case image
    case fileReference
    case unsupported
}

struct ContentTypeDetector {
    /// Detects clipboard content type with priority ordering: text > image > file > unsupported
    func detectContentType(from pasteboard: NSPasteboard) -> ClipboardContentType {
        let types = pasteboard.types ?? []

        // Priority 1: Text (most common, always preferred if available)
        if types.contains(UTType.text.identifier) ||
           types.contains(UTType.utf8PlainText.identifier) {
            return .text
        }

        // Priority 2: Image
        if types.contains(UTType.image.identifier) {
            return .image
        }

        // Priority 3: File/folder reference
        if types.contains(UTType.fileURL.identifier) {
            return .fileReference
        }

        // Priority 4: Unsupported
        return .unsupported
    }
}
```

#### Step 2.3: Create Content Handlers

Create `macos/PastyApp/Sources/ContentHandlers/ContentHandler.swift`:

```swift
import Foundation

/// Protocol for content type-specific handlers
protocol ContentHandler {
    func handle(pasteboard: NSPasteboard, source: SourceApplication, coordinator: ClipboardCoordinator)
}

/// Factory for creating appropriate handlers
struct ContentHandlerFactory {
    static func handler(for type: ClipboardContentType) -> ContentHandler? {
        switch type {
        case .text:
            return TextHandler()
        case .image:
            return ImageHandler()
        case .fileReference:
            return FileHandler()
        case .unsupported:
            return nil
        }
    }
}
```

Create `macos/PastyApp/Sources/ContentHandlers/TextHandler.swift`:

```swift
struct TextHandler: ContentHandler {
    func handle(pasteboard: NSPasteboard, source: SourceApplication, coordinator: ClipboardCoordinator) {
        guard let text = pasteboard.string(forType: .string) else { return }

        // Delegate to platform logic layer (not directly to FFI)
        coordinator.storeTextContent(text, source: source)
    }
}
```

Create `macos/PastyApp/Sources/ContentHandlers/ImageHandler.swift`:

```swift
struct ImageHandler: ContentHandler {
    func handle(pasteboard: NSPasteboard, source: SourceApplication, coordinator: ClipboardCoordinator) {
        guard let imageData = pasteboard.data(forType: .png) ?? pasteboard.data(forType: .tiff) else {
            return
        }

        // Delegate to platform logic layer
        coordinator.storeImageContent(imageData, source: source)
    }
}
```

Create `macos/PastyApp/Sources/ContentHandlers/FileHandler.swift`:

```swift
struct FileHandler: ContentHandler {
    func handle(pasteboard: NSPasteboard, source: SourceApplication, coordinator: ClipboardCoordinator) {
        // Log file/folder reference but don't store
        if let fileURLs = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] {
            for url in fileURLs {
                NSLog("[FileHandler] File reference detected: \(url.path)")
            }
        }
    }
}
```

#### Step 2.4: Create Platform Logic Layer

Create `macos/PastyApp/Sources/PlatformLogic/ClipboardCoordinator.swift`:

```swift
import Foundation

/// Platform-specific business logic layer that coordinates handlers and FFI
class ClipboardCoordinator {
    private let ffiBridge: RustBridge

    init(ffiBridge: RustBridge = RustBridge()) {
        self.ffiBridge = ffiBridge
    }

    func storeTextContent(_ text: String, source: SourceApplication) {
        // Normalize text before storing
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Prepare metadata
        let timestamp = Date()

        // Call FFI to store in database
        _ = ffiBridge.storeClipboardEntry(
            type: .text,
            data: normalized.data(using: .utf8) ?? Data(),
            source: source,
            timestamp: timestamp
        )
    }

    func storeImageContent(_ imageData: Data, source: SourceApplication) {
        let timestamp = Date()

        // Call FFI to store in database and file system
        _ = ffiBridge.storeClipboardEntry(
            type: .image,
            data: imageData,
            source: source,
            timestamp: timestamp
        )
    }

    func retrieveHistory(limit: Int = 50, offset: Int = 0) -> [ClipboardEntry] {
        return ffiBridge.getClipboardHistory(limit: limit, offset: offset)
    }
}
```

Create `macos/PastyApp/Sources/PlatformLogic/MetadataExtractor.swift`:

```swift
import Cocoa

struct SourceApplication {
    let bundleId: String
    let appName: String
    let pid: Int32

    static func current() -> SourceApplication {
        let workspace = NSWorkspace.shared
        let app = workspace.frontmostApplication

        return SourceApplication(
            bundleId: app?.bundleIdentifier ?? "unknown",
            appName: app?.localizedName ?? "Unknown",
            pid: app?.processIdentifier ?? 0
        )
    }
}
```

#### Step 2.5: Create Rust Bridge

Create `macos/PastyApp/Sources/FFI/RustBridge.swift`:

```swift
import Foundation

class RustBridge {
    static func storeClipboardEntry(
        type: ClipboardContentType,
        data: Data,
        source: SourceApplication,
        timestamp: Date
    ) -> ClipboardEntry? {
        var error: PastyErrorCode = 0

        data.withUnsafeBytes { bytes in
            let entry = pasty_store_clipboard_entry(
                type.toFFIType(),
                bytes.baseAddress,
                data.count,
                source.bundleId,
                source.appName,
                source.pid,
                Int64(timestamp.timeIntervalSince1970 * 1000),
                &error
            )

            if error == .success {
                defer { pasty_entry_free(entry) }
                return ClipboardEntry.from(entry)
            } else {
                return nil
            }
        }
    }
}
```

#### Step 2.6: Integration Setup

Create `macos/PastyApp/Sources/App/ClipboardMonitorApp.swift`:

```swift
import Cocoa

class ClipboardMonitorApp {
    private let monitor: Monitor
    private let coordinator: ClipboardCoordinator

    init() {
        let detector = ContentTypeDetector()
        let ffiBridge = RustBridge()
        self.coordinator = ClipboardCoordinator(ffiBridge: ffiBridge)
        self.monitor = Monitor(detector: detector, coordinator: coordinator)
    }

    func start() {
        monitor.startMonitoring()
        NSLog("[ClipboardMonitorApp] System-wide clipboard monitoring started")
    }
}
```

#### Step 2.7: Write Tests

Create `macos/PastyApp/Tests/ClipboardMonitorTests/ClipboardMonitorTests.swift`:

```swift
import XCTest
@testable import PastyApp

final class ClipboardMonitorTests: XCTestCase {
    func testContentTypeDetection() {
        let pasteboard = NSPasteboard.general
        let type = ContentTypeDetector.detectType(from: pasteboard)
        // Assertions
    }
}
```

#### Step 2.8: Build and Test

```bash
cd macos/PastyApp
xcodebuild test -scheme PastyApp
```

---

## Testing

### Run All Tests

```bash
# Rust tests
cd core
cargo test

# Swift tests
cd macos/PastyApp
xcodebuild test -scheme PastyApp
```

### Run Specific Test

```bash
# Rust
cargo test test_insert_and_retrieve

# Swift
xcodebuild test -scheme PastyApp -only-testing:PastyAppTests/ClipboardMonitorTests/testContentTypeDetection
```

---

## Building

### Build Rust Library

```bash
cd core
cargo build --release
```

Output: `core/target/release/libpasty_core.a` (static library)

### Build Swift Application

```bash
cd macos/PastyApp
xcodebuild build -scheme PastyApp
```

Output: `macos/PastyApp/build/Release/PastyApp.app`

---

## Development Tips

### Rust Development

1. **Use `cargo watch` for auto-rebuild**:
   ```bash
   cargo install cargo-watch
   cargo watch -x check -x test -x run
   ```

2. **Enable Rust Analyzer**:
   - Install VS Code or IntelliJ IDEA with Rust plugin
   - Get code completion, go-to-definition, and inline errors

3. **Profile Performance**:
   ```bash
   cargo install flamegraph
   cargo flamegraph --bin pasty-core
   ```

### Swift Development

1. **Use Xcode Features**:
   - Breakpoints for debugging
   - Instruments for profiling
   - View Debugger for UI inspection

2. **Enable SwiftUI Previews** (if using SwiftUI):
   ```swift
   struct ClipboardMonitorView_Previews: PreviewProvider {
       static var previews: some View {
           ClipboardMonitorView()
       }
   }
   ```

---

## Common Issues

### Issue: FFI Linking Errors

**Solution**: Ensure Rust library is compiled as static library:

```toml
# core/Cargo.toml
[lib]
crate-type = ["staticlib", "cdylib"]
```

### Issue: Database Locked

**Solution**: Enable WAL mode:

```rust
conn.pragma_update(None, "journal_mode", "WAL")?;
```

### Issue: Clipboard Permission Denied

**Solution**: Add entitlements to macOS app:

```xml
<!-- macos/PastyApp/PastyApp.entitlements -->
<key>com.apple.security.automation.apple-events</key>
<true/>
```

---

## Environment Variables

### Rust

```bash
# Enable detailed logging
export RUST_LOG=debug

# Use local SQLite instead of bundled
export LIBSQLITE_SYS_BUNDLED=0
```

### Swift

```bash
# Set custom database path
export PASTY_DB_PATH=/tmp/test.db

# Enable verbose logging
export PASTY_LOG_LEVEL=debug
```

---

## Debugging

### Rust

```bash
# Run with debugger
lldb target/debug/pasty-core

# Print backtrace
RUST_BACKTRACE=1 cargo test
```

### Swift

```bash
# Run with debugger
lldb build/Release/PastyApp.app/Contents/MacOS/PastyApp

# View console output
log stream --predicate 'process == "PastyApp"'
```

---

## Next Steps

1. ✅ Complete Phase 1: Rust core layer (database, storage, deduplication)
2. ✅ Complete Phase 2: Swift platform layer (clipboard monitoring, FFI bridge)
3. ➡️ Run integration tests between Swift and Rust
4. ➡️ Test on real macOS system with actual clipboard operations
5. ➡️ Performance testing with large clipboard datasets
6. ➡️ Create user interface for viewing clipboard history

---

## Resources

### Documentation

- [Rust Book](https://doc.rust-lang.org/book/)
- [Swift Programming Language](https://docs.swift.org/swift-book/)
- [SQLite Documentation](https://www.sqlite.org/docs.html)
- [NSPasteboard Reference](https://developer.apple.com/documentation/appkit/nspasteboard)

### Internal Documentation

- [Feature Spec](../spec.md)
- [Implementation Plan](../plan.md)
- [Research Findings](../research.md)
- [Data Model](../data-model.md)
- [FFI Contract](../contracts/rust-ffi.md)
- [Database Schema](../contracts/database-schema.md)

---

## Getting Help

- **Feature Artifacts**: See `specs/002-clipboard-history/` directory
- **Constitution**: `.specify/memory/constitution.md`
- **Issue Tracker**: GitHub issues (if available)

---

## Validation Checklist

Use this checklist to verify that the clipboard history feature is working correctly after setup or changes.

### ✅ Prerequisites Verification

- [ ] Rust 1.70+ installed (`rustc --version`)
- [ ] Cargo available (`cargo --version`)
- [ ] Swift 5.9+ available (`swift --version`)
- [ ] Xcode 15.0+ installed (`xcodebuild -version`)
- [ ] Git repository cloned locally

### ✅ Build Verification

#### Rust Core Layer

- [ ] `cd core && cargo build` succeeds without errors
- [ ] `cd core && cargo test` passes all tests (77+ tests expected)
- [ ] Static library generated: `core/target/release/libpasty_core.a`
- [ ] No compiler warnings about unused dependencies

#### Swift/macOS Layer

- [ ] `cd macos/PastyApp && xcodegen generate` creates Xcode project
- [ ] `cd macos/PastyApp && xcodebuild build` succeeds
- [ ] App bundle created: `build/macos/PastyApp.app`
- [ ] No Swift compiler errors or warnings

### ✅ Functional Testing

#### Clipboard Monitoring (User Story 1)

**Test 1: Text Content**

```bash
# 1. Build and run the app
open build/macos/PastyApp.app

# 2. Copy some text (e.g., "Test clipboard entry")
echo "Test clipboard entry" | pbcopy

# 3. Verify in logs or database
# Expected: Entry should be stored with deduplication
```

- [ ] Text is captured when copied
- [ ] Duplicate text is detected (same hash)
- [ ] Source application is recorded
- [ ] Timestamp is accurate

**Test 2: Image Content**

```bash
# 1. Copy an image (screenshot or image file)
screenshot -c /tmp/test.png
pngpaste /tmp/test.png | pbcopy

# 2. Verify storage
# Expected: Image file stored in images directory with hash-based sharding
```

- [ ] Image is captured when copied
- [ ] Image file is saved with correct permissions (600)
- [ ] Duplicate images are detected (same hash)
- [ ] Image path is stored in database

**Test 3: File References**

```bash
# Copy a file reference
echo "test" > /tmp/test.txt
osascript -e 'tell application "Finder" to set the clipboard to (POSIX file "/tmp/test.txt")'

# Expected: File references are logged but not stored
```

- [ ] File references are detected
- [ ] File references are logged (console output)
- [ ] File references are NOT stored in database

**Test 4: Deduplication**

```bash
# Copy same text twice
echo "Duplicate test" | pbcopy
# Wait 1 second
echo "Duplicate test" | pbcopy

# Expected: Only one entry, with updated timestamp
```

- [ ] Second copy updates `latest_copy_time_ms`
- [ ] Only one database entry exists
- [ ] Same content hash is used

#### Clipboard Retrieval (User Story 2)

**Test 5: Retrieve All Entries**

```bash
# Copy multiple items
for i in {1..5}; do
    echo "Entry $i" | pbcopy
    sleep 0.5
done

# Query history (via API or direct database query)
# Expected: 5 entries returned, ordered by most recent
```

- [ ] `get_history(10, 0)` returns 5 entries
- [ ] Entries are ordered by timestamp DESC
- [ ] All metadata fields are populated
- [ ] Text content is accessible
- [ ] Image paths are accessible

**Test 6: Filter by Content Type**

```bash
# Copy some text and images
echo "Text only" | pbcopy
screenshot -c /tmp/test.png && pngpaste /tmp/test.png | pbcopy

# Query for text entries only
# Expected: Only text entries returned
```

- [ ] `get_history_filtered(ContentType::Text, 10, 0)` returns only text
- [ ] `get_history_filtered(ContentType::Image, 10, 0)` returns only images
- [ ] Filter results are accurate

**Test 7: Retrieve by ID**

```bash
# Get an entry ID from database (or store a new entry and note the ID)
# Query for that specific ID
# Expected: Entry is returned or None if not found
```

- [ ] `get_entry_by_id(uuid)` returns correct entry
- [ ] `get_entry_by_id(fake_uuid)` returns None
- [ ] Retrieved entry has all fields

**Test 8: Pagination**

```bash
# Copy 10 entries
for i in {1..10}; do
    echo "Entry $i" | pbcopy
    sleep 0.5
done

# Get first page (limit=3, offset=0)
# Expected: 3 entries (most recent)

# Get second page (limit=3, offset=3)
# Expected: 3 entries (next most recent)

# Get third page (limit=3, offset=6)
# Expected: 3 entries (oldest of 10)
```

- [ ] Page 1 returns entries 10, 9, 8 (most recent)
- [ ] Page 2 returns entries 7, 6, 5
- [ ] Page 3 returns entries 4, 3, 2
- [ ] Fourth page returns entry 1
- [ ] Pagination is consistent

### ✅ Performance Verification

**Test 9: Database Query Performance**

```bash
# Insert 10,000 entries (via test script)
# Query history with various limits
# Expected: Queries complete in < 50ms
```

- [ ] Query with limit=100 completes in < 50ms
- [ ] Query with filter by type completes in < 50ms
- [ ] No performance degradation with large datasets

**Test 10: Clipboard Change Detection Latency**

```bash
# Copy content and measure time to detection
# Expected: < 100ms detection latency
```

- [ ] Clipboard changes are detected within 500ms (polling interval)
- [ ] Processing is complete within 100ms after detection
- [ ] No clipboard changes are missed

### ✅ Security & Privacy Verification

**Test 11: File Permissions**

```bash
# Check database and image file permissions
ls -l ~/Library/Application\ Support/Pasty/clipboard.db
ls -l ~/Library/Application\ Support/Pasty/images/*/*

# Expected: Database and images have 600 permissions (rw-------)
```

- [ ] Database file has permissions 600 (owner read/write only)
- [ ] Image files have permissions 600
- [ ] Images directory has permissions 700
- [ ] No sensitive data in logs (no clipboard content in log output)

**Test 12: Error Handling**

```bash
# Trigger various error conditions
# Expected: Graceful error handling, no crashes
```

- [ ] Database is locked → automatic retry works
- [ ] Invalid data → handled gracefully, logged
- [ ] Disk full → error message, app continues running
- [ ] All operations have proper error logging

### ✅ Integration Testing

**Test 13: FFI Contract Tests**

```bash
cd core
cargo test --test retrieve_test -- --test-threads=1
```

- [ ] All contract tests pass (6 tests)
- [ ] Memory management tests pass (no leaks)
- [ ] Null pointer handling works correctly

**Test 14: Cross-Layer Integration**

```bash
# Run full app test suite
cargo test
xcodebuild test -scheme PastyApp
```

- [ ] All Rust tests pass
- [ ] All Swift tests pass
- [ ] No integration errors between Rust and Swift
- [ ] FFI calls work correctly in both directions

### ✅ Data Integrity Verification

**Test 15: Database Consistency**

```bash
# Query database directly to verify data integrity
sqlite3 ~/Library/Application\ Support/Pasty/clipboard.db "SELECT COUNT(*) FROM clipboard_entries;"

# Verify indexes are present
sqlite3 ~/Library/Application\ Support/Pasty/clipboard.db ".indexes"
```

- [ ] Entry count matches expected number
- [ ] Indexes exist on key columns (content_hash, content_type, timestamp)
- [ ] No orphaned records (all images have corresponding files)
- [ ] No missing files (all database entries have files if applicable)

**Test 16: Hash Consistency**

```bash
# Verify hash calculation is consistent
# Store same content, verify hash matches
```

- [ ] Same text always produces same hash
- [ ] Text trimming is applied before hashing
- [ ] Same image data produces same hash
- [ ] Different content produces different hash

### ✅ Production Readiness Checklist

- [ ] All critical bugs are fixed
- [ ] Performance meets success criteria (SC-001 through SC-010)
- [ ] Security audit passed (no clipboard content leaks)
- [ ] Documentation is complete and accurate
- [ ] Tests cover all critical code paths
- [ ] Error handling is robust
- [ ] Logging is comprehensive but not excessive
- [ ] Memory leaks are addressed
- [ ] Build process is automated and reproducible

---

## Success Criteria Validation

Each success criterion (SC-001 through SC-010 from spec.md) should be validated:

| Criterion | Description | Validation Method | Status |
|-----------|-------------|-------------------|--------|
| SC-001 | Clipboard change detection latency < 100ms | Performance test with timing | [ ] |
| SC-002 | Database query performance < 50ms | Query timing tests | [ ] |
| SC-003 | Support 10k+ entries | Stress test with 10k entries | [ ] |
| SC-004 | Deduplication works correctly | Unit tests for deduplication | [ ] |
| SC-005 | Text and image support | Functional tests | [ ] |
| SC-006 | File reference logging | Manual test with file copies | [ ] |
| SC-007 | Pagination support | Functional tests with pagination | [ ] |
| SC-008 | Database permissions check | File permission verification | [ ] |
| SC-009 | FFI integration | Contract tests pass | [ ] |
| SC-010 | Cross-platform compatibility | Works on macOS 14+ | [ ] |

---

## Troubleshooting Validation Failures

### If Build Fails

1. **Check Rust version**: `rustc --version` (must be 1.70+)
2. **Check Swift version**: `swift --version` (must be 5.9+)
3. **Clean and rebuild**:
   ```bash
   cd core && cargo clean && cargo build
   cd ../macos/PastyApp && rm -rf build && xcodegen generate
   ```
4. **Check dependencies**: `cargo tree` or `swift package show dependencies`

### If Tests Fail

1. **Run tests individually** to identify specific failures:
   ```bash
   cargo test test_name
   ```
2. **Check test logs**: `RUST_BACKTRACE=1 cargo test`
3. **Verify test data**: Ensure test database is clean
4. **Run tests sequentially**: `cargo test -- --test-threads=1`

### If Functional Tests Fail

1. **Check logs**: Console output from macOS app or `RUST_LOG=debug`
2. **Verify database**: Check if entries are being stored
3. **Test FFI directly**: Run contract tests to verify Rust-Swift communication
4. **Check permissions**: Verify database and image file permissions

### If Performance Tests Fail

1. **Check database indexes**: Ensure `idx_clipboard_entries_type_timestamp` exists
2. **Verify prepared statement cache**: Check for cache capacity = 100
3. **Profile**: Use `cargo flamegraph` or Instruments to identify bottlenecks
4. **Check for locking**: Reduce concurrent access if database locks are frequent

---

## Summary

This quick start guide provides:

- ✅ Complete environment setup instructions
- ✅ Step-by-step implementation workflow
- ✅ Code examples for Rust and Swift
- ✅ Testing and debugging strategies
- ✅ Common issue resolutions
- ✅ Links to detailed documentation
- ✅ **NEW**: Comprehensive validation checklist with 16 test scenarios
- ✅ **NEW**: Success criteria validation table
- ✅ **NEW**: Troubleshooting guide for validation failures

**Ready to implement**: Follow the phases in order, run tests frequently, use the validation checklist to verify functionality, and refer to design artifacts for detailed specifications.
