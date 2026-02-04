#!/bin/bash
# Launch the built macOS application

set -euo pipefail

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

PROJECT_ROOT="$(get_project_root)"
BUILD_TYPE="${1:-debug}"
APP_BUNDLE="$PROJECT_ROOT/build/macos/PastyApp.app"

log_info "Launching PastyApp..."
log_info "Configuration: $BUILD_TYPE"

# Check if app exists
if [[ ! -d "$APP_BUNDLE" ]]; then
    log_error "App bundle not found: $APP_BUNDLE"
    log_info "Have you built the app? Run: ./scripts/build.sh $BUILD_TYPE"
    echo ""
    read -p "Build app now? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log_info "Building app..."
        if "$SCRIPT_DIR/build.sh" "$BUILD_TYPE"; then
            log_info "Build complete, launching app..."
        else
            log_error "Build failed"
            exit 4
        fi
    else
        exit 4
    fi
fi

# Launch the app
log_info "Launching: $APP_BUNDLE"
open "$APP_BUNDLE"

log_info "✓ App launched!"
