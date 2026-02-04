#!/bin/bash
# Run Rust unit tests with coverage

set -euo pipefail

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

PROJECT_ROOT="$(get_project_root)"
CORE_DIR="$PROJECT_ROOT/core"

log_info "Running Rust unit tests..."

cd "$CORE_DIR"

# Run tests
if ! cargo test; then
    log_error "Tests failed"
    exit 1
fi

# Generate coverage if tarpaulin is installed
if command_exists cargo-tarpaulin; then
    log_info "Generating coverage report..."

    mkdir -p "$PROJECT_ROOT/build/core/coverage"

    if cargo tarpaulin --out Html --output-dir "$PROJECT_ROOT/build/core/coverage"; then
        log_info "✓ Coverage report generated: build/core/coverage/index.html"
    else
        log_warn "Coverage generation failed"
    fi
else
    log_warn "cargo-tarpaulin not found - coverage report not generated"
    log_warn "Install with: cargo install cargo-tarpaulin"
fi

log_info "✓ All tests passed!"
