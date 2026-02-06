#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="$PROJECT_ROOT/build/core"

CONFIG=${1:-Debug}

echo "=== Building Pasty Core (C++) ==="
echo "Configuration: $CONFIG"

mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

cmake "$PROJECT_ROOT/core" -DCMAKE_BUILD_TYPE=$CONFIG
cmake --build . --config $CONFIG

echo "Core library built: $BUILD_DIR/lib/libPastyCore.a"
