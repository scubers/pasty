#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="$PROJECT_ROOT/build/core"

CONFIG="${1:-Debug}"

echo "=== Building Pasty Core (C++) ==="
echo "Configuration: $CONFIG"

mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

cmake "$PROJECT_ROOT/core" -DCMAKE_BUILD_TYPE="$CONFIG" -DPASTY_BUILD_TESTS=ON 2>&1 | grep -v "^-- " | grep -E "(warning|error|Configuring done|Generating done|Build files)" || true
cmake --build . --config "$CONFIG" 2>&1 | grep -E "(warning|error|\[.*%\]|Built target)" || true

echo "Core library built: $BUILD_DIR/lib/libPastyCore.a"
