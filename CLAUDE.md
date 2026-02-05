# pasty Development Guidelines

Auto-generated from all feature plans. Last updated: 2026-02-04

## Active Technologies
- Swift 5.9+ (macOS layer), Rust 1.70+ (core layer) (002-clipboard-history)
- Swift 5.9+ (macOS UI layer), Rust 1.70+ (shared storage layer) + SwiftUI (UI framework), AppKit (window management), SQLite (via Rust from feature 002), Security framework (encryption) (003-clipboard-main-panel)
- SQLite database (shared with feature 002 clipboard history), macOS Keychain (encryption keys) (003-clipboard-main-panel)
- Swift 5.9+ (macOS UI), Rust 1.70+ (core storage) + AppKit, SwiftUI, Combine, KeyboardShortcuts, NSPasteboard, CGEvent (ApplicationServices) (004-clipboard-operations)
- SQLite database + image files via Rust core (core/services/database.rs, core/services/storage.rs) (004-clipboard-operations)

- Rust 1.70+ (core), Swift 5.9+ (macOS layer) (001-rust-swift-framework)

## Project Structure

```text
src/
tests/
```

## Commands

cargo test [ONLY COMMANDS FOR ACTIVE TECHNOLOGIES][ONLY COMMANDS FOR ACTIVE TECHNOLOGIES] cargo clippy

## Code Style

Rust 1.70+ (core), Swift 5.9+ (macOS layer): Follow standard conventions

## Recent Changes
- 004-clipboard-operations: Added Swift 5.9+ (macOS UI), Rust 1.70+ (core storage) + AppKit, SwiftUI, Combine, KeyboardShortcuts, NSPasteboard, CGEvent (ApplicationServices)
- 003-clipboard-main-panel: Added Swift 5.9+ (macOS UI layer), Rust 1.70+ (shared storage layer) + SwiftUI (UI framework), AppKit (window management), SQLite (via Rust from feature 002), Security framework (encryption)
- 002-clipboard-history: Added Swift 5.9+ (macOS layer), Rust 1.70+ (core layer)


<!-- MANUAL ADDITIONS START -->
<!-- MANUAL ADDITIONS END -->
