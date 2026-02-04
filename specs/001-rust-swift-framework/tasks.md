# Tasks: Cross-Platform Framework Infrastructure

**Input**: Design documents from `/specs/001-rust-swift-framework/`
**Prerequisites**: plan.md (required), spec.md (required for user stories), research.md, data-model.md, contracts/

**Tests**: This feature follows Test-First Development (TDD) per the constitution. Unit tests are required for Rust core with 80% coverage target (SC-006).

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

- **Rust core**: `core/src/`, `core/tests/`, `core/Cargo.toml`
- **Swift macOS**: `macos/PastyApp/`, `macos/PastyApp.xcodeproj`
- **Build scripts**: `scripts/` at repository root
- **Build artifacts**: `build/core/`, `build/macos/` (gitignored)

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization and directory structure setup

- [x] T001 Create Rust core library directory structure at `core/src/` with subdirectories `models/`, `services/`, `ffi/`
- [x] T002 Create Swift macOS app directory structure at `macos/PastyApp/` with `src/` subdirectory
- [x] T003 Create build scripts directory at `scripts/` and tests directory at `tests/unit/`, `tests/contract/`, `tests/integration/`
- [x] T004 Initialize Rust project with `cargo init --lib` in `core/` directory
- [x] T005 [P] Create `core/Cargo.toml` with package metadata, dependencies (serde, thiserror), and crate-type ["staticlib", "cdylib"]
- [x] T006 [P] Create `core/cbindgen.toml` configuration for C header generation with language = "C", fn.prefix = "pasty_"
- [x] T007 Add `build/` directory to `.gitignore` with patterns for `build/core/`, `build/macos/`, `target/`
- [x] T008 Create `macos/PastyApp/Info.plist` with macOS app bundle metadata and minimum OS version 11.0
- [x] T009 Create `macos/PastyApp/PastyApp.entitlements` with clipboard access permissions for macOS

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure that MUST be complete before ANY user story can be implemented

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [x] T010 Implement Rust FFI exports module structure in `core/src/ffi/mod.rs` with re-exports
- [x] T011 [P] Implement FFI export functions in `core/src/ffi/exports.rs`: `pasty_get_version()`, `pasty_init()`, `pasty_shutdown()`, `pasty_free_string()`, `pasty_get_last_error()`
- [x] T012 [P] Implement thread-local error storage helper `set_last_error()` in `core/src/ffi/exports.rs` using `thread_local!` macro
- [x] T013 [P] Add placeholder clipboard FFI functions in `core/src/ffi/exports.rs`: `pasty_clipboard_get_text()`, `pasty_clipboard_set_text()` returning "Not implemented" errors
- [x] T014 Create `core/src/lib.rs` with module declarations for `models`, `services`, `ffi` and public FFI re-exports
- [x] T015 [P] Create `core/src/models/mod.rs` with module declarations for clipboard_entry and clipboard_history (empty stubs)
- [x] T016 [P] Create `core/src/models/clipboard_entry.rs` with `ClipboardEntry`, `ContentType`, `ClipboardData` struct definitions (no implementation)
- [x] T017 [P] Create `core/src/models/clipboard_history.rs` with `ClipboardHistory` struct definition (no implementation)
- [x] T018 [P] Create `core/src/services/mod.rs` with module declarations for encryption (empty stub)
- [x] T019 [P] Create `core/src/services/encryption.rs` with `EncryptionService` trait definition and `EncryptionError` enum (no implementation)
- [x] T020 Write FFI unit tests in `core/tests/ffi_tests.rs` for version retrieval, init/shutdown cycle, and string freeing
- [x] T021 Write FFI unit tests in `core/tests/error_handling_tests.rs` for thread-local error storage and retrieval
- [x] T022 Write data model unit tests in `core/tests/model_tests.rs` for ClipboardEntry validation and ContentType matching
- [x] T023 [P] Create Swift FFIBridge scaffold in `macos/PastyApp/src/FFIBridge.swift` with `PastyFFIBridge` class and FFI function declarations using `@_silgen_name`
- [x] T024 [P] Implement FFIBridge initialization methods in `macos/PastyApp/src/FFIBridge.swift`: `initialize()`, `shutdown()`, `getVersion()`, `getLastError()`
- [x] T025 Create Swift AppDelegate stub in `macos/PastyApp/src/AppDelegate.swift` with `NSApplicationDelegate` protocol conformance
- [x] T026 [P] Create `scripts/common.sh` with shared utility functions for logging (`log_info`, `log_error`, `log_warn`) and color output
- [x] T027 [P] Create `scripts/check-prereqs.sh` that validates Rust ≥1.70, Xcode ≥14, Swift ≥5.9 with clear error messages and installation URLs
- [x] T028 [P] Create `scripts/build-core.sh` that builds Rust library with `cargo build` for specified architecture (x86_64/arm64/universal) and configuration (debug/release)
- [x] T029 Implement universal binary creation in `scripts/build-core.sh` using `lipo -create` to combine x86_64 and arm64 static libraries
- [x] T030 Implement C header generation in `scripts/build-core.sh` using cbindgen to output `build/core/include/pasty.h`
- [x] T031 [P] Create `scripts/build-macos.sh` that validates Rust library exists and invokes `xcodebuild` with correct configuration
- [x] T032 [P] Create `scripts/build.sh` main orchestrator that calls check-prereqs.sh, build-core.sh, build-macos.sh in correct order
- [x] T033 [P] Create `scripts/run.sh` that launches built app from `build/macos/PastyApp.app` using `open` command
- [x] T034 [P] Create `scripts/test-core.sh` that runs `cargo test` and optionally generates coverage with tarpaulin
- [x] T035 Make all shell scripts executable with `chmod +x` in scripts directory

**Checkpoint**: Foundation ready - user story implementation can now begin in parallel

---

## Phase 3: User Story 1 - Core Rust Library Foundation (Priority: P1) 🎯 MVP

**Goal**: Developers can build, test, and document a functional Rust core library with FFI exports

**Independent Test**: Run `./scripts/build-core.sh release` → compiles successfully; Run `./scripts/test-core.sh` → all tests pass with ≥80% coverage

### Tests for User Story 1 (REQUIRED - TDD) ⚠️

> **NOTE: Tests are written FIRST in TDD. Ensure tests FAIL before implementation.**

- [x] T036 [P] [US1] Write FFI contract test in `tests/contract/test_ffi_api.rs` verifying `pasty_get_version()` returns valid semver string
- [x] T037 [P] [US1] Write FFI contract test in `tests/contract/test_ffi_api.rs` verifying `pasty_init()` returns 0 and can be called multiple times
- [x] T038 [P] [US1] Write FFI contract test in `tests/contract/test_ffi_api.rs` verifying `pasty_free_string()` safely handles null pointers
- [x] T039 [P] [US1] Write unit test in `core/tests/ffi_tests.rs` verifying `pasty_get_last_error()` returns null when no error set
- [x] T040 [P] [US1] Write unit test in `core/tests/model_tests.rs` verifying `ClipboardEntry` struct can be instantiated with valid data
- [x] T041 [P] [US1] Write unit test in `core/tests/model_tests.rs` verifying `ContentType` enum variants (Text, Image, File, HTML)

### Implementation for User Story 1

- [x] T042 [P] [US1] Complete `ClipboardEntry` implementation in `core/src/models/clipboard_entry.rs` with `new()` constructor and validation logic
- [x] T043 [P] [US1] Complete `ContentType` and `ClipboardData` enums in `core/src/models/clipboard_entry.rs` with Debug and PartialEq derives
- [x] T044 [P] [US1] Complete `ClipboardHistory` struct in `core/src/models/clipboard_history.rs` with field definitions (no implementation yet)
- [x] T045 [US1] Complete `EncryptionService` trait in `core/src/services/encryption.rs` with method signatures for `encrypt()` and `decrypt()`
- [x] T046 [US1] Complete `EncryptionError` enum in `core/src/services/encryption.rs` with variants (KeychainAccessFailed, InvalidData, etc.)
- [x] T047 [US1] Update `core/src/lib.rs` to re-export all public types from models and services modules
- [x] T048 [US1] Run `cargo doc --no-deps` in `core/` to generate API documentation and verify it builds without warnings
- [x] T049 [US1] Run `cargo test` in `core/` and verify all tests pass with ≥80% code coverage (SC-006)
- [x] T050 [US1] Run `./scripts/build-core.sh release` and verify static library `libcore.a` is created in `build/core/universal/release/`
- [x] T051 [US1] Run `./scripts/build-core.sh release` and verify C header `pasty.h` is generated in `build/core/include/`

**Checkpoint**: At this point, User Story 1 should be fully functional - Rust core library compiles, tests pass, documentation generates, FFI exports work

---

## Phase 4: User Story 2 - Build and Run Automation Scripts (Priority: P1)

**Goal**: Developers can build and run the entire application with single command

**Independent Test**: Run `./scripts/build.sh release` → full build succeeds; Run `./scripts/run.sh release` → app launches

### Implementation for User Story 2

- [x] T052 [P] [US2] Add environment variable detection to `scripts/build-core.sh` for CONFIGURATION, ARCH, CLEAN, VERBOSE flags
- [x] T053 [P] [US2] Add Rust toolchain validation to `scripts/build-core.sh` with version check (≥1.70) and helpful error message
- [x] T054 [P] [US2] Add Rust target installation to `scripts/build-core.sh` for x86_64-apple-darwin and aarch64-apple-darwin using `rustup target add`
- [x] T055 [US2] Add clean build support to `scripts/build-core.sh` that runs `cargo clean` when CLEAN=true
- [x] T056 [P] [US2] Add build artifact copying to `scripts/build-core.sh` to output `build/core/universal/$CONFIG/libcore.a`
- [x] T057 [P] [US2] Add color-coded logging to `scripts/build-core.sh` using functions from `common.sh`
- [x] T058 [P] [US2] Add error handling to `scripts/build-core.sh` with clear messages and exit code 4 on build failure
- [x] T059 [P] [US2] Add Rust library validation to `scripts/build-macos.sh` that checks `build/core/universal/$CONFIG/libcore.a` exists before Xcode build
- [x] T060 [P] [US2] Add Xcode project validation to `scripts/build-macos.sh` that verifies `.xcodeproj` exists
- [x] T061 [P] [US2] Add build output handling to `scripts/build-macos.sh` that copies `.app` bundle to `build/macos/`
- [x] T062 [P] [US2] Add color-coded logging to `scripts/build-macos.sh` using functions from `common.sh`
- [x] T063 [P] [US2] Add help option to `scripts/build.sh` that displays usage with examples
- [x] T064 [P] [US2] Add argument parsing to `scripts/build.sh` for build type, clean flag, and architecture
- [x] T065 [US2] Implement sequential build orchestration in `scripts/build.sh`: check-prereqs → build-core → build-macos
- [x] T066 [US2] Add build summary to `scripts/build.sh` displaying configuration, duration, and artifact locations
- [x] T067 [P] [US2] Add app bundle validation to `scripts/run.sh` that checks `build/macos/PastyApp.app` exists
- [x] T068 [P] [US2] Add launch command to `scripts/run.sh` using `open` with PID tracking
- [x] T069 [P] [US2] Add error handling to `scripts/run.sh` that offers to build app if not found
- [x] T070 [US2] Run `./scripts/build.sh release` from clean state and verify it completes in <3 minutes (SC-007)
- [x] T071 [US2] Run `./scripts/build.sh release`, modify source file, run again and verify incremental build <30 seconds
- [x] T072 [US2] Run `./scripts/run.sh debug` and verify app launches without errors

**Checkpoint**: At this point, User Stories 1 AND 2 should both work - complete build/test/run workflow established

---

## Phase 5: User Story 3 - macOS Swift Platform Layer (Priority: P2)

**Goal**: Swift macOS app successfully calls Rust FFI functions and displays menu bar UI

**Independent Test**: Build app → launch → menu bar appears with "Quit" and "About" items; Swift can call `pasty_get_version()` and get valid response

### Tests for User Story 3 (REQUIRED - FFI Interoperability) ⚠️

- [x] T073 [P] [US3] Write integration test in `tests/integration/test_swift_rust_ffi.swift` verifying Swift can call `pasty_get_version()` and parse response
- [x] T074 [P] [US3] Write integration test in `tests/integration/test_swift_rust_ffi.swift` verifying Swift can call `pasty_init()` and `pasty_shutdown()` without crashes
- [x] T075 [P] [US3] Write integration test in `tests/integration/test_swift_rust_ffi.swift` verifying string memory management (Rust allocates, Swift frees)

### Implementation for User Story 3

- [x] T076 [P] [US3] Complete FFIBridge error handling in `macos/PastyApp/src/FFIBridge.swift` with `FFIError` enum and `fromCode()` method
- [x] T077 [P] [US3] Complete FFIBridge placeholder methods in `macos/PastyApp/src/FFIBridge.swift`: `getClipboardText()`, `setClipboardText()` throwing not implemented errors
- [x] T078 [P] [US3] Create `macos/PastyApp/src/main.swift` with NSApplication entry point and app delegate initialization
- [x] T079 [US3] Create `macos/PastyApp/src/MenuBarManager.swift` with `NSStatusBar` setup and basic menu creation
- [x] T080 [US3] Implement menu items in `macos/PastyApp/src/MenuBarManager.swift`: "Quit" and "About" with working selectors
- [x] T081 [US3] Complete AppDelegate in `macos/PastyApp/src/AppDelegate.swift` with `applicationDidFinishLaunching()` calling `FFIBridge.initialize()`
- [x] T082 [US3] Complete AppDelegate in `macos/PastyApp/src/AppDelegate.swift` with `applicationWillTerminate()` calling `FFIBridge.shutdown()`
- [x] T083 [US3] Add working "About" menu item handler in `macos/PastyApp/src/AppDelegate.swift` that displays version from `FFIBridge.getVersion()`
- [x] T084 [US3] Create Xcode project file `macos/PastyApp.xcodeproj/project.pbxproj` linking against `build/core/universal/release/libcore.a`
- [x] T085 [US3] Add Run Script build phase to Xcode project that executes `scripts/build-core.sh` before Swift compilation
- [x] T086 [US3] Add module map `core/module.modulemap` for Swift C interop with `pasty.h` header
- [x] T087 [US3] Run `./scripts/build.sh release` and verify Swift app links against Rust library without errors
- [x] T088 [US3] Run `./scripts/run.sh release` and verify menu bar icon appears
- [x] T089 [US3] Click menu bar icon and verify "Quit" and "About" menu items are present and functional
- [x] T090 [US3] Click "About" menu item and verify it displays app version from Rust core (demonstrates FFI works)

**Checkpoint**: At this point, User Stories 1, 2, AND 3 should all work - complete FFI bridge verified, menu bar UI functional

---

## Phase 6: User Story 4 - DMG Packaging and Distribution (Priority: P3)

**Goal**: Generate distributable DMG file with code signing support

**Independent Test**: Run `./scripts/package.sh release sign` → DMG created; Mount DMG → app installs and launches

### Implementation for User Story 4

- [x] T091 [P] [US4] Create `scripts/package.sh` with argument parsing for build type (debug/release) and signing (sign/nosign)
- [x] T092 [P] [US4] Add prerequisite validation to `scripts/package.sh` checking for `create-dmg` tool and app bundle existence
- [x] T093 [P] [US4] Add code signing certificate detection to `scripts/package.sh` using `security find-identity -v -p codesigning`
- [x] T094 [P] [US4] Add ad-hoc signing fallback to `scripts/package.sh` when no certificate found (SIGNING_IDENTITY="-")
- [x] T095 [P] [US4] Implement app bundle signing in `scripts/package.sh` using `codesign --force --deep --sign` with entitlements
- [x] T096 [P] [US4] Add signature verification to `scripts/package.sh` using `codesign --verify --deep`
- [x] T097 [P] [US4] Implement DMG creation in `scripts/package.sh` using `create-dmg` with window positioning and app icon
- [x] T098 [P] [US4] Add Applications shortcut to DMG in `scripts/package.sh` using `--app-drop-link` option
- [x] T099 [P] [US4] Add optional DMG background image support to `scripts/package.sh` with `--background` option
- [x] T100 [P] [US4] Add DMG output to `build/macos/dmg/PastyApp-0.1.0.dmg` in `scripts/package.sh`
- [x] T101 [US4] Create `macos/PastyApp/ExportOptions.plist` for Xcode archive export with signing method
- [x] T102 [US4] Run `./scripts/package.sh release sign` with valid certificate and verify DMG is created
- [x] T103 [US4] Mount generated DMG and verify it shows app icon and Applications shortcut
- [x] T104 [US4] Drag app from DMG to Applications folder and verify it launches without code signing errors
- [x] T105 [US4] Run `./scripts/package.sh release nosign` and verify unsigned DMG works (ad-hoc signing)

**Checkpoint**: All user stories should now be independently functional - complete distribution pipeline working

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Final improvements that affect multiple user stories

- [x] T106 [P] Add comprehensive inline documentation to `core/src/ffi/exports.rs` explaining memory safety and ownership
- [x] T107 [P] Add documentation comments to `macos/PastyApp/src/FFIBridge.swift` explaining FFI calling conventions
- [x] T108 [P] Add help/usage messages to all shell scripts with `-h/--help` flag support
- [x] T109 [P] Add verbose mode support to build scripts with detailed output when VERBOSE=true
- [x] T110 [P] Create `.github/workflows/ci.yml` for CI/CD with build and test automation
- [x] T111 [P] Add README.md at repository root with quickstart link and project overview
- [x] T112 Run full test suite with `./scripts/test-core.sh` and verify ≥80% coverage (SC-006)
- [x] T113 Run complete build from clean state and verify <3 minutes (SC-007)
- [x] T114 Run `./scripts/build.sh` and verify zero manual steps required (SC-002)
- [x] T115 Verify all 8 success criteria from spec.md are met

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Stories (Phase 3-6)**: All depend on Foundational phase completion
  - User Story 1 (P1): Can start after Foundational - No dependencies on other stories
  - User Story 2 (P1): Can start after Foundational - May integrate with US1 but should be independently testable
  - User Story 3 (P2): Can start after Foundational - Must integrate with US1 and US2 FFI/build outputs
  - User Story 4 (P3): Depends on US1-US3 completion - Needs built and signed app
- **Polish (Phase 7)**: Depends on all desired user stories being complete

### User Story Dependencies

- **User Story 1 (P1)**: Foundation - No dependencies, blocks US2-US4
- **User Story 2 (P1)**: Depends on US1 for Rust library - Independent test possible with US1 complete
- **User Story 3 (P2)**: Depends on US1 (FFI) and US2 (build scripts) - Independent test verifies FFI bridge works
- **User Story 4 (P3)**: Depends on US1-US3 - Requires complete app bundle for packaging

### Within Each User Story

- Tests MUST be written and FAIL before implementation (TDD)
- FFI exports before Swift FFIBridge (dependency order)
- Models before services
- Build scripts before app bundle
- Each story has checkpoint task to verify independent functionality

### Parallel Opportunities

- **Setup Phase**: All tasks T001-T009 can run in parallel (different directories)
- **Foundational Phase**: All `[P]` marked tasks (T011, T012, T013, T015-T019, T023, T024, T026-T0035) can run in parallel
- **User Story 1 Tests**: All `[P]` marked test tasks (T036-T041) can run in parallel (different test files)
- **User Story 1 Implementation**: Model tasks (T042-T046) can run in parallel (different files)
- **User Story 2**: All `[P]` marked tasks (T052-T054, T056-T058, T059-T062, T067-T069) can run in parallel
- **User Story 3 Tests**: All `[P]` marked test tasks (T073-T075) can run in parallel
- **User Story 3 Implementation**: FFIBridge tasks (T076-T077), UI tasks (T079-T083), Xcode tasks (T084-T086) can run in parallel within groups
- **User Story 4**: All `[P]` marked tasks (T091-T094, T095-T097, T099-T0100) can run in parallel
- **Polish**: All `[P]` marked tasks (T106-T111) can run in parallel

---

## Parallel Example: User Story 1 Tests

```bash
# Launch all User Story 1 contract tests together:
Task T036: "Write FFI contract test verifying pasty_get_version() returns valid semver"
Task T037: "Write FFI contract test verifying pasty_init() returns 0"
Task T038: "Write FFI contract test verifying pasty_free_string() handles null"

# Launch all User Story 1 model tests together:
Task T040: "Write unit test verifying ClipboardEntry struct instantiation"
Task T041: "Write unit test verifying ContentType enum variants"
```

---

## Parallel Example: User Story 2 Implementation

```bash
# Launch all build-core.sh enhancements together:
Task T052: "Add environment variable detection to build-core.sh"
Task T053: "Add Rust toolchain validation to build-core.sh"
Task T054: "Add Rust target installation to build-core.sh"
Task T056: "Add build artifact copying to build-core.sh"

# Launch all build-macos.sh enhancements together:
Task T059: "Add Rust library validation to build-macos.sh"
Task T060: "Add Xcode project validation to build-macos.sh"
Task T061: "Add build output handling to build-macos.sh"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (T001-T009)
2. Complete Phase 2: Foundational (T010-T035) - CRITICAL BLOCKER
3. Complete Phase 3: User Story 1 (T036-T051)
4. **STOP and VALIDATE**: Test User Story 1 independently
5. Verify: `./scripts/build-core.sh` works, tests pass with ≥80% coverage, documentation generates

**MVP Delivers**: A functional Rust core library with FFI exports that can be reused by future platforms

### Incremental Delivery

1. MVP (above) → User Story 1 complete
2. Add User Story 2 → Test independently → Verify: `./scripts/build.sh` and `./scripts/run.sh` work
3. Add User Story 3 → Test independently → Verify: Menu bar app launches, FFI bridge works
4. Add User Story 4 → Test independently → Verify: DMG packages and installs
5. Each story adds value without breaking previous stories

### Full Delivery (All Stories)

1. Complete all phases sequentially or in dependency order
2. Final polish (Phase 7)
3. Verify all 8 success criteria from spec.md
4. Ready for distribution

---

## Notes

- [P] tasks = different files, no dependencies, safe to parallelize
- [Story] label maps task to specific user story for traceability
- Each user story should be independently completable and testable
- Verify tests fail before implementing (TDD red-green-refactor cycle)
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently
- All tests are REQUIRED per constitution (Test-First Development principle)
- Total tasks: 115 tasks across 7 phases
- Parallel opportunities: ~60 tasks can be parallelized within their phases
- Estimated effort: 2-3 days for MVP (US1), 5-7 days for all stories
