#!/bin/bash
# Run script for Pasty macOS app

set -euo pipefail

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$(dirname "$SCRIPT_DIR")/../scripts/common.sh"

APP_BUNDLE="$SCRIPT_DIR/build/PastyApp.app"

if [[ ! -d "$APP_BUNDLE" ]]; then
    log_error "App bundle not found at $APP_BUNDLE"
    log_info "Please run ./build.sh first"
    exit 1
fi

log_info "Launching Pasty app..."

# Open the app
open "$APP_BUNDLE"
