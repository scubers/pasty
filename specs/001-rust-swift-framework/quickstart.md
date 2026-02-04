# Quickstart Guide: Pasty Cross-Platform Framework

**Last Updated**: 2026-02-04
**Target Audience**: Developers joining the Pasty project
**Prerequisites**: macOS 11+ (Big Sur or later)

This guide will get you set up and running with the Pasty clipboard app framework in under 10 minutes.

---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Installation](#installation)
3. [Building the Project](#building-the-project)
4. [Running the Application](#running-the-application)
5. [Running Tests](#running-tests)
6. [Development Workflow](#development-workflow)
7. [Troubleshooting](#troubleshooting)
8. [Next Steps](#next-steps)

---

## Prerequisites

Before you begin, ensure you have the following installed:

### Required Tools

| Tool | Minimum Version | How to Install |
|------|-----------------|----------------|
| **Rust** | 1.70+ | `curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \| sh` |
| **Xcode** | 14+ | Download from Mac App Store |
| **Command Line Tools** | - | `xcode-select --install` |

### Optional Tools

| Tool | Purpose | How to Install |
|------|---------|----------------|
| **create-dmg** | DMG packaging (for distribution) | `brew install create-dmg` |
| **tarpaulin** | Test coverage (for development) | `cargo install cargo-tarpaulin` |

---

## Installation

### 1. Clone the Repository

```bash
git clone https://github.com/your-org/pasty.git
cd pasty
```

### 2. Verify Prerequisites

Run the prerequisite checker to ensure your environment is set up:

```bash
./scripts/check-prereqs.sh
```

Expected output:
```
[INFO] Checking prerequisites...
[INFO] ✓ Rust 1.75.0 found (required: ≥1.70.0)
[INFO] ✓ Xcode 15.0 found (required: ≥14.0)
[INFO] ✓ Swift 5.9 found (required: ≥5.9)
[INFO] ✓ create-dmg found (optional)
[INFO] All prerequisites met!
```

If any tools are missing, the script will provide installation instructions.

---

## Building the Project

### Quick Build (Release)

Build the entire project with a single command:

```bash
./scripts/build.sh release
```

This will:
1. Check prerequisites
2. Build the Rust core library (universal binary for x86_64 + arm64)
3. Generate the C header (FFI bridge)
4. Build the Swift macOS app
5. Link everything together

Expected time: ~2-3 minutes on a modern Mac

**Output**:
```
[INFO] Starting build process...
[INFO] Configuration: release
[INFO] Architecture: universal

[STEP] Checking prerequisites...
[INFO] ✓ All prerequisites met

[STEP] Building Rust core library...
[INFO] ✓ Core library built: build/core/universal/release/libcore.a

[STEP] Building macOS app...
[INFO] ✓ App built: build/macos/PastyApp.app

[INFO] ✓ Build completed successfully!
```

### Debug Build

For development, build a debug version (faster compilation, more logging):

```bash
./scripts/build.sh debug
```

### Clean Build

Start from scratch (remove all previous build artifacts):

```bash
./scripts/build.sh release clean
```

### Architecture-Specific Build

Build for a single architecture (faster for testing):

```bash
./scripts/build.sh release noclean arm64   # Apple Silicon only
./scripts/build.sh release noclean x86_64  # Intel only
```

---

## Running the Application

### Launch the App

After building, launch the application:

```bash
./scripts/run.sh release
```

Or open it directly:
```bash
open build/macos/PastyApp.app
```

### What to Expect

When the app launches:
1. A menu bar icon appears in the top-right menu bar
2. Click the icon to see the menu (currently has "Quit" and "About" items)
3. The app is functional but clipboard features are not implemented yet (coming in future features)

---

## Running Tests

### Run All Rust Core Tests

```bash
./scripts/test-core.sh
```

This runs all unit tests in the Rust core library with coverage reporting.

**Output**:
```
[INFO] Running Rust unit tests...
running 12 tests
test ffi::tests::test_version ... ok
test ffi::tests::test_init_shutdown ... ok
...

test result: ok. 12 passed; 0 failed; 0 ignored

[INFO] Coverage: 84.5%
[INFO] ✓ All tests passed!
```

### Run Specific Tests

```bash
cd core
cargo test ffi::tests
cargo test models::tests
```

### View Coverage Report

If `cargo-tarpaulin` is installed, coverage reports are generated at:
```
build/core/coverage/index.html
```

Open in a browser:
```bash
open build/core/coverage/index.html
```

---

## Development Workflow

### Typical Development Session

1. **Make changes** to Rust core or Swift code
2. **Rebuild** with `./scripts/build.sh debug` (fast incremental builds)
3. **Run tests** with `./scripts/test-core.sh`
4. **Launch app** with `./scripts/run.sh debug`
5. **Iterate**

### Building Only the Rust Core

If you're only working on the Rust core:

```bash
./scripts/build-core.sh debug
```

### Building Only the macOS App

If you're only working on the Swift layer (after Rust changes are done):

```bash
./scripts/build-macos.sh debug
```

### Xcode Integration

For Swift UI development, use Xcode:

```bash
open macos/PastyApp.xcodeproj
```

**Important**: The Xcode project includes a Run Script phase that automatically builds the Rust core before each Swift build. You don't need to manually run `build-core.sh` when working in Xcode.

---

## Project Structure

```
pasty/
├── core/                  # Rust core library
│   ├── src/
│   │   ├── lib.rs        # Library root
│   │   ├── models/       # Data models
│   │   ├── services/     # Business logic
│   │   └── ffi/          # FFI exports
│   ├── tests/            # Rust unit tests
│   ├── Cargo.toml
│   └── cbindgen.toml     # C header generation config
│
├── macos/                 # Swift macOS app
│   ├── PastyApp/
│   │   ├── src/
│   │   │   ├── main.swift
│   │   │   ├── AppDelegate.swift
│   │   │   ├── MenuBarManager.swift
│   │   │   └── FFIBridge.swift
│   │   ├── Info.plist
│   │   └── PastyApp.entitlements
│   └── PastyApp.xcodeproj
│
├── scripts/               # Build automation
│   ├── build-core.sh
│   ├── build-macos.sh
│   ├── build.sh
│   ├── run.sh
│   ├── package.sh
│   ├── test-core.sh
│   ├── check-prereqs.sh
│   └── common.sh
│
├── build/                 # Build output (gitignored)
│   ├── core/
│   │   ├── include/      # Generated C headers
│   │   └── universal/    # Rust static libraries
│   └── macos/
│       ├── PastyApp.app  # macOS app bundle
│       └── dmg/          # DMG packages
│
└── specs/                 # Feature specifications
    └── 001-rust-swift-framework/
        ├── spec.md
        ├── plan.md
        ├── research.md
        ├── data-model.md
        ├── quickstart.md
        └── contracts/
```

---

## Troubleshooting

### Build Failures

**Issue**: `error: Rust toolchain not found`
```bash
# Solution: Install Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source $HOME/.cargo/env
```

**Issue**: `error: linker 'cc' not found`
```bash
# Solution: Install Xcode command line tools
xcode-select --install
```

**Issue**: `error: target not found: x86_64-apple-darwin`
```bash
# Solution: Install the target
rustup target add x86_64-apple-darwin
rustup target add aarch64-apple-darwin
```

### Code Signing Issues

**Issue**: `error: code signing failed`
```bash
# Solution: Build without signing (for development)
./scripts/package.sh debug nosign
```

Or set up a code signing certificate:
1. Open Xcode → Preferences → Accounts
2. Add your Apple ID
3. Xcode will manage a free development certificate

### App Won't Launch

**Issue**: App crashes immediately on launch
```bash
# Check system log
log show --predicate 'processImagePath contains "Pasty"' --last 5m

# Run from terminal to see output
./build/macos/PastyApp.app/Contents/MacOS/pasty
```

---

## Creating a Distributable DMG

When you're ready to distribute the app:

```bash
# Build release version
./scripts/build.sh release

# Create DMG (with code signing if certificate available)
./scripts/package.sh release sign
```

The DMG will be created at:
```
build/macos/dmg/PastyApp-0.1.0.dmg
```

**Unsigned builds** (for testing):
```bash
./scripts/package.sh release nosign
```

---

## Next Steps

Now that you have the framework set up, here's what you can do:

### Learn the Architecture

- Read the [implementation plan](plan.md) for architecture overview
- Review the [data model](data-model.md) to understand core entities
- Study the [FFI API contract](contracts/ffi-api.md) for Rust-Swift bridging

### Contribute Features

Check for open features in the `specs/` directory or create a new one:

```bash
/speckit.specify "Add clipboard history feature"
```

### Implement Clipboard Features

The framework is ready for clipboard features:
- System clipboard monitoring
- History management
- Encryption
- Search functionality

See the constitution (`.specify/memory/constitution.md`) for development principles.

---

## Getting Help

- **Documentation**: Check `specs/` directory for feature specs
- **Issues**: Open a GitHub issue for bugs or feature requests
- **Constitution**: Review `.specify/memory/constitution.md` for project principles

---

## Summary

You should now have:
- ✅ A fully built Pasty framework (Rust core + Swift UI)
- ✅ A running macOS menu bar app
- ✅ Passing unit tests with coverage
- ✅ Understanding of the build system and project structure

**You're ready to start developing clipboard features!**

For more details, see:
- [Implementation Plan](plan.md)
- [Data Model](data-model.md)
- [FFI API Contract](contracts/ffi-api.md)
- [Build Script Interface](contracts/build-interface.md)
