# Implementation Plan: Clipboard History Manager

**Branch**: `002-clipboard-history` | **Date**: 2026-02-04 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/002-clipboard-history/spec.md`

## Summary

Implement a local clipboard history manager for macOS that automatically monitors clipboard changes, records text and image content with metadata, persists to local database with deduplication, and provides query capabilities for history retrieval.

**Primary Requirements**:
- System-wide clipboard change detection on macOS (monitors all applications, not just app-internal)
- Content type identification with priority handling: text > image > file/folder > unsupported
- Metadata recording (initial timestamp, latest copy timestamp, source application, content hash)
- Local database persistence with deduplication and schema versioning for migrations
- Image file storage with hash-based naming
- Extensible handler architecture: Monitor → Detector → Handler → Platform Logic → FFI → Rust Core

**Technical Approach**:
- Platform-specific layer (macOS/Swift) for clipboard monitoring using NSPasteboard
- Cross-platform layer (Rust) for database operations, file system operations, and deduplication logic
- SQLite for local metadata storage
- File system for image content storage
- SHA-256 for content hashing and deduplication

## Technical Context

**Language/Version**: Swift 5.9+ (macOS layer), Rust 1.70+ (core layer)
**Primary Dependencies**:
  - macOS: AppKit framework (NSPasteboard), Foundation
  - Rust: rusqlite (SQLite), sha2 (hashing), uuid, serde, thiserror
**Storage**:
  - SQLite database for clipboard metadata (text content, hashes, timestamps, source app)
  - File system for image content (hash-based filenames)
**Testing**:
  - Swift: XCTest for clipboard monitoring tests
  - Rust: cargo test for database, file system, and deduplication tests
**Target Platform**: macOS 14+ (Sonoma and later)
**Project Type**: Cross-platform framework (Rust core + platform-specific Swift layer)
**Performance Goals**:
  - Clipboard change detection within 100ms (SC-001)
  - Handle 100 clipboard entries per second (SC-005)
  - Database queries under 50ms for 10,000 entries (SC-006)
**Constraints**:
  - Must not block main thread during clipboard monitoring
  - Must handle large content (10MB text, high-res images) gracefully
  - Must handle rapid clipboard changes without data loss
  - Must respect macOS security and privacy model
**Scale/Scope**:
  - Local single-user application
  - Expected database size: up to 10,000 entries
  - Image storage: user-controlled location (~/Library/Application Support/Pasty)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### ✅ I. User Story Priority

**Status**: PASS

- P1 (Monitor and Record): Independently testable - can verify clipboard monitoring and recording without retrieval UI
- P2 (Retrieve History): Independently testable - can query database independently from monitoring
- No cross-dependencies that prevent independent implementation
- Stories are ordered by business value (recording first, then retrieval)

### ✅ II. Test-First Development

**Status**: PASS

- All acceptance scenarios from spec.md will have corresponding tests
- TDD workflow will be enforced during implementation phase
- Tests will be automated and runnable in CI/CD
- Test structure:
  - Rust: Unit tests for database, hashing, deduplication logic
  - Swift: Integration tests for NSPasteboard monitoring
  - Contract tests for FFI boundary between Swift and Rust

### ✅ III. Documentation Before Implementation

**Status**: PASS

- spec.md completed and approved (2026-02-04)
- plan.md (this document) will be completed before task breakdown
- All design artifacts (research.md, data-model.md, contracts/, quickstart.md) will be generated
- No implementation will begin before complete documentation

### ✅ IV. Simplicity & YAGNI

**Status**: PASS

- Implementing only P1 and P2 features (monitoring + retrieval)
- No premature optimization - will measure before optimizing
- Simple SQLite database for local storage (not complex distributed database)
- Direct file system storage for images (not object storage or custom format)
- No cloud sync or network functionality (out of scope for this feature)
- FFI interface between Swift and Rust kept minimal (clipboard events, database operations)

**Justification for complexity**: None - design follows YAGNI principles

### ✅ V. Cross-Platform Compatibility

**Status**: PASS

- Core clipboard logic (database, hashing, deduplication) in platform-agnostic Rust layer
- Platform-specific code (NSPasteboard monitoring) isolated in Swift layer
- Clear interface between Swift and Rust via FFI
- macOS implementation respects platform permissions and security model
- Feature parity considerations: Architecture supports future Windows/Linux implementations

### ✅ VI. Privacy & Security First

**Status**: PASS

- Clipboard history stored locally ONLY (no network transmission)
- Database stored in user's Application Support directory with proper permissions
- Images stored as regular files (can leverage macOS file encryption)
- User can clear clipboard history (delete database files)
- No telemetry or analytics that could leak clipboard content
- Source application tracking respects macOS privacy model
- Data at rest: Can leverage macOS FileVault for whole-disk encryption (user-controlled)

**Privacy Considerations**:
- Clipboard may contain passwords, tokens, private info
- Application will require explicit user permission to monitor clipboard
- Clear indication of clipboard access status will be provided
- User can disable monitoring at any time

## Project Structure

### Documentation (this feature)

```text
specs/002-clipboard-history/
├── spec.md              # Feature specification (completed)
├── plan.md              # This file (implementation plan)
├── research.md          # Phase 0: Technical research and decisions
├── data-model.md        # Phase 1: Data model design
├── quickstart.md        # Phase 1: Developer quick start guide
├── contracts/           # Phase 1: API/FFI contracts
│   ├── rust-ffi.md      # Rust FFI interface contract
│   └── database-schema.md  # Database schema contract
└── tasks.md             # Phase 2: Task breakdown (created by /speckit.tasks)
```

### Source Code (repository root)

```text
core/                          # Rust cross-platform layer
├── src/
│   ├── models/
│   │   ├── clipboard_entry.rs    # ClipboardEntry model
│   │   ├── content_hash.rs       # ContentHash model
│   │   ├── source_app.rs         # SourceApplication model
│   │   └── image_file.rs         # ImageFile model
│   ├── services/
│   │   ├── database.rs           # Database operations (SQLite)
│   │   ├── storage.rs            # File system operations
│   │   ├── deduplication.rs      # Hash calculation and deduplication
│   │   └── clipboard_store.rs    # High-level clipboard storage API
│   ├── ffi/
│   │   ├── clipboard.rs          # FFI interface for clipboard operations
│   │   └── types.rs              # FFI type conversions
│   └── lib.rs                    # Library root
├── tests/
│   ├── unit/                     # Unit tests for services
│   └── integration/              # Integration tests for database operations
└── Cargo.toml

macos/                         # macOS platform-specific layer (Swift)
└── PastyApp/
    ├── Sources/
    │   ├── ClipboardMonitor/
    │   │   ├── ClipboardMonitor.swift      # NSPasteboard monitoring orchestrator
    │   │   └── Monitor.swift               # System-wide clipboard change detection
    │   ├── ContentDetectors/
    │   │   └── ContentTypeDetector.swift   # Content type detection with priority
    │   ├── ContentHandlers/
    │   │   ├── TextHandler.swift           # Handles text clipboard content
    │   │   ├── ImageHandler.swift          # Handles image clipboard content
    │   │   ├── FileHandler.swift           # Handles file/folder references (log only)
    │   │   └── ContentHandler.swift        # Protocol for content handlers
    │   ├── PlatformLogic/
    │   │   ├── ClipboardCoordinator.swift  # Coordinates handlers and calls FFI
    │   │   ├── StorageManager.swift        # Platform-level storage operations
    │   │   └── MetadataExtractor.swift     # Extracts source app and metadata
    │   ├── Models/
    │   │   ├── ClipboardEvent.swift        # Clipboard event model
    │   │   └── ContentType.swift           # Content type enum
    │   └── FFI/
    │       └── RustBridge.swift            # FFI bridge to Rust core
    └── Tests/
        └── ClipboardMonitorTests/          # Clipboard monitoring tests

tests/                         # Cross-language integration tests
└── contract/                  # Contract tests between Swift and Rust
```

**Structure Decision**:
This is a **cross-platform framework** project with:
- **core/**: Rust crate for cross-platform business logic (database, storage, deduplication)
- **macos/**: Swift macOS app for platform-specific clipboard monitoring with extensible handler architecture
- **tests/**: Shared test suite including contract tests for FFI boundary

**Swift Architecture Pattern**:
The macOS layer follows an extensible, layered architecture:
1. **Monitor**: Detects system-wide clipboard changes via NSPasteboard polling
2. **Detector**: Identifies content types with priority ordering (text > image > file > unsupported)
3. **Handler**: Type-specific processing (TextHandler, ImageHandler, FileHandler)
4. **Platform Logic**: Coordinates handlers and prepares data for FFI layer
5. **FFI Bridge**: Calls Rust core for database persistence

This separation follows Principle V (Cross-Platform Compatibility) by isolating platform-specific code (Swift) from core logic (Rust). The FFI boundary is kept minimal to reduce complexity while enabling future platform implementations (Windows, Linux).

## Complexity Tracking

> **No complexity violations to justify**

This feature follows all constitutional principles:
- User stories are prioritized and independent
- Test-first development will be enforced
- Documentation precedes implementation
- YAGNI principles followed (no premature abstractions or future features)
- Cross-platform architecture enforced
- Privacy and security requirements met

