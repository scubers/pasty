# Research: Clipboard Operation Logic

**Date**: 2026-02-06
**Scope**: Copy, paste, delete operations + main panel key handling. Reuse existing code where available.

## Decisions

### Decision: Use NSPasteboard for copy operations
- **Rationale**: Matches current implementation in `macos/PastyApp/Sources/ViewModels/MainPanelViewModel.swift` and `PreviewPanelViewModel.swift`; aligns with Apple guidance for clipboard writes.
- **Alternatives considered**: Custom clipboard API (rejected; AppKit pasteboard is standard on macOS).
- **References**:
  - https://developer.apple.com/documentation/appkit/nspasteboard
  - https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/PasteboardGuide106/Articles/pbCopying.html

### Decision: Simulate paste with CGEvent (Cmd+V)
- **Rationale**: Existing paste flow already uses CGEvent in `MainPanelViewModel` and `PreviewPanelViewModel`; keeps behavior consistent with current UI expectations.
- **Alternatives considered**: NSEvent global monitor (rejected; read-only, does not inject events).
- **References**:
  - https://levelup.gitconnected.com/swiftui-macos-detect-listen-to-global-key-events-two-ways-df19e565793d

### Decision: Use KeyboardShortcuts for global panel shortcut
- **Rationale**: Existing `ClipboardPanelCoordinator` already registers ⌘+Shift+V; avoids new shortcut registration logic.
- **Alternatives considered**: Carbon HotKey API (rejected; duplicate logic already abstracted by KeyboardShortcuts).
- **References**:
  - https://github.com/soffes/KeyboardShortcuts

### Decision: Reuse existing panel key handling and selection logic
- **Rationale**: `ClipboardPanelWindow` already implements window-level key handling, selection updates, and panel show/hide mechanics.
- **Alternatives considered**: New key handler service (rejected; duplicates existing AppKit window overrides).
- **References**:
  - `macos/PastyApp/Sources/AppKitViews/ClipboardPanelWindow.swift`

### Decision: Reuse Rust core storage and latest_copy_time updates
- **Rationale**: `core/src/services/clipboard_store.rs` and `core/src/services/database.rs` already manage storage and `latest_copy_time_ms` updates; avoid redefining storage logic.
- **Alternatives considered**: Swift-side storage or separate delete store (rejected; breaks cross-platform boundary).
- **References**:
  - `core/src/services/clipboard_store.rs`
  - `core/src/services/database.rs`

## Existing Implementation Inventory (avoid duplicates)

- **Panel shortcut & permissions**: `macos/PastyApp/Sources/Coordinators/ClipboardPanelCoordinator.swift`
- **Panel key handling & selection**: `macos/PastyApp/Sources/AppKitViews/ClipboardPanelWindow.swift`
- **Copy/Paste actions**: `macos/PastyApp/Sources/ViewModels/MainPanelViewModel.swift`, `macos/PastyApp/Sources/ViewModels/PreviewPanelViewModel.swift`
- **Clipboard history access**: `macos/PastyApp/Sources/PlatformLogic/ClipboardHistory.swift` (FFI + mock)
- **Core storage**: `core/src/services/clipboard_store.rs`, `core/src/services/database.rs`
