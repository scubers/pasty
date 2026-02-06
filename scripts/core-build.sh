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

clang++ -std=c++17 -Wall \
    -I"$PROJECT_ROOT/core/include" \
    -c "$PROJECT_ROOT/core/src/Pasty.cpp" \
    -o Pasty.o

ar rcs libPastyCore.a Pasty.o

echo "Core library built: $BUILD_DIR/libPastyCore.a"
