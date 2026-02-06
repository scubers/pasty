# Implementation Plan: Clipboard Main Panel (macOS)

**Branch**: `002-clipboard-main-panel` | **Date**: 2026-02-07 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/002-clipboard-main-panel/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/commands/plan.md` for the execution workflow.

## Summary

Add a real "main panel" UI for the clipboard app: a global shortcut (`cmd+shift+v`) toggles a three-region panel (search input, results list + preview, footer shortcuts) shown on the screen containing the mouse cursor. Search filters clipboard history with like-matching in the portable Core (SQLite-backed store), and the platform shell focuses the search field on open. Retire the feature-001 demo history window behavior (no window shown automatically on launch).

## Technical Context

<!--
  ACTION REQUIRED: Replace the content in this section with the technical details
  for the project. The structure here is presented in advisory capacity to guide
  the iteration process.
-->

**Language/Version**: C++17 (Core), Swift 5.9 (macOS shell)
**Primary Dependencies**: Cocoa.framework (macOS UI/system integration), system SQLite (local storage), XcodeGen (project generation)
**Storage**: Local SQLite database for history + local files for image assets (paths stored as relative references)
**Testing**: Core unit tests via a minimal clang++ test executable (extend for search); manual macOS end-to-end verification via main panel
**Target Platform**: macOS 14.0+ (feature scope); design keeps Core portable for Windows/Linux parity
**Project Type**: Desktop application (portable C++ Core + macOS native shell)
**Performance Goals**: Panel show/hide feels instantaneous; typical query-to-results update under 100ms for up to 1000 items
**Constraints**: Privacy-first (local-only); Core stays portable (no platform headers); no new top-level directories; no new third-party dependencies; maintain atomic persistence guarantees
**Scale/Scope**: Up to 1000 retained items; results list displays up to 200 items by default; support `text` and `image` items

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Check | Status | Notes |
|-----------|-------|--------|-------|
| **P1: Privacy First** | Does feature handle sensitive clipboard data? | [x] | Main panel is a local UI over local history; no network; no cloud sync; no exports in scope.
| **P2: Performance Responsive** | Are performance goals within constitutional limits? | [x] | Dataset bounded (<=1000); like-matching query constrained and debounced; UI updates avoid heavy work on main thread.
| **P3: Cross-Platform Compatibility** | Is feature feasible across macOS, Windows, Linux? | [x] | UI/hotkey are platform-specific; search semantics live in Core behind a store interface; platform differences documented in research.
| **P4: Data Integrity** | Are atomic writes and data validation addressed? | [x] | This feature adds query paths only; persistence remains unchanged (SQLite + atomic asset writes). Search input is escaped to avoid corrupt queries.
| **P5: Extensible Architecture** | Does feature support plugin/extension model? | [x] | Extend Core API minimally (search query) and keep it stable; UI consumes Core via a narrow C ABI surface.

Re-check after Phase 1 design: PASS (Core portability preserved; no third-party deps; no cloud; contracts remain local/internal).

## Project Structure

### Documentation (this feature)

```text
specs/002-clipboard-main-panel/
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output (/speckit.plan command)
├── data-model.md        # Phase 1 output (/speckit.plan command)
├── quickstart.md        # Phase 1 output (/speckit.plan command)
├── contracts/           # Phase 1 output (/speckit.plan command)
└── tasks.md             # Phase 2 output (/speckit.tasks command - NOT created by /speckit.plan)
```

### Source Code (repository root)
<!--
  ACTION REQUIRED: Replace the placeholder tree below with the concrete layout
  for this feature. Delete unused options and expand the chosen structure with
  real paths (e.g., apps/admin, packages/something). The delivered plan must
  not include Option labels.
-->

```text
core/
├── include/
│   ├── Pasty.h
│   ├── ClipboardHistory.h
│   ├── ClipboardHistoryStore.h
│   └── ClipboardHistoryTypes.h
└── src/
    ├── Pasty.cpp
    ├── ClipboardHistory.cpp
    └── ClipboardHistoryStore.cpp

platform/
└── macos/
    ├── project.yml
    ├── Info.plist
    ├── ARCHITECTURE.md
    ├── Pasty2.xcodeproj/
    └── Sources/
        ├── App.swift
        ├── Utils/
        ├── Model/
        ├── ViewModel/
        └── View/

scripts/
├── build.sh
├── core-build.sh
└── platform-build-macos.sh

specs/
└── 002-clipboard-main-panel/
    ├── spec.md
    ├── plan.md
    ├── research.md
    ├── data-model.md
    ├── quickstart.md
    └── contracts/
```

**Structure Decision**: Keep all business rules and data access (history list/search/delete) in portable C++ Core behind a store interface. macOS is a thin shell: hotkey registration, window/panel presentation, input focus, and rendering list/preview.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| [e.g., 4th project] | [current need] | [why 3 projects insufficient] |
| [e.g., Repository pattern] | [specific problem] | [why direct DB access insufficient] |

## Phase 0: Research (output: research.md)

- Decide global hotkey registration approach with minimal permissions and no third-party dependencies.
- Decide main panel window type and focus/activation sequence for a background utility app.
- Decide how to choose the target screen (mouse location) and compute the "center-top" position.
- Decide Core search semantics (like-matching) and how to safely escape user input in SQLite LIKE.

## Phase 1: Design & Contracts (outputs: data-model.md, contracts/*, quickstart.md)

- Define UI state and Core-facing data needed for main panel (search query, results, selection, preview).
- Define stable internal contracts (not network): list recent, search, delete, and image asset path resolution.
- Define quickstart steps to build and manually verify the new main panel behavior.

## Phase 1: Agent Context Update

- Run `/Users/j/Documents/git-repo/pasty2/.specify/scripts/bash/update-agent-context.sh` to record the tech stack and paths for this feature.

## Phase 2: Planning Handoff

- Decompose implementation into tasks.md via `/speckit.tasks` (not created by `/speckit.plan`).
