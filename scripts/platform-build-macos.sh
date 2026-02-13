#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MACOS_DIR="$PROJECT_ROOT/platform/macos"
BUILD_DIR="$PROJECT_ROOT/build/macos"

VERBOSE=false
CONFIG="Debug"

show_help() {
    echo "Usage: ./scripts/platform-build-macos.sh [options] [configuration]"
    echo ""
    echo "Configurations:"
    echo "  Debug (default)"
    echo "  Release"
    echo ""
    echo "Options:"
    echo "  --verbose, -v    Show full xcodebuild output"
    echo "  --help, -h       Show this help message"
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --verbose|-v)
            VERBOSE=true
            shift
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        Debug|Release)
            CONFIG=$1
            shift
            ;;
        -*)
            echo "Unknown option: $1"
            show_help
            exit 1
            ;;
        *)
            CONFIG=$1
            shift
            ;;
    esac
done

if [ "$CONFIG" = "Debug" ]; then
    APP_NAME="PastyDebug"
else
    APP_NAME="Pasty"
fi

echo "=== Building Pasty macOS ==="
echo "Configuration: $CONFIG"
echo "App name: $APP_NAME"

cd "$MACOS_DIR"

if ! command -v xcodegen >/dev/null 2>&1; then
    echo "Error: xcodegen not found. Please install xcodegen first."
    exit 1
fi

if [ "$VERBOSE" = true ]; then
    echo "Generating Xcode project..."
    xcodegen generate
    echo "Building with xcodebuild..."
    xcodebuild -project Pasty.xcodeproj \
        -scheme Pasty \
        -configuration "$CONFIG" \
        -derivedDataPath "$BUILD_DIR" \
        build
else
    echo "Generating Xcode project..."
    xcodegen generate > /dev/null
    echo "Building with xcodebuild..."
    xcodebuild -project Pasty.xcodeproj \
        -scheme Pasty \
        -configuration "$CONFIG" \
        -derivedDataPath "$BUILD_DIR" \
        -quiet \
        build
fi

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
