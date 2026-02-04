# Feature Specification: Cross-Platform Framework Infrastructure

**Feature Branch**: `001-rust-swift-framework`
**Created**: 2026-02-04
**Status**: Complete
**Input**: User description: "搭建一个可运行的框架，先完成 core 和 macos；core 使用 rust 开发，主要放跨平台的通用逻辑；平台层/macos 使用 swift 开发，主要放 macos 相关的逻辑；需要有完整的编译脚本、运行脚本、打包脚本、ng 打包成 dmg 格式"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Core Rust Library Foundation (Priority: P1)

Developers can create, build, and run a Rust-based core library that contains cross-platform business logic for the clipboard application.

**Why this priority**: The Rust core is the foundation of the entire cross-platform architecture. All platform-specific layers will depend on this core library, making it the most critical component to establish first.

**Independent Test**: Can be fully tested by building the Rust library with `cargo build`, running unit tests with `cargo test`, and verifying the library compiles successfully on macOS. Delivers a reusable core library that can be imported by other platforms.

**Acceptance Scenarios**:

1. **Given** a fresh project clone, **When** developer runs `./scripts/build-core.sh`, **Then** Rust core library compiles successfully without errors
2. **Given** compiled Rust core library, **When** developer runs `./scripts/test-core.sh`, **Then** all unit tests pass and code coverage report is generated
3. **Given** Rust core library source code, **When** developer inspects the library structure, **Then** it contains modular components for clipboard models, services, and interfaces
4. **Given** the Rust core, **When** developer runs `cargo doc`, **Then** API documentation is generated for all public interfaces

---

### User Story 2 - Build and Run Automation Scripts (Priority: P1)

Developers can build and run the entire application (Rust core + macOS layer) using simple shell scripts that handle all compilation steps correctly.

**Why this priority**: Without automated build and run scripts, developers would need to manually execute complex multi-language build sequences. This story enables developer productivity and ensures reproducible builds.

**Independent Test**: Can be fully tested by executing `./scripts/build.sh` and `./scripts/run.sh` scripts, verifying they compile both Rust and Swift components and launch the application successfully. Delivers a streamlined developer workflow.

**Acceptance Scenarios**:

1. **Given** a fresh project clone, **When** developer runs `./scripts/build.sh`, **Then** both Rust core and macOS Swift layer compile successfully in correct order
2. **Given** built application, **When** developer runs `./scripts/run.sh`, **Then** the macOS application launches and displays a basic window or menu
3. **Given** the build script, **When** developer modifies source code and rebuilds, **Then** only changed components are recompiled (incremental builds work)
4. **Given** build failure, **When** developer runs build scripts, **Then** clear error messages indicate which component failed and why

---

### User Story 3 - macOS Swift Platform Layer (Priority: P2)

Developers can implement macOS-specific functionality in Swift that interfaces with the Rust core library through FFI (Foreign Function Interface) bindings.

**Why this priority**: The macOS layer provides platform-specific features (native UI, system integration, permissions) that wrap the cross-platform Rust core. This builds upon the foundation established in P1 stories.

**Independent Test**: Can be fully tested by building a Swift macOS application that imports and calls functions from the Rust core library, verifying data can be passed between Swift and Rust correctly. Delivers a working macOS application scaffold.

**Acceptance Scenarios**:

1. **Given** compiled Rust core library, **When** Swift code imports the library using FFI, **Then** Swift can successfully call Rust functions and receive return values
2. **Given** the macOS Swift application, **When** it launches, **Then** it displays a native macOS menu bar application with basic menu items
3. **Given** the Swift layer, **When** it needs to access system APIs (clipboard, notifications), **Then** it successfully requests and receives necessary permissions from macOS
4. **Given** data in Rust core, **When** Swift layer retrieves clipboard data, **Then** data is correctly marshaled between Rust and Swift memory spaces

---

### User Story 4 - DMG Packaging and Distribution (Priority: P3)

End users can download and install the macOS application from a distributable DMG (Disk Image) file that contains the signed application bundle.

**Why this priority**: Packaging enables distribution to users. This is lower priority than core functionality because developers can test and run the app during development without DMG packaging.

**Independent Test**: Can be fully tested by running `./scripts/package.sh` and verifying a `.dmg` file is generated that can be mounted, installed, and launched on a clean macOS system. Delivers a distributable application package.

**Acceptance Scenarios**:

1. **Given** a successfully built application, **When** developer runs `./scripts/package.sh`, **Then** a DMG file is created with the application bundle inside
2. **Given** the generated DMG file, **When** user double-clicks it on macOS, **Then** the disk image mounts and shows the application icon with a drag-to-install shortcut
3. **Given** the installed application, **When** user launches it from the DMG or Applications folder, **Then** the application starts without code signing errors
4. **Given** the packaging process, **When** DMG is generated, **Then** it includes necessary assets (icon, background image, license file if applicable)

---

### Edge Cases

- What happens when Rust core compilation fails due to missing dependencies? (Build script should detect and report missing tools clearly)
- How does the system handle version mismatches between Rust and Swift toolchains? (Scripts should check minimum required versions)
- What happens when macOS code signing certificate is missing or expired? (Package script should provide clear error and optional unsigned build)
- How does the build handle architecture differences (x86_64 vs arm64)? (Build scripts should support universal binaries or architecture detection)

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST provide a Rust core library organized into modular components (models, services, interfaces)
- **FR-002**: System MUST include FFI bindings that expose Rust core functions to Swift via C-compatible interface
- **FR-003**: System MUST provide build automation scripts that compile Rust core before macOS Swift layer (correct dependency order)
- **FR-004**: System MUST include a run script that launches the built macOS application with proper environment configuration
- **FR-005**: System MUST provide a packaging script that creates a DMG disk image containing the macOS application bundle
- **FR-006**: Build scripts MUST detect and report missing dependencies (Rust toolchain, Swift, Xcode command-line tools)
- **FR-007**: System MUST support both Debug and Release build configurations
- **FR-008**: macOS application MUST request necessary system permissions (clipboard access, notification permissions) at runtime
- **FR-009**: Build scripts MUST generate build artifacts in organized output directories (separate from source)
- **FR-010**: System MUST include basic logging/error handling in both Rust core and Swift layer
- **FR-011**: DMG packaging script MUST optionally support code signing if certificate is available
- **FR-012**: System MUST provide a basic macOS menu bar application scaffold with at least one functional menu item

### Key Entities

- **Rust Core Library**: Cross-platform business logic including clipboard data models, encryption services, history management interfaces; exposed via C ABI for FFI
- **Swift macOS Layer**: Platform-specific code including native UI (menu bar app), system integration (clipboard monitoring), macOS permissions handling
- **FFI Boundary**: Interface layer between Rust and Swift using C-compatible types; handles data marshaling, memory management, and error propagation
- **Build Scripts**: Automation scripts (build.sh, run.sh, package.sh) that orchestrate multi-language compilation with proper dependency ordering
- **Application Bundle**: macOS .app package containing executable, resources, Info.plist, and code signature
- **DMG Disk Image**: Distributable archive containing the application bundle with installation UI

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Developers can build the entire project from a clean state by running a single command in under 5 minutes
- **SC-002**: Build scripts successfully compile both Rust and Swift components with zero manual steps required
- **SC-003**: Swift layer can successfully call at least 3 different Rust core functions through FFI (demonstrating interoperability)
- **SC-004**: Generated DMG file can be mounted and installed on a clean macOS system and the application launches without errors
- **SC-005**: All build scripts provide clear error messages when dependencies are missing (zero ambiguity about what's required)
- **SC-006**: Unit tests for Rust core achieve at least 80% code coverage and all tests pass in under 30 seconds
- **SC-007**: Complete build (Debug configuration) from clean state completes in under 3 minutes on typical development hardware
- **SC-008**: macOS application displays a functional menu bar with at least "Quit" and "About" menu items working correctly

## Assumptions

- Development is targeting macOS 11 (Big Sur) or later as minimum supported version
- Rust toolchain version 1.70 or later is available
- Xcode 14 or later (or Swift command-line tools) is installed
- Development machine has macOS operating system (initial implementation is macOS-only per user request)
- Code signing certificate is optional for development builds but recommended for distribution
- Project will use Cargo (Rust) and Swift Package Manager or Xcode build system
- FFI boundary will use standard C types (primitive types, C strings) for maximum compatibility
- Application will initially be a menu bar app (status bar app) rather than a full windowed application
