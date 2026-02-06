#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "=== Pasty2 Environment Check ==="

check_command() {
    if command -v "$1" &> /dev/null; then
        echo "✓ $1 found: $(command -v "$1")"
        return 0
    else
        echo "✗ $1 not found"
        return 1
    fi
}

check_version() {
    local cmd=$1
    local version_flag=${2:---version}
    if command -v "$cmd" &> /dev/null; then
        local version=$("$cmd" $version_flag 2>&1 | head -1)
        echo "  Version: $version"
    fi
}

MISSING=0

echo ""
echo "Core Tools:"
check_command "xcodebuild" || MISSING=$((MISSING + 1))
check_version "xcodebuild" "-version"

check_command "xcodegen" || MISSING=$((MISSING + 1))
check_version "xcodegen"

echo ""
echo "Build Tools:"
check_command "clang++" || MISSING=$((MISSING + 1))
check_version "clang++"

check_command "cmake" || MISSING=$((MISSING + 1))
check_version "cmake"

echo ""
echo "Optional Tools:"
check_command "git" && check_version "git"

echo ""
if [ $MISSING -eq 0 ]; then
    echo "=== All required tools are installed ==="
    exit 0
else
    echo "=== Missing $MISSING required tool(s) ==="
    echo "Run: ./scripts/install-requirements.sh"
    exit 1
fi
