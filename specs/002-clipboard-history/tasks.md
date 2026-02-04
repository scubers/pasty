# Tasks: Clipboard History Manager

**Input**: Design documents from `/specs/002-clipboard-history/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/

**Tests**: Tests are included as this feature requires TDD approach per the constitution (Section II).

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2)
- Include exact file paths in descriptions

## Path Conventions

This project uses a cross-platform architecture:
- **Rust core**: `core/` for cross-platform business logic
- **macOS/Swift**: `macos/PastyApp/` for platform-specific clipboard monitoring
- **Tests**: `core/tests/` and `macos/PastyApp/Tests/` for language-specific tests
- **Contract tests**: `tests/contract/` for FFI boundary tests

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization and basic structure for both Rust and Swift layers

- [x] T001 Create Rust core project structure with Cargo.toml in core/
- [x] T002 Initialize Swift macOS app project with XcodeGen in macos/PastyApp/
- [x] T003 [P] Add Rust dependencies to core/Cargo.toml: rusqlite, sha2, uuid, serde, thiserror, chrono
- [x] T004 [P] Configure Swift package dependencies in macos/PastyApp/project.yml: Foundation, AppKit
- [x] T005 [P] Create directory structure for core/src/models, core/src/services, core/src/ffi
- [x] T006 [P] Create directory structure for macOS: ClipboardMonitor, ContentDetectors, ContentHandlers, PlatformLogic, Models, FFI
- [x] T007 [P] Create test directories: core/tests/unit, core/tests/integration, tests/contract, macos/PastyApp/Tests
- [x] T008 [P] Configure Rust toolchain: set edition = "2021" in Cargo.toml
- [x] T009 [P] Configure Swift version: 5.9+ in macos/PastyApp/project.yml

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure that MUST be complete before ANY user story can be implemented

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

### Rust Core Foundation

- [x] T010 Create database schema migration files in core/migrations/001_initial.up.sql and 001_initial.down.sql
- [x] T011 Implement database connection manager with WAL mode in core/src/services/database.rs
- [x] T012 Implement migration system with version tracking in core/src/services/database.rs
- [x] T013 [P] Create ClipboardEntry model in core/src/models/clipboard_entry.rs
- [x] T014 [P] Create ContentType enum in core/src/models/clipboard_entry.rs
- [x] T015 [P] Create Content enum (Text/Image variants) in core/src/models/clipboard_entry.rs
- [x] T016 [P] Create SourceApplication model in core/src/models/source_app.rs
- [x] T017 [P] Create ImageFile model with ImageFormat enum in core/src/models/image_file.rs
- [x] T018 Implement content hash service (SHA-256) in core/src/services/deduplication.rs
- [x] T019 Implement text normalization (trim whitespace) in core/src/services/deduplication.rs
- [x] T020 Implement file system storage service for images in core/src/services/storage.rs
- [x] T021 Implement two-level directory sharding for images in core/src/services/storage.rs
- [x] T022 Create error types with thiserror in core/src/services/database.rs, storage.rs, deduplication.rs
- [x] T023 Implement clipboard store service (high-level API) in core/src/services/clipboard_store.rs

### Swift/macOS Foundation

- [x] T024 Create ClipboardEvent model in macos/PastyApp/Sources/Models/ClipboardEvent.swift
- [x] T025 Create ContentType enum in macos/PastyApp/Sources/Models/ContentType.swift
- [x] T026 [P] Create ClipboardMonitor orchestrator in macos/PastyApp/Sources/ClipboardMonitor/ClipboardMonitor.swift
- [x] T027 [P] Create Monitor (NSPasteboard polling) in macos/PastyApp/Sources/ClipboardMonitor/Monitor.swift
- [x] T028 [P] Create ContentTypeDetector in macos/PastyApp/Sources/ContentDetectors/ContentTypeDetector.swift
- [x] T029 [P] Create ContentHandler protocol in macos/PastyApp/Sources/ContentHandlers/ContentHandler.swift
- [x] T030 [P] Create TextHandler in macos/PastyApp/Sources/ContentHandlers/TextHandler.swift
- [x] T031 [P] Create ImageHandler in macos/PastyApp/Sources/ContentHandlers/ImageHandler.swift
- [x] T032 [P] Create FileHandler (log only) in macos/PastyApp/Sources/ContentHandlers/FileHandler.swift
- [x] T033 [P] Create ClipboardCoordinator in macos/PastyApp/Sources/PlatformLogic/ClipboardCoordinator.swift
- [x] T034 [P] Create StorageManager in macos/PastyApp/Sources/PlatformLogic/StorageManager.swift
- [x] T035 [P] Create MetadataExtractor in macos/PastyApp/Sources/PlatformLogic/MetadataExtractor.swift

### FFI Bridge Foundation

- [x] T036 Define C types and enums in core/src/ffi/types.rs
- [x] T037 Implement FFI function signatures in core/src/ffi/clipboard.rs
- [x] T038 Implement accessor functions for ClipboardEntry in core/src/ffi/clipboard.rs
- [x] T039 Implement memory management functions (entry_free, list_free) in core/src/ffi/clipboard.rs
- [x] T040 Create RustBridge Swift wrapper in macos/PastyApp/Sources/FFI/RustBridge.swift
- [x] T041 Implement Swift type mappings in macos/PastyApp/Sources/FFI/RustBridge.swift

### Build Configuration

- [x] T042 Configure cdylib build for Rust FFI in core/Cargo.toml
- [x] T043 Setup XcodeGen to link Rust static library in macos/PastyApp/project.yml
- [x] T044 Create build script to compile Rust library and link to Swift app
- [x] T045 Verify FFI compilation: Swift can call Rust functions successfully

**Checkpoint**: Foundation ready - user story implementation can now begin in parallel

---

## Phase 3: User Story 1 - Monitor and Record Clipboard Changes (Priority: P1) 🎯 MVP

**Goal**: Automatically detect and record clipboard changes (text and images) with metadata to local database with deduplication

**Independent Test**: Copy various types of content (text, images, files) and verify that the system correctly records supported types (text, images) with metadata, logs unsupported types (files), and updates duplicates without creating new entries

### Tests for User Story 1 (TDD - Write First, Ensure Failures)

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation**

#### Rust Core Tests

- [x] T046 [P] [US1] Unit test for hash calculation in core/tests/unit/deduplication_test.rs
- [x] T047 [P] [US1] Unit test for text normalization in core/tests/unit/deduplication_test.rs
- [x] T048 [P] [US1] Unit test for duplicate detection in core/tests/unit/clipboard_store_test.rs
- [x] T049 [P] [US1] Unit test for image file storage with sharding in core/tests/unit/storage_test.rs
- [x] T050 [P] [US1] Integration test for database insert and retrieve in core/tests/integration/database_test.rs
- [x] T051 [P] [US1] Integration test for database migration in core/tests/integration/database_test.rs

#### Swift/macOS Tests

- [x] T052 [P] [US1] Unit test for NSPasteboard change detection in macos/PastyApp/Tests/ClipboardMonitorTests/MonitorTest.swift
- [x] T053 [P] [US1] Unit test for content type detection with priority in macos/PastyApp/Tests/ClipboardMonitorTests/ContentTypeDetectorTest.swift
- [x] T054 [P] [US1] Unit test for text handler extraction in macos/PastyApp/Tests/ClipboardMonitorTests/TextHandlerTest.swift
- [x] T055 [P] [US1] Unit test for image handler processing in macos/PastyApp/Tests/ClipboardMonitorTests/ImageHandlerTest.swift
- [x] T056 [P] [US1] Unit test for source app extraction in macos/PastyApp/Tests/ClipboardMonitorTests/MetadataExtractorTest.swift

#### Contract Tests

- [x] T057 [P] [US1] Contract test for pasty_store_clipboard_entry FFI in tests/contract/store_entry_test.rs
- [x] T058 [P] [US1] Contract test for duplicate detection via FFI in tests/contract/store_entry_test.rs
- [x] T059 [P] [US1] Contract test for memory management (entry_free) in tests/contract/memory_test.rs

### Implementation for User Story 1

#### Rust Core Implementation

- [x] T060 [P] [US1] Implement hash_text function in core/src/services/deduplication.rs
- [x] T061 [P] [US1] Implement hash_image function in core/src/services/deduplication.rs
- [x] T062 [P] [US1] Implement normalize_text function (trim whitespace) in core/src/services/deduplication.rs
- [x] T063 [US1] Implement check_duplicate function in core/src/services/clipboard_store.rs (depends on T060, T061)
- [x] T064 [US1] Implement store_text_entry function in core/src/services/clipboard_store.rs (depends on T063)
- [x] T065 [US1] Implement store_image_entry function in core/src/services/clipboard_store.rs (depends on T063)
- [x] T066 [US1] Implement update_duplicate_timestamp function in core/src/services/clipboard_store.rs
- [x] T067 [US1] Implement save_image_file function with sharding in core/src/services/storage.rs
- [x] T068 [US1] Add prepared statement caching for database queries in core/src/services/database.rs

#### Swift/macOS Implementation

- [x] T069 [US1] Implement NSPasteboard polling with 500ms interval in macos/PastyApp/Sources/ClipboardMonitor/Monitor.swift
- [x] T070 [US1] Implement changeCount comparison for change detection in macos/PastyApp/Sources/ClipboardMonitor/Monitor.swift
- [x] T071 [US1] Implement content type detection with UTI priority checking in macos/PastyApp/Sources/ContentDetectors/ContentTypeDetector.swift
- [x] T072 [US1] Implement TextHandler content extraction in macos/PastyApp/Sources/ContentHandlers/TextHandler.swift
- [x] T073 [US1] Implement ImageHandler content extraction in macos/PastyApp/Sources/ContentHandlers/ImageHandler.swift
- [x] T074 [US1] Implement FileHandler logging (no storage) in macos/PastyApp/Sources/ContentHandlers/FileHandler.swift
- [x] T075 [US1] Implement MetadataExtractor for source app detection in macos/PastyApp/Sources/PlatformLogic/MetadataExtractor.swift
- [x] T076 [US1] Implement ClipboardCoordinator handler orchestration in macos/PastyApp/Sources/PlatformLogic/ClipboardCoordinator.swift
- [x] T077 [US1] Implement debounce logic (200ms) for rapid changes in macos/PastyApp/Sources/ClipboardMonitor/ClipboardMonitor.swift
- [x] T078 [US1] Wire up FFI call from ClipboardCoordinator to Rust pasty_store_clipboard_entry in macos/PastyApp/Sources/PlatformLogic/ClipboardCoordinator.swift

#### Integration & End-to-End

- [x] T079 [US1] Integrate Monitor with ClipboardMonitor orchestrator in macos/PastyApp/Sources/ClipboardMonitor/ClipboardMonitor.swift
- [x] T080 [US1] Setup background queue for clipboard monitoring to avoid blocking main thread
- [x] T081 [US1] Implement error handling and logging for clipboard operations
- [x] T082 [US1] Add graceful degradation for database errors (log and continue)
- [x] T083 [US1] Add graceful degradation for file system errors (log and continue)

**Checkpoint**: At this point, User Story 1 should be fully functional and testable independently
**Validation**: Run all tests for US1, copy text/images manually and verify database records

---

## Phase 4: User Story 2 - Retrieve Clipboard History (Priority: P2)

**Goal**: Provide query capabilities to retrieve clipboard history with filtering options

**Independent Test**: Copy multiple items, then query the database via FFI to retrieve them. Verify that all recorded clipboard entries are returned with complete metadata and content is accessible

### Tests for User Story 2 (TDD - Write First, Ensure Failures)

#### Rust Core Tests

- [x] T084 [P] [US2] Unit test for retrieve all entries query in core/tests/unit/clipboard_store_test.rs
- [x] T085 [P] [US2] Unit test for retrieve by content type filter in core/tests/unit/clipboard_store_test.rs
- [x] T086 [P] [US2] Unit test for retrieve by ID query in core/tests/unit/clipboard_store_test.rs
- [x] T087 [P] [US2] Unit test for pagination (LIMIT/OFFSET) in core/tests/unit/clipboard_store_test.rs

#### Contract Tests

- [x] T088 [P] [US2] Contract test for pasty_get_clipboard_history FFI in tests/contract/retrieve_test.rs
- [x] T089 [P] [US2] Contract test for pasty_get_entry_by_id FFI in tests/contract/retrieve_test.rs
- [x] T090 [P] [US2] Contract test for list accessors and memory management in tests/contract/retrieve_test.rs

### Implementation for User Story 2

#### Rust Core Implementation

- [x] T091 [US2] Implement get_history function with pagination in core/src/services/clipboard_store.rs
- [x] T092 [US2] Implement get_history_filtered function by content type in core/src/services/clipboard_store.rs
- [x] T093 [US2] Implement get_entry_by_id function in core/src/services/clipboard_store.rs
- [x] T094 [US2] Add query optimization: use idx_clipboard_entries_type_timestamp index
- [x] T095 [US2] Implement pasty_get_clipboard_history FFI wrapper in core/src/ffi/clipboard.rs
- [x] T096 [US2] Implement pasty_get_entry_by_id FFI wrapper in core/src/ffi/clipboard.rs
- [x] T097 [US2] Implement ClipboardEntryList accessor functions in core/src/ffi/clipboard.rs
- [x] T098 [US2] Implement pasty_list_free memory management in core/src/ffi/clipboard.rs

#### Swift/macOS Implementation

- [x] T099 [US2] Create ClipboardHistory service wrapper in macos/PastyApp/Sources/PlatformLogic/ClipboardHistory.swift
- [x] T100 [US2] Implement retrieveAllEntries function in macos/PastyApp/Sources/PlatformLogic/ClipboardHistory.swift
- [x] T101 [US2] Implement retrieveEntriesFiltered by type function in macos/PastyApp/Sources/PlatformLogic/ClipboardHistory.swift
- [x] T102 [US2] Implement retrieveEntryById function in macos/PastyApp/Sources/PlatformLogic/ClipboardHistory.swift
- [x] T103 [US2] Add Swift model mappings from FFI ClipboardEntry in macos/PastyApp/Sources/Models/ClipboardEntry.swift

**Checkpoint**: ✅ User Stories 1 AND 2 both work independently
**Validation**: ✅ All tests passing (77 tests), build successful
**Completed**: 2026-02-04

---

## Phase 5: Polish & Cross-Cutting Concerns

**Purpose**: Improvements that affect multiple user stories and production readiness

### Performance & Optimization

- [ ] T104 [P] Profile clipboard change detection latency (target: < 100ms)
- [ ] T105 [P] Profile database query performance with 10k entries (target: < 50ms)
- [ ] T106 [P] Add prepared statement caching if not already implemented
- [ ] T107 [P] Optimize image file I/O with buffered writes

### Error Handling & Logging

- [ ] T108 [P] Add comprehensive error logging to Rust services in core/src/services/
- [ ] T109 [P] Add comprehensive error logging to Swift handlers in macos/PastyApp/Sources/
- [ ] T110 [P] Implement structured error types with context in Rust
- [ ] T111 [P] Add error recovery for transient database locks

### Security & Privacy

- [ ] T112 [P] Verify database file permissions (600) in core/src/services/storage.rs
- [ ] T113 [P] Verify clipboard access permission handling in Swift
- [ ] T114 [P] Add secure deletion option for clipboard history

### Documentation & Developer Experience

- [ ] T115 [P] Create quickstart.md validation checklist
- [ ] T116 [P] Add inline documentation to FFI functions
- [ ] T117 [P] Add inline documentation to public API surfaces
- [ ] T118 [P] Create example usage documentation for clipboard monitoring

### Additional Testing

- [ ] T119 [P] Add stress test for rapid clipboard changes (100 copies/second)
- [ ] T120 [P] Add integration test for large content handling (10MB text, high-res images)
- [ ] T121 [P] Add edge case tests: special characters, unicode, empty content
- [ ] T122 [P] Add contract test for concurrent FFI calls

### Production Readiness

- [ ] T123 [P] Run full test suite and ensure 100% pass rate
- [ ] T124 [P] Validate against quickstart.md scenarios
- [ ] T125 [P] Performance test against all success criteria (SC-001 through SC-010)
- [ ] T126 [P] Security audit: verify no clipboard content leaks in logs
- [ ] T127 Create release notes and migration guide if needed

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Story 1 (Phase 3)**: Depends on Foundational phase - No dependencies on other user stories
- **User Story 2 (Phase 4)**: Depends on Foundational phase - Uses database created by US1 but independently testable
- **Polish (Phase 5)**: Depends on US1 and US2 being functionally complete

### User Story Dependencies

- **User Story 1 (P1)**: Can start after Foundational - No dependencies on US2
- **User Story 2 (P2)**: Can start after Foundational - Queries data created by US1 but tests can use seeded database

### Within Each User Story

- Tests MUST be written and FAIL before implementation (TDD)
- Rust core models/services before FFI wrappers
- FFI wrappers before Swift integration
- Core implementation before integration/end-to-end
- Story complete before moving to next priority

### Parallel Opportunities

#### Phase 1 (Setup)
- T003, T004, T005, T006, T007, T008, T009 can all run in parallel

#### Phase 2 (Foundational)
- T013-T017 (models) can run in parallel
- T026-T035 (Swift components) can run in parallel

#### Phase 3 (User Story 1)
- All tests T046-T059 can run in parallel
- T060-T062 (hashing functions) can run in parallel
- T046-T055 (unit tests) can run in parallel

#### Phase 4 (User Story 2)
- All tests T084-T090 can run in parallel
- T091-T093 (query functions) can run in parallel after US1 complete

#### Phase 5 (Polish)
- All tasks marked [P] can run in parallel

---

## Parallel Example: User Story 1 Models

```bash
# Launch all model creation tasks together:
Task T013: "Create ClipboardEntry model in core/src/models/clipboard_entry.rs"
Task T014: "Create ContentType enum in core/src/models/clipboard_entry.rs"
Task T015: "Create Content enum in core/src/models/clipboard_entry.rs"
Task T016: "Create SourceApplication model in core/src/models/source_app.rs"
Task T017: "Create ImageFile model in core/src/models/image_file.rs"
```

---

## Parallel Example: User Story 1 Tests

```bash
# Launch all tests for User Story 1 together (after writing tests):
Task T046: "Unit test for hash calculation in core/tests/unit/deduplication_test.rs"
Task T047: "Unit test for text normalization in core/tests/unit/deduplication_test.rs"
Task T048: "Unit test for duplicate detection in core/tests/unit/clipboard_store_test.rs"
Task T049: "Unit test for image file storage in core/tests/unit/storage_test.rs"
Task T050: "Integration test for database insert in core/tests/integration/database_test.rs"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (T001-T009)
2. Complete Phase 2: Foundational (T010-T045) - CRITICAL, blocks everything
3. Complete Phase 3: User Story 1 (T046-T083)
4. **STOP and VALIDATE**: Test User Story 1 independently
5. Deploy/demo MVP - clipboard is being monitored and recorded

### Incremental Delivery

1. Complete Setup + Foundational → Foundation ready
2. Add User Story 1 → Test independently → Deploy/Demo (MVP!) ✅
3. Add User Story 2 → Test independently → Deploy/Demo
4. Add Polish improvements → Final production release
5. Each phase adds value without breaking previous work

### Parallel Team Strategy

With multiple developers:

1. Team completes Setup + Foundational together (T001-T045)
2. Once Foundational is done:
   - Developer A: User Story 1 Rust core (T060-T068)
   - Developer B: User Story 1 Swift layer (T069-T078)
   - Developer C: User Story 1 tests (T046-T059)
3. Integrate User Story 1 components
4. Repeat parallel approach for User Story 2

---

## Notes

- **[P]** tasks = different files, no blocking dependencies
- **[US1]**, **[US2]** labels map task to specific user story for traceability
- Each user story should be independently completable and testable
- **TDD is enforced**: Tests must be written first and must fail before implementation
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently
- The FFI boundary is critical - contract tests verify correctness
- Performance targets are defined in success criteria (SC-001 through SC-010)
- All clipboard content is local-only - no network transmission (privacy requirement)
