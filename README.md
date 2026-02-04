# Pasty - Cross-Platform Clipboard Manager

A modern, privacy-focused clipboard manager built with Rust (core) and native platform layers (Swift for macOS).

## Status

This is the initial framework implementation. Clipboard features are coming soon.

## Quick Start

### Prerequisites

- **Rust** 1.70 or later - Install from https://rustup.rs/
- **Xcode** 14 or later - Install from Mac App Store
- **Swift** 5.9 or later - Installed with Xcode
- **cbindgen** - Install with: `cargo install cbindgen`
- **create-dmg** (optional, for packaging) - Install with: `brew install create-dmg`

### Setup

1. Clone the repository:
```bash
git clone <repository-url>
cd pasty
```

2. Verify prerequisites:
```bash
./scripts/check-prereqs.sh
```

3. Build the Rust core library:
```bash
./scripts/build.sh release
```

This will:
- Build the Rust core as a universal static library (x86_64 + arm64)
- Generate the C header file for FFI
- Output artifacts to `build/core/universal/release/`

### Running Tests

Run the Rust unit tests:
```bash
./scripts/test-core.sh
```

## Project Structure

```
pasty/
├── core/                  # Rust core library (platform-agnostic)
│   ├── src/
│   │   ├── models/       # Data models (ClipboardEntry, ClipboardHistory)
│   │   ├── services/     # Business logic (EncryptionService)
│   │   └── ffi/          # FFI exports for Swift
│   ├── Cargo.toml
│   └── cbindgen.toml
├── macos/                 # Swift macOS app (platform-specific)
│   └── PastyApp/
│       ├── src/
│       │   ├── main.swift
│       │   ├── AppDelegate.swift
│       │   └── FFIBridge.swift
│       ├── Info.plist
│       └── PastyApp.entitlements
├── scripts/               # Build automation scripts
│   ├── build-core.sh    # Build Rust library
│   ├── build.sh         # Main orchestrator
│   ├── run.sh           # Launch app
│   ├── test-core.sh     # Run tests
│   └── check-prereqs.sh # Validate environment
├── build/                # Build artifacts (gitignored)
└── specs/                # Feature specifications
```

## Architecture

Pasty uses a dual-language architecture:

- **Rust Core**: Platform-agnostic business logic, data models, and services
- **Swift macOS Layer**: Native macOS UI, system integration, and platform-specific features
- **FFI Boundary**: C ABI interface using cbindgen for automatic header generation

This design enables:
- ✅ Cross-platform code reuse (Rust core works on Windows/Linux too)
- ✅ Native platform feel (Swift for macOS, could use C++ for Windows)
- ✅ Memory safety (Rust's ownership system)
- ✅ Performance (zero-copy FFI where possible)

## Development

### Building the Rust Core

```bash
# Debug build (faster)
./scripts/build-core.sh debug

# Release build (optimized)
./scripts/build-core.sh release

# Single architecture (for testing)
./scripts/build-core.sh release arm64    # Apple Silicon only
./scripts/build-core.sh release x86_64   # Intel only

# Universal binary (both architectures)
./scripts/build-core.sh release universal
```

### Running Tests

```bash
./scripts/test-core.sh
```

With coverage (requires cargo-tarpaulin):
```bash
cargo install cargo-tarpaulin
./scripts/test-core.sh
```

## Current Implementation (User Story 1 & 2)

### ✅ Completed
- Rust core library structure with models and services
- FFI exports: `pasty_init()`, `pasty_shutdown()`, `pasty_get_version()`, `pasty_free_string()`
- Error handling with thread-local storage
- Placeholder clipboard functions (to be implemented in future features)
- Build automation scripts for Rust core
- Unit tests for FFI and data models

### 🔨 In Progress
- Swift macOS app scaffold (User Story 3)
- Xcode project setup
- Menu bar UI implementation

### 📋 Planned (Future Features)
- Clipboard monitoring and history
- Search and filtering
- Encryption for sensitive data
- Cross-platform support (Windows, Linux)

## Troubleshooting

### Rust not found
```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source $HOME/.cargo/env
```

### Xcode not found
```bash
xcode-select --install
```

### cbindgen not found
```bash
cargo install cbindgen
```

### Build fails
Run the prerequisite checker:
```bash
./scripts/check-prereqs.sh
```

## Constitution

This project follows the Pasty Constitution defined in `.specify/memory/constitution.md`:

1. **User Story Priority** - Features prioritized as P1, P2, P3...
2. **Test-First Development** - TDD mandatory with red-green-refactor cycle
3. **Documentation Before Implementation** - All design artifacts complete before coding
4. **Simplicity & YAGNI** - Only implement what's needed now
5. **Cross-Platform Compatibility** - Platform-agnostic core with isolated platform layers
6. **Privacy & Security First** - Local-only storage, encryption, no telemetry

## License

[To be determined]

## Contributing

[To be determined]

## Roadmap

See `specs/001-rust-swift-framework/` for the implementation plan and task breakdown.
