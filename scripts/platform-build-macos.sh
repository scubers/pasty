#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MACOS_DIR="$PROJECT_ROOT/platform/macos"
BUILD_DIR="$PROJECT_ROOT/build/macos"

CONFIG=${1:-Debug}

echo "=== Building Pasty macOS ==="
echo "Configuration: $CONFIG"

cd "$MACOS_DIR"

if [ ! -f "Pasty.xcodeproj/project.pbxproj" ]; then
    echo "Generating Xcode project..."
    xcodegen generate
fi

echo "Building with xcodebuild..."
xcodebuild -project Pasty.xcodeproj \
    -scheme Pasty \
    -configuration "$CONFIG" \
    -derivedDataPath "$BUILD_DIR" \
    build

APP_PATH="$BUILD_DIR/Build/Products/$CONFIG/Pasty.app"
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
