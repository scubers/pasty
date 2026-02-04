#!/bin/bash
# Common utility functions for all build scripts
# Source this file in other scripts: source "$(dirname "$0")/common.sh"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# Get project root directory
get_project_root() {
    echo "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
}

# Check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Compare version numbers (returns 0 if first >= second)
version_ge() {
    [ "$1" = "$(echo -e "$1\n$2" | sort -V | head -n1)" ]
}
