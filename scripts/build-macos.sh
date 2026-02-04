#!/bin/bash
# Build Swift macOS app

set -euo pipefail

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

PROJECT_ROOT="$(get_project_root)"
MACOS_DIR="$PROJECT_ROOT/macos/PastyApp"
BUILD_TYPE="${1:-release}"

# Normalize build type
BUILD_CONFIG=$(echo "$BUILD_TYPE" | tr '[:upper:]' '[:lower:]')

# Validate build type
if [[ "$BUILD_CONFIG" != "debug" && "$BUILD_CONFIG" != "release" ]]; then
    log_error "Invalid build type: $BUILD_TYPE"
    log_info "Usage: $0 [debug|release]"
    exit 2
fi

log_info "Building macOS app..."
log_info "Configuration: $BUILD_CONFIG"

# Check Swift toolchain
if ! command_exists swiftc; then
    log_error "Swift compiler not found"
    log_error "Install Xcode from Mac App Store and run: sudo xcode-select -s /Applications/Xcode.app"
    exit 3
fi

SWIFT_VERSION=$(swift --version 2>/dev/null | head -n1 | grep -oE 'Swift version [0-9.]+' || echo "unknown")
log_info "Swift version: $SWIFT_VERSION"

# Validate Rust library exists
RUST_LIB="$PROJECT_ROOT/target/universal/$BUILD_CONFIG/libpasty_core.a"
if [[ ! -f "$RUST_LIB" ]]; then
    log_error "Rust library not found: $RUST_LIB"
    log_error "Run ./scripts/build-core.sh $BUILD_CONFIG universal first"
    exit 3
fi

log_info "Rust library found: $RUST_LIB"

# Determine Swift compiler flags based on build type
SWIFTC_FLAGS=()
if [[ "$BUILD_CONFIG" == "release" ]]; then
    SWIFTC_FLAGS+=(-O)
else
    SWIFTC_FLAGS+=(-Onone)
fi

# Target macOS 14.0 (Big Sur or later)
SWIFTC_FLAGS+=(-target arm64-apple-macos14.0)
SWIFTC_FLAGS+=(-L "$PROJECT_ROOT/target/universal/$BUILD_CONFIG")
SWIFTC_FLAGS+=(-Xlinker -lpasty_core)

# Find all Swift files
log_step "Finding Swift source files..."
SWIFT_FILES=()
while IFS= read -r -d '' file; do
    SWIFT_FILES+=("$file")
done < <(find "$MACOS_DIR/PastyApp" -name "*.swift" -print0 2>/dev/null)

if [ ${#SWIFT_FILES[@]} -eq 0 ]; then
    log_error "No Swift files found in $MACOS_DIR/PastyApp"
    exit 4
fi

log_info "Found ${#SWIFT_FILES[@]} Swift file(s)"

# Build Swift app
log_step "Compiling Swift app..."
cd "$MACOS_DIR"

OUTPUT_BINARY="$MACOS_DIR/PastyApp_binary"
if ! swiftc "${SWIFTC_FLAGS[@]}" "${SWIFT_FILES[@]}" -o "$OUTPUT_BINARY"; then
    log_error "Failed to build Swift app"
    exit 4
fi

# Create app bundle
log_step "Creating app bundle..."

APP_BUNDLE="$PROJECT_ROOT/build/macos/PastyApp.app"
CONTENTS="$APP_BUNDLE/Contents"
MACOS_DIR_BUNDLE="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"

rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS_DIR_BUNDLE"
mkdir -p "$RESOURCES"

# Copy executable
mv "$OUTPUT_BINARY" "$MACOS_DIR_BUNDLE/PastyApp"

# Process and copy Info.plist (replace Xcode variables)
if [[ -f "$MACOS_DIR/PastyApp/Info.plist" ]]; then
    sed -e 's/$(DEVELOPMENT_LANGUAGE)/en/g' \
        -e 's/$(EXECUTABLE_NAME)/PastyApp/g' \
        -e 's/$(PRODUCT_NAME)/PastyApp/g' \
        -e 's/$(MACOSX_DEPLOYMENT_TARGET)/14.0/g' \
        "$MACOS_DIR/PastyApp/Info.plist" > "$CONTENTS/Info.plist"
else
    log_warn "Info.plist not found"
fi

# Copy entitlements
if [[ -f "$MACOS_DIR/PastyApp/PastyApp.entitlements" ]]; then
    cp "$MACOS_DIR/PastyApp/PastyApp.entitlements" "$CONTENTS/PastyApp.entitlements"
fi

log_info "✓ App bundle created: $APP_BUNDLE"
log_info "✓ Build completed successfully!"

exit 0
