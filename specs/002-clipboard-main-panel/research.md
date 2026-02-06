# Research: Clipboard Main Panel (macOS)

**Feature**: `specs/002-clipboard-main-panel/spec.md`  
**Plan**: `specs/002-clipboard-main-panel/plan.md`  
**Date**: 2026-02-07

This document resolves technical decisions for implementing the macOS main panel while strictly following:

- `platform/macos/ARCHITECTURE.md` (MVVM + Combine; Sources/ layering)
- `core/ARCHITECTURE.md` (portable Core; history/search semantics in Core; C API in `include/pasty/api/`)

## Decision 1: macOS layer must be MVVM + Combine (no Core calls from View)

**Decision**: Implement the main panel UI using MVVM and Combine. Views (ViewControllers/NSViews) only render `State` and send `Action` to the ViewModel. Core is accessed only through injected Services/Adapters owned by the ViewModel.

**Rationale**:
- Required by `platform/macos/ARCHITECTURE.md`.
- Keeps UI thin and testable (ViewModel can be tested with stubbed services).

**Alternatives considered**:
- View directly calling `pasty_history_list_json`: rejected (architecture violation).

## Decision 2: Background utility behavior (no Dock icon)

**Decision**: Configure the app to run as a background utility so it does not appear in the Dock during normal use.

**Rationale**:
- Required by feature spec (FR-001).
- Common UX for clipboard utilities.

**Alternatives considered**:
- Standard Dock app: rejected (does not match product intent).

## Decision 3: Global hotkey registration

**Decision**: Implement `cmd+shift+v` as a global hotkey using `KeyboardShortcuts`.

**Rationale**:
- Low code volume compared to direct Carbon usage.
- Provides a clean API for registering and handling shortcuts.
- Still avoids Accessibility/Input Monitoring permission prompts required by event-tap approaches.

**Alternatives considered**:
- Direct Carbon `RegisterEventHotKey`: works, but more verbose.
- `NSEvent.addGlobalMonitorForEvents`: may require Accessibility permissions; cannot consume events.
- `CGEventTap`: requires Input Monitoring permission; increases security surface.

**Source**:
- https://github.com/sindresorhus/KeyboardShortcuts

## Decision 3a: Layout DSL

**Decision**: Use `SnapKit` for AppKit view layout where AppKit constraints are needed (e.g., hosting SwiftUI content inside a window).

**Rationale**:
- Reduces boilerplate compared to manual Auto Layout constraints.

**Source**:
- https://github.com/SnapKit/SnapKit

## Decision 4: Main panel window type and activation

**Decision**: Implement the main panel as a dedicated panel-like window (NSPanel or configured NSWindow) created lazily and toggled by the hotkey. When shown, activate the app and focus the search input.

**Rationale**:
- Meets US1 (toggle + focus) and works with background-utility activation.
- Avoids opening windows on launch.

**Alternatives considered**:
- Always-open demo window: rejected (FR-017).
- Non-activating panel: rejected (search input focus and typing reliability).

## Decision 4a: SwiftUI content hosted in AppKit

**Decision**: Use an AppKit window/panel as the outer container and host the main panel content as a SwiftUI view (embedded via `NSHostingController`/`NSHostingView`).

**Rationale**:
- Lower code volume for composing the split layout (search + list + preview + footer).
- Fits macOS MVVM guidance: SwiftUI View binds to ViewModel state and sends actions.

**Notes**:
- Initial focus for the search field should be driven by ViewModel state and implemented with SwiftUI `@FocusState`.

## Decision 5: Screen selection and positioning

**Decision**: On open, choose the screen containing the mouse cursor and position the panel using that screen's `visibleFrame`, centered horizontally and slightly above vertical center.

**Rationale**:
- Matches FR-004/FR-005.
- Using visible frame avoids menu bar and Dock overlap.

## Decision 6: Search semantics live in portable Core (SQLite LIKE)

**Decision**: Implement like-matching search in Core (SQLite store) with safe escaping and case-insensitive matching. Expose it to macOS via a narrow C API alongside the existing JSON list API.

**Rationale**:
- Required by `core/ARCHITECTURE.md`: search semantics belong in Core.
- Enables future cross-platform UI reuse.
- Avoids duplicating search logic in macOS shell.

**Alternatives considered**:
- UI-side filtering of `list_json` results: rejected (platform duplication and inconsistent semantics).
- Full-text search: rejected (scope/complexity not justified for <=1000 items).

## Decision 7: Remove feature-001 demo UI behavior

**Decision**: Remove/disable the History demo window and any demo-only behavior introduced in feature 001.

**Rationale**:
- Required by FR-016/FR-017.
- Demo UI currently violates MVVM boundaries (direct Core calls from View); replacing with a properly layered main panel resolves this.

## Citations

- KeyboardShortcuts: https://github.com/sindresorhus/KeyboardShortcuts
- SnapKit: https://github.com/SnapKit/SnapKit
- SwiftUI focus: https://developer.apple.com/documentation/swiftui/focused(_:equals:)
