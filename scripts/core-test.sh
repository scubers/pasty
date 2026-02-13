#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="$PROJECT_ROOT/build/core"

VERBOSE=false

show_help() {
    echo "Usage: ./scripts/core-test.sh [options]"
    echo ""
    echo "Options:"
    echo "  --verbose, -v    Show detailed test output"
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
        *)
            echo "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

if [ ! -d "$BUILD_DIR" ]; then
    echo "Error: Build directory $BUILD_DIR not found. Run ./scripts/core-build.sh first."
    exit 1
fi

echo "=== Running Pasty Core Tests ==="
cd "$BUILD_DIR"

CTEST_ARGS="--output-on-failure"

if [ "$VERBOSE" = true ]; then
    CTEST_ARGS="-V $CTEST_ARGS"
fi

# Run ctest
ctest $CTEST_ARGS
