# Tasks: Clipboard Main Panel (macOS)

**Input**: Design documents from `/Users/j/Documents/git-repo/pasty2/specs/002-clipboard-main-panel/`
**Prerequisites**: `/Users/j/Documents/git-repo/pasty2/specs/002-clipboard-main-panel/plan.md`, `/Users/j/Documents/git-repo/pasty2/specs/002-clipboard-main-panel/spec.md`

**Organization**: Tasks are grouped by user story to enable independent implementation and testing.

**Architecture**:
- macOS shell MUST follow MVVM + Combine and the `platform/macos/Sources/` layering.
- View (AppKit or SwiftUI) MUST NOT call Core directly (no direct `pasty_history_*` calls from View).
- Core search semantics MUST live in portable Core and be exposed via the Core C API (`core/include/pasty/api/history_api.h`).

**Approved third-party libraries (macOS shell only)**:
- `KeyboardShortcuts` (global shortcut)
- `SnapKit` (AppKit layout)
- SwiftUI mixed inside AppKit (system framework)

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Add third-party libs via SPM/XcodeGen, ensure background utility behavior, and stop demo UI on launch.

- [ ] T001 Configure background utility behavior (`LSUIElement=true`) in /Users/j/Documents/git-repo/pasty2/platform/macos/Info.plist
- [ ] T002 Add Swift Package dependencies (KeyboardShortcuts, SnapKit) via XcodeGen in /Users/j/Documents/git-repo/pasty2/platform/macos/project.yml
- [ ] T003 Stop showing the demo History window on launch (remove `HistoryWindowController` show-on-launch wiring) in /Users/j/Documents/git-repo/pasty2/platform/macos/Sources/App.swift

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: MVVM + Combine scaffolding, services/adapters, and SwiftUI-in-AppKit main panel skeleton.

- [ ] T004 [P] Add main panel presentation models (rows + preview state) in /Users/j/Documents/git-repo/pasty2/platform/macos/Sources/Model/MainPanelModels.swift
- [ ] T005 [P] Add Core history DTO + JSON decoding helpers for `pasty_history_*_json` payloads in /Users/j/Documents/git-repo/pasty2/platform/macos/Sources/Model/CoreHistoryItemDTO.swift

- [ ] T006 [P] Add HotkeyService protocol + KeyboardShortcutsHotkeyService implementation in /Users/j/Documents/git-repo/pasty2/platform/macos/Sources/Utils/HotkeyService.swift
- [ ] T007 [P] Add PanelPlacement helper (mouse screen + visibleFrame + center-top frame) in /Users/j/Documents/git-repo/pasty2/platform/macos/Sources/Utils/PanelPlacement.swift
- [ ] T008 [P] Add AssetPathResolver (relative image path -> absolute path using Core storage base dir) in /Users/j/Documents/git-repo/pasty2/platform/macos/Sources/Utils/AssetPathResolver.swift

- [ ] T009 [P] Add ClipboardHistoryService protocol + CoreHistoryService adapter (calls Core C API; returns Combine publishers) in /Users/j/Documents/git-repo/pasty2/platform/macos/Sources/Model/ClipboardHistoryService.swift

- [ ] T010 [P] Add MainPanelViewModel skeleton (State/Action; Combine wiring; injected services) in /Users/j/Documents/git-repo/pasty2/platform/macos/Sources/ViewModel/MainPanelViewModel.swift
- [ ] T011 [P] Add SwiftUI main panel view skeleton (search/list/preview/footer; sends actions only) in /Users/j/Documents/git-repo/pasty2/platform/macos/Sources/View/MainPanelView.swift

- [ ] T012 Add MainPanelWindowController that hosts `MainPanelView` (NSHostingView/NSHostingController + SnapKit edge pinning) in /Users/j/Documents/git-repo/pasty2/platform/macos/Sources/View/MainPanelWindowController.swift
- [ ] T013 Wire composition root (instantiate services + ViewModel + window controller; do not show on launch) in /Users/j/Documents/git-repo/pasty2/platform/macos/Sources/App.swift

**Checkpoint**: macOS builds; app launches without opening a window; MVVM skeleton compiles with injected services.

---

## Phase 3: User Story 1 - Open and dismiss the main panel (Priority: P1) 🎯 MVP

**Goal**: Global shortcut toggles the main panel on the current mouse screen; search input is focused; panel dismisses via Escape or clicking outside.

**Independent Test**: Launch app; no window shows; app is not in Dock. Press `cmd+shift+v` to show panel near mouse screen center-top; typing goes into search field. Press `cmd+shift+v` again to hide. Escape hides. Clicking outside hides.

- [ ] T014 [US1] Register `cmd+shift+v` via HotkeyService and dispatch to ViewModel action in /Users/j/Documents/git-repo/pasty2/platform/macos/Sources/App.swift
- [ ] T015 [US1] Implement ViewModel toggle action/state (visible/hidden) in /Users/j/Documents/git-repo/pasty2/platform/macos/Sources/ViewModel/MainPanelViewModel.swift
- [ ] T016 [US1] Implement window toggle behavior (lazy create; placement; activation; show/hide) in /Users/j/Documents/git-repo/pasty2/platform/macos/Sources/View/MainPanelWindowController.swift
- [ ] T017 [US1] Implement SwiftUI search-field focus on open using `@FocusState` driven by ViewModel state in /Users/j/Documents/git-repo/pasty2/platform/macos/Sources/View/MainPanelView.swift
- [ ] T018 [US1] Implement dismissal rules: Escape and losing key (click outside) hide panel via ViewModel action in /Users/j/Documents/git-repo/pasty2/platform/macos/Sources/View/MainPanelWindowController.swift
- [ ] T019 [US1] Render footer shortcuts text (toggle + dismiss) from ViewModel state in /Users/j/Documents/git-repo/pasty2/platform/macos/Sources/View/MainPanelView.swift

---

## Phase 4: User Story 2 - Search and see results update (Priority: P2)

**Goal**: Typing updates results via Core like-matching; empty query shows default recent items; no matches shows explicit empty state.

**Independent Test**: Ensure history exists (copy some text). Open panel and type a partial query; results update as you type; clear query to see recent items; type gibberish to see empty state.

- [ ] T020 [US2] Extend Core store interface to support LIKE search (new method) in /Users/j/Documents/git-repo/pasty2/core/include/pasty/history/store.h
- [ ] T021 [US2] Implement SQLite LIKE search with safe escaping + case-insensitive behavior in /Users/j/Documents/git-repo/pasty2/core/src/history/store_sqlite.cpp
- [ ] T022 [US2] Extend Core history API to expose search (delegates to store) in /Users/j/Documents/git-repo/pasty2/core/include/pasty/history/history.h
- [ ] T023 [US2] Implement Core history search (delegation + cursor/limit semantics) in /Users/j/Documents/git-repo/pasty2/core/src/history/history.cpp

- [ ] T024 [US2] Extend Core C API with `pasty_history_search_json(query, limit)` declaration in /Users/j/Documents/git-repo/pasty2/core/include/pasty/api/history_api.h
- [ ] T025 [US2] Implement `pasty_history_search_json` and JSON payload construction in /Users/j/Documents/git-repo/pasty2/core/src/pasty.cpp

- [ ] T026 [US2] Implement CoreHistoryService `search` by calling Core C API + decoding JSON on a background queue, publishing results via Combine in /Users/j/Documents/git-repo/pasty2/platform/macos/Sources/Model/ClipboardHistoryService.swift
- [ ] T027 [US2] Implement ViewModel search flow (debounce query changes; list when empty; search when non-empty; map DTOs -> rows; error to state) in /Users/j/Documents/git-repo/pasty2/platform/macos/Sources/ViewModel/MainPanelViewModel.swift
- [ ] T028 [US2] Bind SwiftUI results list to rows and show an explicit empty state when query is non-empty and rows is empty in /Users/j/Documents/git-repo/pasty2/platform/macos/Sources/View/MainPanelView.swift

---

## Phase 5: User Story 3 - Select an item and preview it (Priority: P3)

**Goal**: Clicking a row selects it; preview shows text or image plus basic metadata.

**Independent Test**: With text and image items present, click different rows; preview updates correctly; missing image assets show a placeholder (no crash).

- [ ] T029 [US3] Add selection action + selectedId in ViewModel state; update on row click in /Users/j/Documents/git-repo/pasty2/platform/macos/Sources/ViewModel/MainPanelViewModel.swift
- [ ] T030 [US3] Wire SwiftUI row taps/selection -> ViewModel action (no side-effects in View) in /Users/j/Documents/git-repo/pasty2/platform/macos/Sources/View/MainPanelView.swift
- [ ] T031 [US3] Implement preview mapping in ViewModel: derive PreviewState from selected DTO (text vs image) and metadata in /Users/j/Documents/git-repo/pasty2/platform/macos/Sources/ViewModel/MainPanelViewModel.swift
- [ ] T032 [US3] Render preview pane in SwiftUI bound to PreviewState (text scroll/truncation; metadata) in /Users/j/Documents/git-repo/pasty2/platform/macos/Sources/View/MainPanelView.swift
- [ ] T033 [US3] Render image preview via resolved absolute path + scale-to-fit; handle missing file placeholder in /Users/j/Documents/git-repo/pasty2/platform/macos/Sources/View/MainPanelView.swift

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Remove legacy demo UI code, ensure build sanity, and validate quickstart.

- [ ] T034 Remove legacy demo UI files (no longer referenced): /Users/j/Documents/git-repo/pasty2/platform/macos/Sources/View/HistoryWindowController.swift
- [ ] T035 Remove legacy demo UI files (no longer referenced): /Users/j/Documents/git-repo/pasty2/platform/macos/Sources/View/HistoryViewController.swift
- [ ] T036 Remove legacy demo UI files (no longer referenced): /Users/j/Documents/git-repo/pasty2/platform/macos/Sources/ViewModel/HistoryItemViewModel.swift

- [ ] T037 [P] Add diagnostic logging (hotkey, show/hide, search timings) in /Users/j/Documents/git-repo/pasty2/platform/macos/Sources/ViewModel/MainPanelViewModel.swift
- [ ] T038 Run manual verification checklist and record validation notes in /Users/j/Documents/git-repo/pasty2/specs/002-clipboard-main-panel/quickstart.md

---

## Dependencies & Execution Order

### Phase Dependencies

- Phase 1 (Setup) blocks everything else.
- Phase 2 (Foundational) blocks all user story work.
- US1 is required before US2/US3 can be meaningfully validated.
- US2 is required before US3 preview is useful (US3 depends on results list + selection + preview mapping).

### User Story Dependencies

- **US1 (P1)** depends on Phase 1 + Phase 2.
- **US2 (P2)** depends on US1.
- **US3 (P3)** depends on US2.

### Suggested MVP Scope

- MVP = US1 only (hotkey toggle + placement + focus + dismiss).

---

## Parallel Opportunities Identified

- Phase 2: T004-T011 are independent file additions and can be done in parallel ([P] tasks).
- US2 Core work (T020-T025) can be done before macOS wiring (T026-T028).

---

## Parallel Example: US1

```text
Do these in parallel:
- T006 Implement /Users/j/Documents/git-repo/pasty2/platform/macos/Sources/Utils/HotkeyService.swift
- T007 Implement /Users/j/Documents/git-repo/pasty2/platform/macos/Sources/Utils/PanelPlacement.swift
- T011 Implement /Users/j/Documents/git-repo/pasty2/platform/macos/Sources/View/MainPanelView.swift
- T012 Implement /Users/j/Documents/git-repo/pasty2/platform/macos/Sources/View/MainPanelWindowController.swift
Then integrate wiring in T013-T019.
```

## Parallel Example: US2

```text
Do these in parallel:
- T020 Update /Users/j/Documents/git-repo/pasty2/core/include/pasty/history/store.h
- T022 Update /Users/j/Documents/git-repo/pasty2/core/include/pasty/history/history.h
- T024 Update /Users/j/Documents/git-repo/pasty2/core/include/pasty/api/history_api.h
Then implement store/history/C-API in T021, T023, T025 and wire macOS in T026-T028.
```

---

## Implementation Strategy

1) Setup + Foundation: establish MVVM + Combine skeleton and composition root without showing windows on launch.
2) US1 MVP: KeyboardShortcuts toggles a correctly placed/focused panel hosting SwiftUI.
3) US2: Core like-search + debounced ViewModel flow + SwiftUI list UI.
4) US3: selection + preview.
5) Polish: remove demo UI remnants and validate via quickstart.
