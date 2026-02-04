#!/bin/bash
# Main build orchestrator for Rust + Swift project

set -euo pipefail

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# Configuration
BUILD_TYPE="${1:-release}"
CLEAN="${2:-noclean}"
ARCH="${3:-universal}"

# Show help
show_help() {
    cat << EOF
Build Orchestrator for Pasty (Rust + Swift)

Usage: $0 [debug|release] [clean|noclean] [arch]

Arguments:
    debug/release      Build configuration (default: release)
    clean/noclean      Clean previous builds (default: noclean)
    arch               Target architecture (default: universal)

Examples:
    $0                    # Build release universal binary
    $0 debug              # Build debug universal binary
    $0 release clean      # Clean and build release
    $0 release noclean x86_64  # Build x86_64 only

EOF
}

# Parse arguments
parse_args() {
    if [[ "${1:-}" == "help" || "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
        show_help
        exit 0
    fi
}

# Check prerequisites
check_prerequisites() {
    log_step "Checking prerequisites..."
    if ! "$SCRIPT_DIR/check-prereqs.sh"; then
        exit 3
    fi
}

# Build core library
build_core_library() {
    log_step "Building Rust core library..."

    local core_args=("$BUILD_TYPE")
    if [[ "$ARCH" != "universal" ]]; then
        core_args+=("$ARCH")
    fi

    if ! "$SCRIPT_DIR/build-core.sh" "${core_args[@]}"; then
        log_error "Core library build failed"
        exit 4
    fi

    log_info "✓ Core library built successfully"
}

# Build macOS app
build_macos_app() {
    log_step "Building macOS app..."

    if ! "$SCRIPT_DIR/build-macos.sh" "$BUILD_TYPE"; then
        log_error "macOS app build failed"
        exit 5
    fi

    log_info "✓ macOS app built successfully"
}

# Show build summary
show_summary() {
    local PROJECT_ROOT="$(get_project_root)"
    log_info "Build Summary:"
    echo "  Configuration: $BUILD_TYPE"
    echo "  Architecture: $ARCH"
    echo "  Clean: $CLEAN"
    echo ""
    echo "Build Artifacts:"

    if [[ -d "$PROJECT_ROOT/build" ]]; then
        find "$PROJECT_ROOT/build" \( -name "*.a" -o -name "*.h" -o -name "*.app" \) 2>/dev/null | while read -r file; do
            echo "  $file"
        done
    fi
}

# Main build sequence
main() {
    log_info "Starting build process..."

    parse_args "$@"
    check_prerequisites

    # Set clean environment variable
    if [[ "$CLEAN" == "clean" ]]; then
        export CLEAN=true
    fi

    # Build core library first
    build_core_library

    # Build macOS app
    build_macos_app

    show_summary
    log_info "✓ Build completed successfully!"
}

main "$@"
