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

## Summary

This quick start guide provides:

- ✅ Complete environment setup instructions
- ✅ Step-by-step implementation workflow
- ✅ Code examples for Rust and Swift
- ✅ Testing and debugging strategies
- ✅ Common issue resolutions
- ✅ Links to detailed documentation

**Ready to implement**: Follow the phases in order, run tests frequently, and refer to design artifacts for detailed specifications.
