# Quickstart Guide: Clipboard Main Panel UI

**Feature**: 003-clipboard-main-panel
**Last Updated**: 2026-02-04

## Overview

This guide helps you set up a local development environment and run the clipboard main panel UI feature.

## Prerequisites

### Required Software
- **macOS 14+** (Sonoma or later)
- **Xcode 15.0+** (Swift 5.9+ support)
- **Rust 1.70+** (for core layer integration)
- **Git** (for version control)

### Required Hardware
- Mac with Apple Silicon (M1/M2/M3) or Intel-based Mac
- 8GB RAM minimum (16GB recommended)
- 500MB free disk space

## Installation Steps

### 1. Clone Repository

```bash
git clone https://github.com/your-org/pasty.git
cd pasty
```

### 2. Install Rust Dependencies

```bash
# Install Rust if not already installed
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# Install SQLite development libraries
brew install sqlite3
```

### 3. Open Xcode Project

```bash
# Open the Xcode workspace
open Pasty.xcworkspace
```

⚠️ **Note**: Use `.xcworkspace` not `.xcodeproj` because the project uses Swift Package Manager for dependencies.

### 4. Build Project

In Xcode:
1. Select scheme: **Pasty**
2. Select target: **My Mac**
3. Press `⌘B` to build

Or via command line:
```bash
xcodebuild -workspace Pasty.xcworkspace -scheme Pasty -destination 'platform=macOS' build
```

### 5. Run Tests

```bash
# Run Swift tests
xcodebuild test -workspace Pasty.xcworkspace -scheme Pasty -destination 'platform=macOS'

# Run Rust tests
cargo test --manifest-path src/core/Cargo.toml
```

## Development Workflow

### Local Development

1. **Start clipboard history daemon** (feature 002):
   ```bash
   cargo run --bin clipboard-daemon --manifest-path src/core/Cargo.toml
   ```

2. **Launch main panel UI** (this feature):
   ```bash
   open Pasty.app  # Or run from Xcode
   ```

3. **Trigger global keyboard shortcut**:
   - Press `⌘+Shift+V` to open/close main panel

### Debugging

#### Enable Debug Logging

In Xcode:
1. Edit scheme: **Product → Scheme → Edit Scheme**
2. Run → Arguments → Environment Variables
3. Add: `PASTY_LOG_LEVEL = debug`
4. Add: `RUST_LOG = debug`

#### View Clipboard Database

```bash
# Open SQLite database
sqlite3 ~/Library/Application\ Support/Pasty/clipboard-history.db

# Query entries
SELECT id, content_type, timestamp, source_app, is_pinned
FROM clipboard_entries
ORDER BY timestamp DESC
LIMIT 10;

# Exit
.quit
```

### Common Development Tasks

#### Add New Clipboard Entry (Testing)

```bash
# Use pbcopy to add content to clipboard
echo "Test clipboard entry" | pbcopy

# Copy image
screencapture -iC /tmp/clipboard-test.png
# Then manually copy in Preview app
```

#### View Main Panel Logs

```bash
# Console app
open -a Console

# Filter logs
log stream --predicate 'process == "Pasty"' --level debug
```

#### Reset Clipboard History

```bash
# Stop app
killall Pasty

# Delete database
rm ~/Library/Application\ Support/Pasty/clipboard-history.db

# Restart app
open Pasty.app
```

## Project Structure Reference

```
pasty/
├── src/
│   ├── macos/                      # Swift UI layer (this feature)
│   │   ├── ClipboardPanel/         # Main panel window
│   │   │   ├── ClipboardPanel.swift
│   │   │   ├── ClipboardListView.swift
│   │   │   └── PreviewPanel.swift
│   │   ├── Models/                 # Data models
│   │   │   ├── ClipboardEntry.swift
│   │   │   └── MainPanelState.swift
│   │   ├── Services/               # Business logic
│   │   │   ├── ClipboardService.swift
│   │   │   ├── SearchService.swift
│   │   │   └── EncryptionService.swift
│   │   └── Views/                  # Reusable views
│   │       ├── SearchBar.swift
│   │       └── FilterButtons.swift
│   │
│   └── core/                       # Rust core layer (feature 002)
│       └── clipboard/
│           ├── models.rs
│           └── storage.rs
│
├── specs/003-clipboard-main-panel/  # Documentation (this folder)
│   ├── spec.md                     # Feature specification
│   ├── plan.md                     # Implementation plan
│   ├── research.md                 # Technical research
│   ├── data-model.md               # Data model
│   ├── contracts/                  # Service contracts
│   └── quickstart.md               # This file
│
└── Pasty.xcworkspace               # Xcode workspace
```

## Testing Checklist

### Manual Testing

- [ ] **Main Panel Display**
  - [ ] Open panel with `⌘+Shift+V`
  - [ ] Verify entries display in reverse chronological order
  - [ ] Scroll through 100+ entries smoothly
  - [ ] Check empty state message when no entries

- [ ] **Entry Selection**
  - [ ] Click entry, see preview in right panel
  - [ ] Keyboard navigation with arrow keys
  - [ ] Enter key copies selected entry
  - [ ] Escape key closes panel

- [ ] **Copy/Paste Actions**
  - [ ] Click "Copy" button, paste in another app
  - [ ] Click "Paste" button, verify paste happens immediately
  - [ ] Test `⌘C` shortcut
  - [ ] Test `⌘←` shortcut

- [ ] **Search**
  - [ ] Type in search box, verify debouncing (300ms)
  - [ ] Clear search, verify all entries show
  - [ ] Search for non-existent text, see "no results found"

- [ ] **Filters**
  - [ ] Click "All" filter, see all entries
  - [ ] Click "Text" filter, see only text entries
  - [ ] Click "Images" filter, see only image entries
  - [ ] Toggle pinned filter, see only pinned entries

- [ ] **Pin/Unpin**
  - [ ] Pin entry, verify it moves to top
  - [ ] Verify red pushpin icon appears
  - [ ] Unpin entry, verify it returns to normal position
  - [ ] Copy new content, verify pinned entries stay at top

- [ ] **Delete**
  - [ ] Delete single entry, verify removed from list
  - [ ] Delete multiple entries, verify all removed
  - [ ] Verify deletion persists after panel close/reopen

- [ ] **Sensitive Content**
  - [ ] Copy password (e.g., "password: secret123")
  - [ ] Verify warning icon appears
  - [ ] Click entry, verify encryption option offered
  - [ ] Encrypt entry, verify it remains encrypted after restart

### Automated Testing

```bash
# Run unit tests
xcodebuild test -workspace Pasty.xcworkspace -scheme Pasty -destination 'platform=macOS'

# Run with code coverage
xcodebuild test -workspace Pasty.xcworkspace -scheme Pasty \
  -destination 'platform=macOS' \
  -enableCodeCoverage YES

# View coverage report
xcrun llvm-cov report \
  --instr-profile=Pasty.profdata \
  Pasty.app/Contents/MacOS/Pasty
```

## Troubleshooting

### Build Errors

**Error**: `No such module 'SQLite.swift'`
**Solution**: Open Xcode, File → Packages → Reset Package Caches

**Error**: `Command CompileSwift failed`
**Solution**: Clean build folder (`⌘+Shift+K`), then rebuild

**Error**: `Linker error: symbol not found`
**Solution**: Ensure Rust core library is built: `cargo build --release --manifest-path src/core/Cargo.toml`

### Runtime Errors

**Error**: "Database not found"
**Solution**: Start clipboard daemon first: `cargo run --bin clipboard-daemon`

**Error**: "Permission denied accessing Keychain"
**Solution**: Grant Keychain access in System Settings → Privacy & Security → Accessibility

**Error**: "Panel doesn't appear on keyboard shortcut"
**Solution**: Check global hotkey registration in System Settings → Keyboard → Keyboard Shortcuts

### Performance Issues

**Slow scrolling with 1000+ entries**:
- Verify `LazyVStack` is used (not regular `VStack`)
- Check pagination is working (load in chunks of 100)
- Profile with Instruments: `⌘I` in Xcode

**Search takes >300ms**:
- Verify debouncing is active
- Check search runs on background queue
- Profile with Time Profiler

## Keyboard Shortcuts Reference

| Shortcut | Action |
|----------|--------|
| `⌘+Shift+V` | Open/close main panel |
| `↑ / ↓` | Navigate list (up/down) |
| `Enter` | Copy selected entry to clipboard |
| `Escape` | Close main panel |
| `Tab` | Move focus between search, filters, list |
| `⌘C` | Copy selected entry |
| `⌘←` | Paste selected entry (copy + paste) |

## Getting Help

### Documentation
- **Feature Spec**: `specs/003-clipboard-main-panel/spec.md`
- **Implementation Plan**: `specs/003-clipboard-main-panel/plan.md`
- **Data Model**: `specs/003-clipboard-main-panel/data-model.md`
- **Service Contracts**: `specs/003-clipboard-main-panel/contracts/`

### Team Communication
- **Issues**: [GitHub Issues](https://github.com/your-org/pasty/issues)
- **Discussions**: [GitHub Discussions](https://github.com/your-org/pasty/discussions)
- **Slack**: #pasty-dev channel

### Related Features
- **Feature 001**: Rust/Swift Framework (`specs/001-rust-swift-framework/`)
- **Feature 002**: Clipboard History (`specs/002-clipboard-history/`)

## Next Steps

1. ✅ Complete local development setup
2. ✅ Run tests and verify they pass
3. ✅ Implement P1 user stories (Display list + Select/Copy)
4. ✅ Implement P2 user stories (Search, Pin, Keyboard nav)
5. ✅ Implement P3 user stories (Delete)
6. ✅ Write comprehensive tests
7. ✅ Deploy to production

## Version History

- **1.0.0** (2026-02-04): Initial quickstart guide for feature 003
