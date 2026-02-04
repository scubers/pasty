#!/bin/bash
# Build Rust core library for macOS

set -euo pipefail

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

PROJECT_ROOT="$(get_project_root)"
CORE_DIR="$PROJECT_ROOT/core"
TARGET_DIR="$CORE_DIR/target"
UNIVERSAL_DIR="$PROJECT_ROOT/target/universal"
BUILD_TYPE="${1:-release}"
ARCH="${2:-universal}"

# Validate build type
if [[ "$BUILD_TYPE" != "debug" && "$BUILD_TYPE" != "release" ]]; then
    log_error "Invalid build type: $BUILD_TYPE"
    log_info "Usage: $0 [debug|release] [x86_64|arm64|universal]"
    exit 2
fi

# Validate architecture
if [[ "$ARCH" != "x86_64" && "$ARCH" != "arm64" && "$ARCH" != "universal" ]]; then
    log_error "Invalid architecture: $ARCH"
    log_info "Usage: $0 [debug|release] [x86_64|arm64|universal]"
    exit 2
fi

log_info "Building Rust core library..."
log_info "Configuration: $BUILD_TYPE"
log_info "Architecture: $ARCH"

# Check Rust toolchain
if ! command_exists rustc; then
    log_error "Rust compiler not found"
    exit 3
fi

RUST_VERSION=$(rustc --version | cut -d' ' -f2)
log_info "Rust version: $RUST_VERSION"

# Check Xcode (needed for linking)
if ! command_exists xcodebuild; then
    log_error "Xcode not found (required for linking)"
    exit 3
fi

# Install Rust targets if needed
if [[ "$ARCH" == "universal" ]]; then
    if ! rustup target list --installed | grep -q "x86_64-apple-darwin"; then
        log_info "Installing x86_64-apple-darwin target..."
        rustup target add x86_64-apple-darwin
    fi
    if ! rustup target list --installed | grep -q "aarch64-apple-darwin"; then
        log_info "Installing aarch64-apple-darwin target..."
        rustup target add aarch64-apple-darwin
    fi
fi

# Clean if requested
if [[ "${CLEAN:-false}" == "true" ]]; then
    log_step "Cleaning previous builds..."
    cargo clean
    rm -rf "$UNIVERSAL_DIR"
fi

# Build for specific architecture
build_arch() {
    local arch=$1
    local target=""
    local triple=""

    case $arch in
        x86_64)
            triple="x86_64-apple-darwin"
            ;;
        arm64)
            triple="aarch64-apple-darwin"
            ;;
        *)
            log_error "Unsupported architecture: $arch"
            exit 1
            ;;
    esac

    log_step "Building for $triple ($BUILD_TYPE)..."

    cd "$CORE_DIR"

    local cargo_args=()
    if [[ "$BUILD_TYPE" == "release" ]]; then
        cargo_args+=("--release")
    fi

    cargo_args+=("--target" "$triple")

    if ! cargo build "${cargo_args[@]}"; then
        log_error "Failed to build for $triple"
        exit 4
    fi

    # Copy to universal directory for later combination
    mkdir -p "$UNIVERSAL_DIR/$BUILD_TYPE"

    local target_dir="$TARGET_DIR/$triple/$BUILD_TYPE"

    # Find the static library (could be .a archive)
    if [[ -f "$target_dir/libpasty_core.a" ]]; then
        cp "$target_dir/libpasty_core.a" "$UNIVERSAL_DIR/$BUILD_TYPE/libpasty_core.$arch.a"
    else
        log_error "Could not find static library in $target_dir"
        log_error "Looking for libpasty_core.a"
        log_error "Directory contents:"
        ls -la "$target_dir" || true
        exit 4
    fi
}

# Create universal binary
create_universal() {
    if [[ "$ARCH" != "universal" ]]; then
        return 0
    fi

    log_step "Creating universal binary..."

    # Build both architectures
    build_arch x86_64
    build_arch arm64

    # Combine with lipo
    local x86_lib="$UNIVERSAL_DIR/$BUILD_TYPE/libpasty_core.x86_64.a"
    local arm_lib="$UNIVERSAL_DIR/$BUILD_TYPE/libpasty_core.arm64.a"
    local universal_lib="$UNIVERSAL_DIR/$BUILD_TYPE/libpasty_core.a"

    if ! lipo -create "$x86_lib" "$arm_lib" -output "$universal_lib"; then
        log_error "Failed to create universal binary"
        exit 4
    fi

    # Clean up intermediate files
    rm -f "$x86_lib" "$arm_lib"

    log_info "✓ Universal binary created: $universal_lib"
}

# Build
cd "$CORE_DIR"

if [[ "$ARCH" == "universal" ]]; then
    create_universal
else
    build_arch "$ARCH"
    # Rename single-arch lib
    src_lib="$UNIVERSAL_DIR/$BUILD_TYPE/libpasty_core.$ARCH.a"
    dst_lib="$UNIVERSAL_DIR/$BUILD_TYPE/libpasty_core.a"
    if [[ -f "$src_lib" ]]; then
        mv "$src_lib" "$dst_lib"
    fi
fi

# Generate C header with cbindgen
if command_exists cbindgen; then
    log_step "Generating C header with cbindgen..."

    mkdir -p "$PROJECT_ROOT/build/core/include"

    if ! cbindgen --config "$CORE_DIR/cbindgen.toml" --crate pasty-core \
        --output "$PROJECT_ROOT/build/core/include/pasty.h"; then
        log_warn "cbindgen failed - C header not generated"
    else
        log_info "✓ C header generated: build/core/include/pasty.h"
    fi
else
    log_warn "cbindgen not found - C header not generated"
    log_warn "Install with: cargo install cbindgen"
fi

log_info "✓ Core library built successfully!"
log_info "Artifact: $UNIVERSAL_DIR/$BUILD_TYPE/libpasty_core.a"

exit 0
