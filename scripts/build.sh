#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="$PROJECT_ROOT/build"

PLATFORM=${1:-all}
CONFIG=${2:-Debug}

echo "=== Pasty Build Script ==="
echo "Platform: $PLATFORM"
echo "Configuration: $CONFIG"
echo ""

build_core() {
    echo "Building Core (C++ library)..."
    "$SCRIPT_DIR/core-build.sh" "$CONFIG"
}

build_macos() {
    echo "Building macOS platform..."
    "$SCRIPT_DIR/platform-build-macos.sh" "$CONFIG"
}

case $PLATFORM in
    core)
        build_core
        ;;
    macos)
        build_macos
        ;;
    all)
        build_macos
        ;;
    *)
        echo "Unknown platform: $PLATFORM"
        echo "Usage: $0 [core|macos|all] [Debug|Release]"
        exit 1
        ;;
esac

echo ""
echo "=== Build complete ==="
