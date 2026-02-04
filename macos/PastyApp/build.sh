#!/bin/bash
# Build script for Pasty macOS app

set -euo pipefail

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$(dirname "$SCRIPT_DIR")/../scripts/common.sh"

PROJECT_ROOT="$(get_project_root)"
BUILD_TYPE="${1:-Release}"

log_info "Building Pasty macOS app..."
log_info "Configuration: $BUILD_TYPE"

# Ensure Rust core is built
log_step "Building Rust core library..."
cd "$PROJECT_ROOT"
source ~/.cargo/env
./scripts/build-core.sh $(echo "$BUILD_TYPE" | tr '[:upper:]' '[:lower:]') arm64

# Build Swift app
log_step "Building Swift app..."

cd "$SCRIPT_DIR"

SWIFTC_FLAGS=(
    -O
    -target arm64-apple-macos14.0
    -L "$PROJECT_ROOT/target/universal/release"
    -Xlinker -lpasty_core
)

# Find all Swift files
SWIFT_FILES=()
while IFS= read -r -d '' file; do
    SWIFT_FILES+=("$file")
done < <(find PastyApp -name "*.swift" -print0)

if [ ${#SWIFT_FILES[@]} -eq 0 ]; then
    log_error "No Swift files found"
    exit 1
fi

log_info "Swift files: ${SWIFT_FILES[@]}"

# Build the app
OUTPUT_BINARY="PastyApp_binary"
if ! swiftc "${SWIFTC_FLAGS[@]}" "${SWIFT_FILES[@]}" -o "$OUTPUT_BINARY"; then
    log_error "Failed to build Swift app"
    exit 1
fi

# Create app bundle
log_step "Creating app bundle..."

APP_BUNDLE="$SCRIPT_DIR/build/PastyApp.app"
CONTENTS="$APP_BUNDLE/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"

rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS"
mkdir -p "$RESOURCES"

# Copy executable
cp PastyApp_binary "$MACOS/PastyApp"

# Copy Info.plist
cp PastyApp/Info.plist "$CONTENTS/"

# Copy PastyApp.entitlements
cp PastyApp/PastyApp.entitlements "$CONTENTS/"

log_info "✓ App bundle created: $APP_BUNDLE"
log_info "✓ Build successful!"

exit 0
