# Implementation Plan: Clipboard Main Panel (macOS)

**Branch**: `002-clipboard-main-panel` | **Date**: 2026-02-07 | **Spec**: `/Users/j/Documents/git-repo/pasty2/specs/002-clipboard-main-panel/spec.md`
**Input**: Feature specification from `/Users/j/Documents/git-repo/pasty2/specs/002-clipboard-main-panel/spec.md`

**Architecture References (must follow)**:
- `/Users/j/Documents/git-repo/pasty2/platform/macos/ARCHITECTURE.md` (MVVM + Combine; `platform/macos/Sources/` layering)
- `/Users/j/Documents/git-repo/pasty2/core/ARCHITECTURE.md` (portable Core; C API location)
- `/Users/j/Documents/git-repo/pasty2/.specify/memory/constitution.md` (P1-P5)

## Summary

Implement the application's main panel on macOS with lower implementation code volume by adopting approved third-party libraries:

- **Hotkey**: use `KeyboardShortcuts` to register `cmd+shift+v` and toggle panel visibility.
- **Layout**: use `SnapKit` for AppKit layout where AppKit views are used.
- **UI**: keep an outer AppKit window/panel, and embed a simple SwiftUI view inside it for the main panel contents.

Core behavior remains unchanged: clipboard history and like-matching search semantics live in portable Core (SQLite store). macOS remains a thin shell.

## Technical Context

**Language/Version**: C++17 (Core), Swift 5.9 (macOS shell)  
**Primary Dependencies**: Cocoa.framework (AppKit), SwiftUI (system), Combine (system), XcodeGen, system SQLite  
**Third-Party Dependencies (explicitly approved)**: `KeyboardShortcuts` (hotkey), `SnapKit` (layout) via Swift Package Manager  
**Storage**: Local SQLite database for history + local files for image assets (relative paths)  
**Testing**: Core built with CMake via `/Users/j/Documents/git-repo/pasty2/scripts/core-build.sh`; macOS built via `/Users/j/Documents/git-repo/pasty2/scripts/platform-build-macos.sh Debug`; manual verification via `/Users/j/Documents/git-repo/pasty2/specs/002-clipboard-main-panel/quickstart.md`  
**Target Platform**: macOS 14.0+  
**Project Type**: Desktop app (portable Core + macOS thin shell)  
**Performance Goals**: UI operations remain responsive (<100ms typical for <=1000 items); search input uses debounce + bounded result count  
**Constraints**: Privacy-first (local-only); Core portable (no platform headers); macOS shell must follow MVVM + Combine; no new top-level directories  
**Scale/Scope**: <=1000 items retained; list shows up to 200 items; supports text and image items

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Check | Status | Notes |
|-----------|-------|--------|-------|
| **P1: Privacy First** | Does feature handle sensitive clipboard data? | [x] | Local-only; no network/sync; panel is a viewer over local history.
| **P2: Performance Responsive** | Are performance goals within constitutional limits? | [x] | Debounced search; bounded result size; Core query uses SQLite; avoid blocking main thread in adapters.
| **P3: Cross-Platform Compatibility** | Is feature feasible across macOS, Windows, Linux? | [x] | UI libs are macOS-only; Core search API remains portable and reusable by future shells.
| **P4: Data Integrity** | Are atomic writes and data validation addressed? | [x] | This feature adds query paths; persistence rules stay in Core.
| **P5: Extensible Architecture** | Does feature support plugin/extension model? | [x] | ViewModel depends on protocols; Core API extension is minimal and stable.

Re-check after Phase 1 design: PASS.

## Project Structure

### Documentation (this feature)

```text
/Users/j/Documents/git-repo/pasty2/specs/002-clipboard-main-panel/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
└── tasks.md
```

### Source Code (repository root)

```text
/Users/j/Documents/git-repo/pasty2/core/
├── include/pasty/
│   ├── pasty.h
│   ├── api/history_api.h
│   └── history/
│       ├── types.h
│       ├── history.h
│       └── store.h
└── src/
    ├── pasty.cpp
    └── history/
        ├── history.cpp
        └── store_sqlite.cpp

/Users/j/Documents/git-repo/pasty2/platform/macos/
├── project.yml
├── Info.plist
└── Sources/
    ├── App.swift
    ├── Utils/
    ├── Model/
    ├── ViewModel/
    └── View/
```

**Structure Decision**:
- Core: history list/search semantics and persistence in portable C++.
- macOS: MVVM + Combine. AppKit window/panel container hosts a SwiftUI main panel view (for faster UI iteration) and sends user events as actions to the ViewModel.
- Third-party libs are used only in macOS shell.

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| Third-party dependencies (KeyboardShortcuts, SnapKit) | Reduce code volume for hotkey and layout | Native Carbon + manual Auto Layout are more verbose |

## Phase 0: Research (output: research.md)

- Confirm best-practice integration of KeyboardShortcuts with a background utility app (activation + focus).
- Confirm a clean pattern for hosting SwiftUI in AppKit while preserving MVVM + Combine boundaries.
- Confirm how to add SPM packages via XcodeGen (`project.yml`) for this repo.
- Confirm Core LIKE search API shape and safe escaping approach.

## Phase 1: Design & Contracts (outputs: data-model.md, contracts/*, quickstart.md)

- Define `MainPanelViewModel.State`/`Action` and how SwiftUI View binds to state and emits actions.
- Define macOS adapter protocols: HotkeyService (KeyboardShortcuts-backed), ClipboardHistoryService (Core C API-backed), AssetPathResolver.
- Define Core additions: `pasty_history_search_json` in `/Users/j/Documents/git-repo/pasty2/core/include/pasty/api/history_api.h` and implementation in `/Users/j/Documents/git-repo/pasty2/core/src/pasty.cpp`.

## Phase 2: Planning Handoff

- Decompose implementation into `/Users/j/Documents/git-repo/pasty2/specs/002-clipboard-main-panel/tasks.md`.
