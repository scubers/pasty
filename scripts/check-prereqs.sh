#!/bin/bash
# Check prerequisites for Pasty development

set -euo pipefail

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

PROJECT_ROOT="$(get_project_root)"

log_info "Checking prerequisites..."

missing=()

# Check Rust
if ! command_exists rustc; then
    missing+=("Rust compiler not found. Install from: https://rustup.rs/")
else
    RUST_VERSION=$(rustc --version | cut -d' ' -f2)
    # Rust 1.93.0 is newer than 1.70.0, so version_ge should work
    if ! version_ge "1.70.0" "$RUST_VERSION"; then
        missing+=("Rust version $RUST_VERSION is too old (required: ≥1.70.0). Update with: rustup update")
    else
        log_info "✓ Rust $RUST_VERSION found (required: ≥1.70.0)"
    fi
fi

# Check Cargo
if ! command_exists cargo; then
    missing+=("Cargo not found (should be installed with Rust)")
fi

# Check Xcode
if ! command_exists xcodebuild; then
    missing+=("Xcode command line tools not found. Install from: https://developer.apple.com/download/all/")
else
    XCODE_VERSION=$(xcodebuild -version | head -1 | cut -d' ' -f2)
    # Extract major version number
    XCODE_MAJOR=$(echo "$XCODE_VERSION" | cut -d'.' -f1)
    if [ "$XCODE_MAJOR" -lt 14 ]; then
        missing+=("Xcode version $XCODE_VERSION is too old (required: ≥14.0). Update from Mac App Store")
    else
        log_info "✓ Xcode $XCODE_VERSION found (required: ≥14.0)"
    fi
fi

# Check Swift
if ! command_exists swift; then
    missing+=("Swift not found (should be installed with Xcode)")
else
    SWIFT_VERSION=$(swift --version | head -1 | cut -d' ' -f3)
    log_info "✓ Swift $SWIFT_VERSION found"
fi

# Check cbindgen (optional but recommended)
if ! command_exists cbindgen; then
    log_warn "cbindgen not found. Install with: cargo install cbindgen"
    log_warn "Required for C header generation"
else
    log_info "✓ cbindgen found (optional)"
fi

# Check create-dmg (optional, for packaging)
if ! command_exists create-dmg; then
    log_warn "create-dmg not found. Install with: brew install create-dmg"
    log_warn "Required for DMG packaging (User Story 4)"
else
    log_info "✓ create-dmg found (optional)"
fi

# Report missing prerequisites
if [ ${#missing[@]} -gt 0 ]; then
    log_error "Missing prerequisites:"
    for item in "${missing[@]}"; do
        echo "  - $item"
    done
    echo ""
    log_error "Please install missing prerequisites and try again."
    exit 3
fi

log_info "✓ All prerequisites met!"
exit 0
