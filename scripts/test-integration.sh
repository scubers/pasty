#!/bin/bash
# Run Swift-Rust FFI integration tests

set -euo pipefail

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

PROJECT_ROOT="$(get_project_root)"
TEST_FILE="$PROJECT_ROOT/tests/integration/test_swift_rust_ffi.swift"

log_info "Running Swift-Rust FFI integration tests..."

# Check if test file exists
if [[ ! -f "$TEST_FILE" ]]; then
    log_error "Integration test file not found: $TEST_FILE"
    exit 1
fi

# Check if Rust library is built
RUST_LIB="$PROJECT_ROOT/target/universal/release/libpasty_core.a"
if [[ ! -f "$RUST_LIB" ]]; then
    log_error "Rust library not found: $RUST_LIB"
    log_info "Run ./scripts/build.sh release first"
    exit 2
fi

# Build the test executable with Rust library linked
log_step "Building integration test..."

TEST_EXECUTABLE="$PROJECT_ROOT/tests/integration/test_swift_rust_ffi"

if ! swiftc -target arm64-apple-macos14.0 \
           -L "$PROJECT_ROOT/target/universal/release" \
           -Xlinker -lpasty_core \
           "$TEST_FILE" \
           -o "$TEST_EXECUTABLE"; then
    log_error "Failed to build integration test"
    exit 3
fi

# Run the test
log_step "Running integration tests..."
if ! "$TEST_EXECUTABLE"; then
    log_error "Integration tests failed"
    exit 4
fi

log_info "✓ All integration tests passed!"
exit 0
