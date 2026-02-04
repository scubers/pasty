#!/bin/bash
# Build Swift macOS app using Xcode
#
# This script uses xcodegen to generate the Xcode project from project.yml,
# then builds the app using xcodebuild.

set -euo pipefail

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

PROJECT_ROOT="$(get_project_root)"
MACOS_DIR="$PROJECT_ROOT/macos/PastyApp"
BUILD_TYPE="${1:-release}"

# Normalize build type
BUILD_CONFIG=$(echo "$BUILD_TYPE" | tr '[:upper:]' '[:lower:]')

# Map to Xcode configuration names
if [[ "$BUILD_CONFIG" == "release" ]]; then
    CAPITALIZED_CONFIG="Release"
else
    CAPITALIZED_CONFIG="Debug"
fi

# Validate build type
if [[ "$BUILD_CONFIG" != "debug" && "$BUILD_CONFIG" != "release" ]]; then
    log_error "Invalid build type: $BUILD_TYPE"
    log_info "Usage: $0 [debug|release]"
    exit 2
fi

log_info "Building macOS app with Xcode..."
log_info "Configuration: $CAPITALIZED_CONFIG"

# Check for xcodegen
if ! command_exists xcodegen; then
    log_error "xcodegen not found"
    log_error "Install with: brew install xcodegen"
    exit 3
fi

# Check for xcodebuild
if ! command_exists xcodebuild; then
    log_error "xcodebuild not found (Xcode command line tools)"
    log_error "Install Xcode from Mac App Store and run: xcode-select -s /Applications/Xcode.app"
    exit 3
fi

# Validate project.yml exists
if [[ ! -f "$MACOS_DIR/project.yml" ]]; then
    log_error "project.yml not found in $MACOS_DIR"
    exit 3
fi

# Validate Rust library exists
RUST_LIB="$PROJECT_ROOT/target/universal/$BUILD_CONFIG/libpasty_core.a"
if [[ ! -f "$RUST_LIB" ]]; then
    log_error "Rust library not found: $RUST_LIB"
    log_error "Run ./scripts/build-core.sh $BUILD_CONFIG universal first"
    exit 3
fi

log_info "Rust library found: $RUST_LIB"

# Generate Xcode project
log_step "Generating Xcode project with xcodegen..."
cd "$MACOS_DIR"

if ! xcodegen generate --spec project.yml; then
    log_error "Failed to generate Xcode project"
    exit 4
fi

log_info "✓ Xcode project generated"

# Check if project was generated
if [[ ! -f "$MACOS_DIR/PastyApp.xcodeproj/project.pbxproj" ]]; then
    log_error "Xcode project file not found after generation"
    exit 4
fi

# Build with xcodebuild
log_step "Building macOS app with xcodebuild..."

XCODE_BUILD_DIR="$MACOS_DIR/build"
ARCHIVE_PATH="$MACOS_DIR/build/PastyApp.xcarchive"

# Build settings
BUILD_SETTINGS=(
    -project PastyApp.xcodeproj
    -scheme PastyApp
    -configuration "$CAPITALIZED_CONFIG"
    -derivedDataPath "$XCODE_BUILD_DIR"
    -archivePath "$ARCHIVE_PATH"
)

# Clean if requested
if [[ "${CLEAN:-false}" == "true" ]]; then
    log_info "Cleaning build..."
    xcodebuild clean "${BUILD_SETTINGS[@]}" || true
fi

# Build the app
if ! xcodebuild build "${BUILD_SETTINGS[@]}" | while IFS= read -r line; do
    # Only show important lines
    if [[ "$line" =~ ^(Build|Compile|Link|Write|Ld|error|warning:|note:) ]] || [[ "$line" =~ \*\s*ASSET\* ]]; then
        echo "$line"
    fi
done; then
    log_error "Failed to build macOS app"
    exit 4
fi

log_info "✓ Build completed successfully"

# Find the built app bundle
APP_BUNDLE=$(find "$XCODE_BUILD_DIR" -name "PastyApp.app" -type d | head -n1)

if [[ -z "$APP_BUNDLE" ]]; then
    log_error "Could not find built app bundle"
    exit 4
fi

# Copy to final location
FINAL_APP="$PROJECT_ROOT/build/macos/PastyApp.app"
rm -rf "$FINAL_APP"
mkdir -p "$PROJECT_ROOT/build/macos"

if ! ditto "$APP_BUNDLE" "$FINAL_APP"; then
    log_error "Failed to copy app bundle"
    exit 4
fi

log_info "✓ App bundle created: $FINAL_APP"
log_info "✓ Build completed successfully!"

exit 0
