# Contracts: Internal Boundaries (macOS Shell ↔ Core)

**Feature**: `specs/002-clipboard-main-panel/spec.md`  
**Research**: `specs/002-clipboard-main-panel/research.md`  
**Date**: 2026-02-07

This feature is local-only. These contracts describe stable internal boundaries. They are not network APIs.

## macOS ViewModel → Services

The macOS ViewModel depends on protocols (interfaces) so it can be unit tested. Concrete implementations are assembled in `platform/macos/Sources/App.swift`.

### Contract: HotkeyService

**Purpose**: Register and handle a global hotkey.

- `registerToggleMainPanelHotkey(handler: () -> Void)`
- `unregisterAll()`

**Rules**

- Registers `cmd+shift+v`.
- Invokes handler on hotkey press.

**Implementation note**

- Backed by `KeyboardShortcuts` in the macOS shell.

### Contract: MainPanelWindowService

**Purpose**: Toggle a window/panel and manage focus.

- `show(at: PanelPlacement)`
- `hide()`
- `toggle(at: PanelPlacement)`

**Rules**

- On show: activates app and focuses the search field.
- On hide: hides without mutating history.

**Implementation note**

- The window hosts a SwiftUI main panel view (NSHostingView/NSHostingController).

### Contract: ClipboardHistoryService

**Purpose**: Fetch clipboard history from Core.

- `list(limit: Int) -> Publisher<[ClipboardHistoryItem], Error>`
- `search(query: String, limit: Int) -> Publisher<[ClipboardHistoryItem], Error>`

**Rules**

- `search` uses Core like-matching semantics.
- When query is empty, UI should call `list` (default results).

### Contract: AssetPathResolver

**Purpose**: Resolve image preview paths.

- `resolveAbsoluteImagePath(relativePath: String) -> String`

**Rules**

- Resolution uses the known Core storage base directory.
- If the file is missing, UI must show a placeholder and not crash.

## Core C API

**Purpose**: Provide a narrow bridge for macOS to access Core history.

Existing:

- `pasty_history_list_json(limit)`

Add for this feature:

- `pasty_history_search_json(query, limit)`

**Semantics**

- Returns the same JSON array shape as `pasty_history_list_json`.
- Search is case-insensitive and performs safe literal like-matching (user input wildcards are escaped).
