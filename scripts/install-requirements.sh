#!/bin/bash
set -e

echo "=== Pasty2 Requirements Installation ==="

if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "Detected macOS"
    
    if ! command -v brew &> /dev/null; then
        echo "Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi
    
    echo "Installing XcodeGen..."
    brew install xcodegen || brew upgrade xcodegen
    
    echo "Installing CMake..."
    brew install cmake || brew upgrade cmake
    
    echo ""
    echo "=== Installation complete ==="
    echo "Run: ./scripts/check-requirements.sh to verify"
else
    echo "This script currently only supports macOS"
    echo "For other platforms, please install manually:"
    echo "  - CMake: https://cmake.org/download/"
    exit 1
fi
