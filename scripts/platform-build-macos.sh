#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MACOS_DIR="$PROJECT_ROOT/platform/macos"
BUILD_DIR="$PROJECT_ROOT/build/macos"

CONFIG=${1:-Debug}

if [ "$CONFIG" = "Debug" ]; then
    APP_NAME="PastyDebug"
else
    APP_NAME="Pasty"
fi

echo "=== Building Pasty macOS ==="
echo "Configuration: $CONFIG"
echo "App name: $APP_NAME"

cd "$MACOS_DIR"

echo "Generating Xcode project..."
if ! command -v xcodegen >/dev/null 2>&1; then
    echo "Error: xcodegen not found. Please install xcodegen first."
    exit 1
fi
xcodegen generate

echo "Building with xcodebuild..."
xcodebuild -project Pasty.xcodeproj \
    -scheme Pasty \
    -configuration "$CONFIG" \
    -derivedDataPath "$BUILD_DIR" \
    build

APP_PATH="$BUILD_DIR/Build/Products/$CONFIG/${APP_NAME}.app"
if [ -d "$APP_PATH" ]; then
    echo ""
    echo "=== Build successful ==="
    echo "Application: $APP_PATH"
    echo ""
    echo "To run: open \"$APP_PATH\""
else
    echo "Build failed: Application not found"
    exit 1
fi
