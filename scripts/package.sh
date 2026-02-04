#!/bin/bash
# Package macOS application as DMG disk image
# Usage: ./scripts/package.sh [release|debug] [sign|nosign]

set -euo pipefail

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

PROJECT_ROOT="$(get_project_root)"
BUILD_TYPE="${1:-release}"
SIGNING="${2:-sign}"

# Validate build type
if [[ "$BUILD_TYPE" != "debug" && "$BUILD_TYPE" != "release" ]]; then
    log_error "Invalid build type: $BUILD_TYPE"
    log_info "Usage: $0 [debug|release] [sign|nosign]"
    exit 2
fi

# Validate signing option
if [[ "$SIGNING" != "sign" && "$SIGNING" != "nosign" ]]; then
    log_error "Invalid signing option: $SIGNING"
    log_info "Usage: $0 [debug|release] [sign|nosign]"
    exit 2
fi

log_info "Packaging Pasty for macOS..."
log_info "Configuration: $BUILD_TYPE"
log_info "Signing: $SIGNING"

# Paths
APP_BUNDLE="$PROJECT_ROOT/build/macos/PastyApp.app"
DMG_OUTPUT_DIR="$PROJECT_ROOT/build/macos/dmg"
APP_NAME="PastyApp"
APP_VERSION="0.1.0"
DMG_NAME="${APP_NAME}-${APP_VERSION}.dmg"
DMG_PATH="$DMG_OUTPUT_DIR/$DMG_NAME"

# Check if app bundle exists
if [[ ! -d "$APP_BUNDLE" ]]; then
    log_error "App bundle not found: $APP_BUNDLE"
    log_info "Please build the app first: ./scripts/build.sh $BUILD_TYPE"
    exit 4
fi

log_step "Checking prerequisites..."

# Check for create-dmg
if ! command_exists create-dmg; then
    log_warn "create-dmg not found"
    log_info "Install with: brew install create-dmg"
    log_info "Will use hdiutil for basic DMG creation instead"
    HAS_CREATE_DMG=false
else
    log_info "✓ create-dmg found"
    HAS_CREATE_DMG=true
fi

# Check code signing certificate
SIGNING_IDENTITY=""
if [[ "$SIGNING" == "sign" ]]; then
    log_step "Checking for code signing certificate..."

    # Try to find a valid signing identity
    IDENTITY=$(security find-identity -v -p codesigning 2>/dev/null | grep -o '"[^"]*"' | head -1 | tr -d '"')

    if [[ -n "$IDENTITY" ]]; then
        SIGNING_IDENTITY="$IDENTITY"
        log_info "✓ Found signing identity: $IDENTITY"
    else
        log_warn "No code signing certificate found"
        log_info "Will use ad-hoc signing (-)"
        SIGNING_IDENTITY="-"
    fi
fi

# Sign the app bundle
if [[ "$SIGNING" == "sign" ]]; then
    log_step "Signing application bundle..."

    ENTITLEMENTS="$PROJECT_ROOT/macos/PastyApp/PastyApp.entitlements"

    if [[ -f "$ENTITLEMENTS" ]]; then
        codesign --force --deep --sign "$SIGNING_IDENTITY" \
            --entitlements "$ENTITLEMENTS" \
            "$APP_BUNDLE" 2>/dev/null || {
            log_error "Failed to sign app bundle"
            exit 5
        }
    else
        codesign --force --deep --sign "$SIGNING_IDENTITY" \
            "$APP_BUNDLE" 2>/dev/null || {
            log_error "Failed to sign app bundle"
            exit 5
        }
    fi

    log_info "✓ App bundle signed"

    # Verify signature
    if codesign --verify --deep --strict "$APP_BUNDLE" 2>/dev/null; then
        log_info "✓ Signature verified"
    else
        log_warn "Signature verification failed (this may be ok for ad-hoc signing)"
    fi
fi

# Create output directory
mkdir -p "$DMG_OUTPUT_DIR"

# Remove old DMG if exists
if [[ -f "$DMG_PATH" ]]; then
    log_step "Removing old DMG..."
    rm -f "$DMG_PATH"
fi

# Create DMG
log_step "Creating DMG disk image..."

if [[ "$HAS_CREATE_DMG" == true ]]; then
    # Use create-dmg for professional-looking DMG
    create-dmg \
        --volname "$APP_NAME" \
        --window-pos 200 120 \
        --window-size 600 400 \
        --icon-size 100 \
        --app-drop-link 450 185 \
        --hide-extension "$APP_NAME.app" \
        "$DMG_PATH" \
        "$APP_BUNDLE" || {
        log_error "Failed to create DMG with create-dmg"
        exit 6
    }
else
    # Fallback to basic hdiutil
    DMG_TEMP_DIR="$DMG_OUTPUT_DIR/temp_dmg"
    rm -rf "$DMG_TEMP_DIR"
    mkdir -p "$DMG_TEMP_DIR"

    # Copy app to temp dir
    cp -R "$APP_BUNDLE" "$DMG_TEMP_DIR/"

    # Create Applications symlink
    ln -s /Applications "$DMG_TEMP_DIR/Applications"

    # Create DMG
    hdiutil create -volname "$APP_NAME" \
        -srcfolder "$DMG_TEMP_DIR" \
        -ov \
        -format UDZO \
        "$DMG_PATH" || {
        log_error "Failed to create DMG with hdiutil"
        rm -rf "$DMG_TEMP_DIR"
        exit 6
    }

    # Clean up temp dir
    rm -rf "$DMG_TEMP_DIR"
fi

log_info "✓ DMG created successfully!"

# Get DMG size
DMG_SIZE=$(du -h "$DMG_PATH" | cut -f1)

log_info ""
log_info "=========================================="
log_info "Package Summary"
log_info "=========================================="
log_info "Configuration:  $BUILD_TYPE"
log_info "Signing:        $SIGNING ${SIGNING_IDENTITY:+($SIGNING_IDENTITY)}"
log_info "DMG Path:       $DMG_PATH"
log_info "DMG Size:       $DMG_SIZE"
log_info ""
log_info "To install:"
log_info "  1. Open: open $DMG_PATH"
log_info "  2. Drag $APP_NAME.app to Applications"
log_info "  3. Launch from Applications"
log_info "=========================================="

exit 0
