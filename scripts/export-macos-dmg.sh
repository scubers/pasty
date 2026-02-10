#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="$PROJECT_ROOT/build/macos"
DMG_OUTPUT_DIR="$PROJECT_ROOT/dist"

CONFIG=${1:-Release}
APP_NAME="Pasty"
VOLUME_NAME="$APP_NAME"

APP_PATH="$BUILD_DIR/Build/Products/$CONFIG/$APP_NAME.app"
DMG_PATH="$DMG_OUTPUT_DIR/${APP_NAME}-${CONFIG}.dmg"

WORK_DIR=$(mktemp -d)
trap "rm -rf $WORK_DIR" EXIT

echo "=== Building Pasty macOS ==="
"$SCRIPT_DIR/platform-build-macos.sh" "$CONFIG"

echo ""
echo "=== Exporting Pasty macOS DMG ==="
echo "Configuration: $CONFIG"
echo "App path: $APP_PATH"
echo "DMG output: $DMG_PATH"
echo ""

if [ ! -d "$APP_PATH" ]; then
    echo "❌ Error: Build failed, application not found at $APP_PATH"
    exit 1
fi

mkdir -p "$DMG_OUTPUT_DIR"

echo "Creating DMG contents..."
APP_DEST="$WORK_DIR/$APP_NAME.app"
cp -R "$APP_PATH" "$APP_DEST"

ln -s /Applications "$WORK_DIR/Applications"

echo "Creating DMG image..."
hdiutil create -volname "$VOLUME_NAME" \
    -srcfolder "$WORK_DIR" \
    -ov \
    -format UDZO \
    "$DMG_PATH"

echo ""
echo "=== DMG export successful ==="
echo "DMG path: $DMG_PATH"
echo ""
echo "To install: open \"$DMG_PATH\""
