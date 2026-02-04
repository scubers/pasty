# Implementation Plan: Cross-Platform Framework Infrastructure

**Branch**: `001-rust-swift-framework` | **Date**: 2026-02-04 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/001-rust-swift-framework/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/commands/plan.md` for the execution workflow.

## Summary

Build a runnable cross-platform framework with Rust core library and Swift macOS platform layer, including complete build/run/packaging automation scripts and DMG distribution. The framework establishes the foundation for Pasty clipboard app with platform-agnostic business logic in Rust (models, services, interfaces) and platform-specific implementation in Swift (menu bar UI, system integration, FFI bindings).

## Technical Context

**Language/Version**: Rust 1.70+ (core), Swift 5.9+ (macOS layer)
**Primary Dependencies**:
- Rust: serde (serialization), thiserror (error handling), cbindgen (C header generation)
- Swift: SwiftUI (UI), Foundation (system integration), Xcode build tools
- Build: Cargo (Rust), Xcodebuild / Swift Package Manager (Swift), hdiutil (DMG creation)

**Storage**:
- Development: Local file system (build artifacts in `target/` and `build/` directories)
- Runtime: Platform-appropriate local storage (to be implemented in future features)

**Testing**: Cargo test (Rust unit tests), XCTest (Swift tests - future scope)
**Target Platform**: macOS 11+ (Big Sur or later), both x86_64 and arm64 (Apple Silicon)
**Project Type**: Multi-language framework (Rust core + Swift macOS application)
**Performance Goals**:
- Clean build time: < 3 minutes (SC-007)
- Incremental build: < 30 seconds
- Test execution: < 30 seconds for 80% coverage (SC-006)
- Startup time: < 2 seconds for menu bar app launch

**Constraints**:
- Must support both Debug and Release configurations
- Must detect and validate Rust toolchain, Swift, and Xcode versions before build
- Must support universal binaries (x86_64 + arm64) or architecture-specific builds
- Build scripts must have zero manual steps (SC-002)
- Must provide clear error messages for missing dependencies (SC-005)

**Scale/Scope**: Framework infrastructure only (no clipboard features yet)
- ~5-10 Rust modules (models, services, FFI layer)
- ~3-5 Swift files (app delegate, menu bar UI, FFI bridge)
- ~5 shell scripts (build-core.sh, build-macos.sh, build.sh, run.sh, package.sh)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### Pre-Design Evaluation

**I. User Story Priority**: ✅ PASS
- US1 (P1): Core Rust Library - independently testable, delivers reusable library
- US2 (P1): Build/Run Scripts - independently testable, delivers developer workflow
- US3 (P2): macOS Swift Layer - depends on P1, independently testable FFI bridge
- US4 (P3): DMG Packaging - depends on P1-P3, independently testable distribution

**II. Test-First Development**: ✅ PASS (with notes)
- US1 explicitly requires unit tests with 80% coverage (SC-006)
- TDD will be enforced during implementation phase
- Test scripts (build-core.sh, test-core.sh) included in P1 scope

**III. Documentation Before Implementation**: ✅ PASS
- Spec approved with all mandatory sections
- This plan (plan.md) being generated before tasks.md
- Design artifacts (research.md, data-model.md, contracts/, quickstart.md) will be generated

**IV. Simplicity & YAGNI**: ⚠️ VIOLATION (requires justification)
- **Violation**: Dual-language architecture (Rust + Swift) with FFI boundary
- **Complexity**: Must maintain two build systems, memory management across FFI, type marshaling
- **Justification**: See Complexity Tracking table below

**V. Cross-Platform Compatibility**: ✅ PASS
- Core logic in platform-agnostic Rust (Principle V compliant)
- Platform-specific code isolated in Swift/macOS layer
- FFI boundary follows C ABI for maximum future compatibility
- Aligned with constitution Platform Support Matrix

**VI. Privacy & Security First**: ✅ PASS
- Framework infrastructure only - no clipboard data handling yet
- Will establish encryption interfaces for future clipboard features
- Code signing support for DMG distribution (security best practice)

### Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| Dual-language architecture (Rust + Swift with FFI) | User explicitly requested Rust for cross-platform core and Swift for macOS-native UI. Rust provides memory safety, performance, and cross-platform compilation. Swift provides native macOS integration (menu bar, permissions, system APIs). Alternative: Single-language (Rust-only or Swift-only) would sacrifice either cross-platform portability or native macOS user experience. | Pure Swift would lack Linux/Windows support in future. Pure Rust would require complex macOS UI bindings and lose native menu bar simplicity. Dual approach with FFI leverages strengths of both ecosystems. |
| Multi-build-system orchestration | Rust uses Cargo, Swift uses Xcode/SPM. Must coordinate compilation order (Rust first, then Swift) and ensure binary compatibility. | Single build system would require abandoning one toolchain, violating user's explicit technology requirements. |
| FFI boundary with C types | Required to bridge Rust and Swift memory spaces. Must handle string conversion, error propagation, and memory safety across languages. | Direct memory sharing would be unsafe and violate Rust's ownership guarantees. IPC/message passing would add unnecessary complexity for same-process architecture. |

### Post-Design Evaluation

**Re-evaluation after Phase 1**: ✅ CONFIRMED MANAGEABLE

After completing research (research.md) and design (data-model.md, contracts/), the FFI complexity is confirmed to be manageable:

**Evidence**:
1. **cbindgen automation**: Automatic C header generation eliminates manual synchronization errors
2. **Clear ownership semantics**: Rust allocates, Swift frees with `pasty_free_string()` - no ambiguity
3. **Minimal FFI surface**: Only 4 core functions in this feature (init, shutdown, version, free_string)
4. **Standard patterns**: C strings, integer error codes - well-documented in FFI API contract
5. **Type-safe Swift wrapper**: FFIBridge class provides safe Swift interface, hiding unsafe C details

**Conclusion**: The dual-language complexity is justified and manageable. The FFI boundary is minimal, well-documented, and follows established patterns from Mozilla (cbindgen) and the Rust-Swift interoperability community.

**All Constitution Principles**: ✅ PASS

## Project Structure

### Documentation (this feature)

```text
specs/001-rust-swift-framework/
├── spec.md              # Feature specification (already created)
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output (research on FFI patterns, build tools)
├── data-model.md        # Phase 1 output (Rust core entities, FFI interface)
├── quickstart.md        # Phase 1 output (developer setup instructions)
├── contracts/           # Phase 1 output (FFI API contract, build script interface)
│   ├── ffi-api.md       # Rust-Swift FFI interface specification
│   └── build-interface.md  # Build script command-line interface
└── tasks.md             # Phase 2 output (/speckit.tasks command - NOT created by /speckit.plan)
```

### Source Code (repository root)

```text
.
├── core/                    # Rust core library (platform-agnostic)
│   ├── Cargo.toml           # Rust package manifest
│   ├── cbindgen.toml        # C header generation config
│   └── src/
│       ├── lib.rs           # Library root with FFI exports
│       ├── models/          # Data models (clipboard entries, history)
│       │   ├── mod.rs
│       │   └── clipboard_entry.rs
│       ├── services/        # Business logic (encryption, history management)
│       │   ├── mod.rs
│       │   └── encryption.rs
│       └── ffi/             # C-compatible FFI layer
│           ├── mod.rs
│           └── exports.rs    # Public C API for Swift
│
├── macos/                   # Swift macOS application (platform-specific)
│   ├── PastyApp/            # Xcode project or Swift Package
│   │   ├── Info.plist
│   │   └── src/
│   │       ├── main.swift           # Application entry point
│   │       ├── AppDelegate.swift    # NSApplicationDelegate
│   │       ├── MenuBarManager.swift # Menu bar UI management
│   │       └── FFIBridge.swift      # Swift wrapper for Rust FFI calls
│   └── PastyApp.entitlements       # macOS permissions entitlements
│
├── scripts/                 # Build automation scripts
│   ├── build-core.sh        # Build Rust core library
│   ├── build-macos.sh       # Build Swift macOS app
│   ├── build.sh             # Orchestrate full build (Rust + macOS)
│   ├── run.sh               # Launch built application
│   ├── package.sh           # Create DMG distribution
│   ├── check-prereqs.sh     # Validate dependencies (Rust, Xcode, etc.)
│   └── common.sh            # Shared script utilities
│
├── build/                   # Build output directory (gitignored)
│   ├── core/                # Rust build artifacts
│   │   ├── debug/           # Debug builds
│   │   ├── release/         # Release builds
│   │   └── include/         # Generated C headers
│   └── macos/               # macOS build artifacts
│       ├── PastyApp.app     # Application bundle
│       └── dmg/             # DMG packaging output
│
├── tests/                   # Test suites (following constitution structure)
│   ├── contract/            # FFI API contract tests (future)
│   ├── integration/         # Cross-language tests (future)
│   └── unit/                # Rust unit tests in core/tests/
│
└── .specify/                # Project specification templates and memory
```

**Structure Decision**: Dual-directory structure (core/ + macos/) reflects the multi-language architecture mandated by the user. The Rust core in `core/` follows standard Cargo layout, enabling easy testing and future expansion to other platforms. The Swift macOS app in `macos/` follows Xcode/SPM conventions, enabling native macOS integration. Build orchestration in `scripts/` coordinates both languages. The `build/` directory separates artifacts from source, matching FR-009.

## Phase 0: Research (COMPLETE)

**Status**: ✅ COMPLETE - See research.md

All 8 research questions have been resolved:

1. ✅ **Rust-Swift FFI**: cbindgen with manual C header oversight
2. ✅ **String Marshaling**: C strings with ownership transfer (`CString::into_raw()`, `pasty_free_string()`)
3. ✅ **Build Orchestration**: Shell script wrapper with Xcode Run Script integration
4. ✅ **Universal Binary Support**: Per-architecture build + lipo combination
5. ✅ **DMG Creation**: create-dmg tool with code signing workflow
6. ✅ **Code Signing**: Deep signing with certificate detection
7. ✅ **Menu Bar UI**: AppKit NSStatusBar (future: SwiftUI for settings)
8. ✅ **Testing**: Rust unit tests now, integration tests later

Key decisions:
- cbindgen for automatic C header generation
- Shell scripts for build orchestration (flexible, CI/CD friendly)
- create-dmg for professional DMG packaging
- AppKit for menu bar UI (proven, reliable)

## Phase 1: Design (COMPLETE)

**Status**: ✅ COMPLETE

All design artifacts have been created:

### Data Model (data-model.md)
- ✅ Rust core entities defined: ClipboardEntry, ClipboardHistory, EncryptionService trait
- ✅ FFI exports specified: init, shutdown, version, free_string, error handling
- ✅ Swift FFIBridge wrapper structure defined
- ✅ Memory ownership semantics clearly documented

### Contracts (contracts/)
- ✅ **ffi-api.md**: Complete FFI API contract with function signatures, calling conventions, error handling
- ✅ **build-interface.md**: Build script CLI interface with exit codes, environment variables, output formats

### Quickstart Guide (quickstart.md)
- ✅ Developer onboarding instructions
- ✅ Prerequisites and installation
- ✅ Build/run/test workflows
- ✅ Troubleshooting guide

### Agent Context Updated
- ✅ Claude Code context file (CLAUDE.md) updated with Rust 1.70+, Swift 5.9+ technology stack

## Phase 2: Task Generation (NEXT)

**Ready for**: `/speckit.tasks`

All planning artifacts are complete. The next phase will generate tasks.md with:
- Phase 1: Setup (project structure, Cargo.toml, cbindgen.toml)
- Phase 2: Foundational (Rust FFI exports, Swift FFIBridge, build scripts)
- Phase 3: User Story 1 (P1) - Core Rust Library
- Phase 4: User Story 2 (P1) - Build/Run Scripts
- Phase 5: User Story 3 (P2) - macOS Swift Layer
- Phase 6: User Story 4 (P3) - DMG Packaging

Tasks will be organized by user story to enable independent implementation and testing per the constitution.

---

## Planning Summary

**Duration**: Phase 0 and Phase 1 completed
**Artifacts Generated**: 6 files (research.md, data-model.md, 2 contracts, quickstart.md, CLAUDE.md)
**Constitution Check**: ✅ PASS (all principles satisfied with justified complexity)
**Decision Confidence**: HIGH - All technical unknowns resolved, design validated

**Ready for Implementation**: YES

Run `/speckit.tasks` to generate the task breakdown.
