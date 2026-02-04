# Build Script Interface Contract

**Feature**: 001-rust-swift-framework
**Version**: 1.0.0
**Date**: 2026-02-04

This document specifies the command-line interface and behavior for all build automation scripts in the framework.

---

## Overview

The build system consists of the following scripts:

| Script | Purpose | Dependencies |
|--------|---------|--------------|
| `check-prereqs.sh` | Validate development environment | None |
| `build-core.sh` | Build Rust core library | Rust toolchain |
| `build-macos.sh` | Build Swift macOS app | Rust library, Xcode |
| `build.sh` | Orchestrate full build | All above |
| `run.sh` | Launch built application | Successful build |
| `package.sh` | Create DMG distribution | Signed app bundle |
| `test-core.sh` | Run Rust unit tests | Rust toolchain |

---

## Common Conventions

### Exit Codes
All scripts use standard exit codes:
- `0`: Success
- `1`: General error
- `2`: Usage error (invalid arguments)
- `3`: Missing prerequisite
- `4`: Build failure

### Output Formatting
- **Info**: `[INFO]` prefix (green)
- **Warning**: `[WARN]` prefix (yellow)
- **Error**: `[ERROR]` prefix (red)
- **Step**: `[STEP]` prefix (blue)

### Environment Variables
Scripts respect these environment variables:
- `CONFIGURATION`: `Debug` or `Release` (default: `Release`)
- `ARCH`: `x86_64`, `arm64`, or `universal` (default: `universal`)
- `CLEAN`: Set to `true` to clean before build (default: `false`)
- `VERBOSE`: Set to `true` for verbose output (default: `false`)
- `PROJECT_ROOT`: Project root directory (auto-detected if not set)

### Directory Structure
All scripts assume this structure:
```
$PROJECT_ROOT/
├── core/              # Rust library
├── macos/             # Swift app
├── scripts/           # Build scripts
└── build/             # Build output (gitignored)
    ├── core/          # Rust artifacts
    └── macos/         # macOS artifacts
```

---

## check-prereqs.sh

Validate that all required tools are installed and meet minimum versions.

### Usage
```bash
./scripts/check-prereqs.sh
```

### Arguments
None

### Validations

| Tool | Check | Minimum Version | Install URL |
|------|-------|-----------------|-------------|
| `rustc` | Exists and version ≥ 1.70 | 1.70.0 | https://rustup.rs/ |
| `cargo` | Exists | - | (installed with rustc) |
| `xcodebuild` | Exists | Xcode 14+ | Mac App Store |
| `swift` | Exists | 5.9+ | (installed with Xcode) |
| `hdiutil` | Exists | - | (built-in) |
| `create-dmg` | Exists (optional) | - | `brew install create-dmg` |

### Exit Codes
- `0`: All prerequisites met
- `3`: One or more prerequisites missing

### Output Format
```
[INFO] Checking prerequisites...
[INFO] ✓ Rust 1.75.0 found (required: ≥1.70.0)
[INFO] ✓ Xcode 15.0 found (required: ≥14.0)
[INFO] ✓ Swift 5.9 found (required: ≥5.9)
[INFO] ✓ create-dmg found (optional)
[INFO] All prerequisites met!
```

---

## build-core.sh

Build the Rust core library for specified architecture and configuration.

### Usage
```bash
./scripts/build-core.sh [debug|release] [x86_64|arm64|universal]
```

### Arguments
| Position | Name | Values | Default |
|----------|------|--------|---------|
| 1 | Build type | `debug`, `release` | `release` |
| 2 | Architecture | `x86_64`, `arm64`, `universal` | `universal` |

### Environment Variables
- `CLEAN`: If `true`, run `cargo clean` before building
- `CARGO_FLAGS`: Additional flags to pass to `cargo`
- `RUSTFLAGS`: Additional Rust compiler flags

### Output Artifacts
```
build/core/
├── include/              # Generated C headers
│   └── pasty.h          # cbindgen output
└── universal/            # Universal binaries
    ├── debug/
    │   └── libcore.a    # Debug static library
    └── release/
        └── libcore.a    # Release static library
```

### Build Process
1. Validate Rust toolchain
2. Install Rust targets if needed (x86_64-apple-darwin, aarch64-apple-darwin)
3. If `universal`, build both architectures separately
4. Combine architectures with `lipo` (if universal)
5. Generate C header with cbindgen
6. Copy artifacts to `build/core/`

### Exit Codes
- `0`: Build succeeded
- `3`: Rust toolchain not found
- `4`: Cargo build failed

### Output Format
```
[INFO] Building Rust core library...
[INFO] Rust version: 1.75.0
[INFO] Target: universal (x86_64 + arm64)
[INFO] Configuration: release
[STEP] Building x86_64-apple-darwin...
   Compiling core v0.1.0
[STEP] Building aarch64-apple-darwin...
   Compiling core v0.1.0
[STEP] Creating universal binary...
[INFO] Generating C header with cbindgen...
[INFO] ✓ Core library built: build/core/universal/release/libcore.a
[INFO] ✓ C header generated: build/core/include/pasty.h
```

---

## build-macos.sh

Build the Swift macOS app, linking against the Rust core library.

### Usage
```bash
./scripts/build-macos.sh [debug|release]
```

### Arguments
| Position | Name | Values | Default |
|----------|------|--------|---------|
| 1 | Build type | `debug`, `release` | `release` |

### Environment Variables
- `XCODE_BUILD_FLAGS`: Additional flags for `xcodebuild`
- `DERIVED_DATA_PATH`: Custom derived data location

### Output Artifacts
```
build/macos/
└── PastyApp.app/         # macOS app bundle
    ├── Contents/
    │   ├── MacOS/
    │   │   └── pasty    # Executable
    │   ├── Resources/
    │   │   └── ...      # Assets, icons
    │   └── Info.plist
```

### Build Process
1. Validate Rust library exists at `build/core/universal/$CONFIG/libcore.a`
2. Locate Xcode project
3. Run `xcodebuild` with appropriate scheme and configuration
4. Copy .app bundle to `build/macos/`

### Exit Codes
- `0`: Build succeeded
- `3`: Rust library not found
- `4`: Xcode build failed

### Output Format
```
[INFO] Building macOS app...
[INFO] Rust library found: build/core/universal/release/libcore.a
[INFO] Xcode project: macos/PastyApp.xcodeproj
[STEP] Building with Xcode...
Build settings from command line:
    CONFIGURATION = Release
    ARCHS = x86_64 arm64
** BUILD SUCCEEDED **
[INFO] ✓ App built: build/macos/PastyApp.app
```

---

## build.sh

Main build orchestrator. Builds Rust core, then Swift macOS app.

### Usage
```bash
./scripts/build.sh [debug|release] [clean] [arch]
```

### Arguments
| Position | Name | Values | Default |
|----------|------|--------|---------|
| 1 | Build type | `debug`, `release` | `release` |
| 2 | Clean build | `clean`, `noclean` | `noclean` |
| 3 | Architecture | `x86_64`, `arm64`, `universal` | `universal` |

### Environment Variables
- All variables from `build-core.sh` and `build-macos.sh`

### Build Process
1. Parse arguments
2. Run `check-prereqs.sh`
3. If `clean`, run `cargo clean`
4. Run `build-core.sh $CONFIG $ARCH`
5. Run `build-macos.sh $CONFIG`
6. Display build summary

### Exit Codes
- `0`: Full build succeeded
- `3`: Prerequisites check failed
- `4`: Core or macOS build failed

### Output Format
```
[INFO] Starting build process...
[INFO] Configuration: release
[INFO] Architecture: universal
[INFO] Clean: noclean

[STEP] Checking prerequisites...
[INFO] ✓ All prerequisites met

[STEP] Building Rust core library...
[INFO] ✓ Core library built

[STEP] Building macOS app...
[INFO] ✓ App built

[INFO] Build Summary:
  Configuration: release
  Architecture: universal
  Duration: 2m 34s

Build Artifacts:
  build/core/universal/release/libcore.a
  build/core/include/pasty.h
  build/macos/PastyApp.app

[INFO] ✓ Build completed successfully!
```

---

## run.sh

Launch the built macOS application.

### Usage
```bash
./scripts/run.sh [debug|release]
```

### Arguments
| Position | Name | Values | Default |
|----------|------|--------|---------|
| 1 | Build type | `debug`, `release` | `debug` |

### Environment Variables
- `RUN_ARGS`: Arguments to pass to the application

### Behavior
1. Check if app exists at `build/macos/PastyApp.app`
2. If not found, offer to build it first
3. Launch app with `open` command
4. Monitor app output (if in terminal)

### Exit Codes
- `0`: App launched successfully
- `4`: App bundle not found

### Output Format
```
[INFO] Launching PastyApp...
[INFO] Configuration: debug
[INFO] Executable: build/macos/PastyApp.app
[INFO] ✓ App launched (PID: 12345)
```

---

## package.sh

Create a DMG disk image from the built application.

### Usage
```bash
./scripts/package.sh [debug|release] [sign|nosign]
```

### Arguments
| Position | Name | Values | Default |
|----------|------|--------|---------|
| 1 | Build type | `debug`, `release` | `release` |
| 2 | Code signing | `sign`, `nosign` | `sign` |

### Environment Variables
- `SIGNING_IDENTITY`: Override auto-detected signing identity
- `DMG_BACKGROUND`: Path to DMG background image
- `DMG_ICON`: Path to custom DMG icon

### Output Artifacts
```
build/macos/dmg/
└── PastyApp-0.1.0.dmg    # Distributable disk image
```

### Packaging Process
1. Validate app bundle exists
2. Detect code signing certificate (if signing enabled)
3. Sign app bundle with `codesign --force --deep`
4. Create DMG with `create-dmg`
5. Optionally notarize (if Developer ID available)

### Exit Codes
- `0`: Packaging succeeded
- `3`: Prerequisites missing (create-dmg, app bundle)
- `4`: Code signing failed
- `5**: DMG creation failed

### Output Format
```
[INFO] Creating DMG package...
[INFO] Configuration: release
[INFO] Signing: enabled
[STEP] Detecting code signing certificate...
[INFO] Found: Developer ID Application: Your Name (TEAMID)
[STEP] Signing app bundle...
[INFO] ✓ App signed successfully
[STEP] Creating DMG with create-dmg...
[INFO] ✓ DMG created: build/macos/dmg/PastyApp-0.1.0.dmg
[INFO] Package size: 15.2 MB
[INFO] ✓ Package completed successfully!
```

---

## test-core.sh

Run Rust unit tests with coverage reporting.

### Usage
```bash
./scripts/test-core.sh
```

### Arguments
None

### Environment Variables
- `COVERAGE`: If `true`, generate coverage report (default: `true` if tarpaulin installed)

### Behavior
1. Run `cargo test`
2. If coverage enabled, run `cargo tarpaulin`
3. Generate HTML coverage report

### Exit Codes
- `0`: All tests passed
- `1`: One or more tests failed

### Output Format
```
[INFO] Running Rust unit tests...
   Compiling core v0.1.0
    Finished test profile [unoptimized + debuginfo]
     Running unittests src/lib.rs

running 12 tests
test ffi::tests::test_version ... ok
test ffi::tests::test_init_shutdown ... ok
test models::tests::test_clipboard_entry ... ok
...

test result: ok. 12 passed; 0 failed; 0 ignored; 0 measured; 0 filtered out

[INFO] Coverage: 84.5%
[INFO] Coverage report: build/core/coverage/index.html
[INFO] ✓ All tests passed!
```

---

## Integration with Xcode

### Run Script Build Phase

Add this to Xcode target's "Build Phases" → "Run Script":

```bash
# Build Rust core before Swift compilation
CONFIGURATION=${CONFIGURATION:-Release}
PROJECT_DIR="${PROJECT_FILE_PATH%/*}/.."

cd "$PROJECT_DIR"
./scripts/build-core.sh "$CONFIGURATION" universal
```

### Output Directory in Xcode

In Xcode build settings:
- `CONFIGURATION_BUILD_DIR` = `$(PROJECT_DIR)/build/macos/$(CONFIGURATION)$(EFFECTIVE_PLATFORM_NAME)`
- `BUILT_PRODUCTS_DIR` = `$(CONFIGURATION_BUILD_DIR)`

---

## CI/CD Integration

All scripts are CI/CD friendly:

- Non-interactive (no prompts)
- Clear exit codes for failure detection
- Structured output for logging
- Environment variable overrides for customization
- No assumptions about GUI tools

### GitHub Actions Example

```yaml
- name: Build
  run: |
    ./scripts/build.sh release false universal

- name: Test
  run: |
    ./scripts/test-core.sh

- name: Package
  run: |
    ./scripts/package.sh release sign
```

---

## Troubleshooting

### Common Issues

**Issue**: `error: Rust toolchain not found`
- **Fix**: Install Rust from https://rustup.rs/

**Issue**: `error: Xcode not found`
- **Fix**: Install Xcode from Mac App Store and run `sudo xcode-select -s /Applications/Xcode.app`

**Issue**: `error: Rust library not found`
- **Fix**: Run `./scripts/build-core.sh` first

**Issue**: `error: Code signing failed`
- **Fix**: Run `./scripts/package.sh release nosign` for unsigned build, or set up code signing certificate

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2026-02-04 | Initial version |
