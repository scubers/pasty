# Tasks: Clipboard Operation Logic

**Input**: Design documents from `/specs/004-clipboard-operations/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/

**Tests**: Not requested in spec.md. No test tasks included.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Confirm integration points and reuse existing code paths.

No setup tasks required. Existing structure and integration points are already in place.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure required by all user stories.

**⚠️ CRITICAL**: No user story work can begin until this phase is complete.

- [x] T001 [P] Add single-entry delete API in `core/src/services/clipboard_store.rs` and `core/src/services/database.rs` (remove DB row and linked image file via `core/src/services/storage.rs`)
- [x] T002 [P] Add batch delete API in `core/src/services/clipboard_store.rs` and `core/src/services/database.rs` (delete by id list)
- [x] T003 [P] Add update-latest-copy-time API by entry id in `core/src/services/clipboard_store.rs` and `core/src/services/database.rs` (do not rely on content_hash)
- [x] T004 [P] Expose delete/update APIs via FFI in `core/src/ffi/clipboard.rs` and `core/src/lib.rs`
- [x] T005 [P] Extend Swift FFI declarations in `macos/PastyApp/Sources/FFI/FFIDeclarations.swift` for delete and update-latest-copy-time APIs
- [x] T006 Add Swift bridge helpers in `macos/PastyApp/Sources/PlatformLogic/ClipboardHistory.swift` for delete and latest-copy-time updates

**Checkpoint**: Core delete/update-copy-time operations are available via FFI and callable from Swift.

---

## Phase 3: User Story 1 - Copy Entry to System Clipboard (Priority: P1) 🎯 MVP

**Goal**: Copy selected history entry to system clipboard (text and image) and update copy timestamps.

**Independent Test**: Select a text/image entry, trigger copy, paste into another app, and confirm content matches and latest copy time updates.

### Implementation for User Story 1

- [x] T007 [US1] Update `MainPanelViewModel.copyEntry` in `macos/PastyApp/Sources/ViewModels/MainPanelViewModel.swift` to support image copy and update latest_copy_time via `ClipboardHistory`
- [x] T008 [US1] Update `PreviewPanelViewModel.handleCopyAction` in `macos/PastyApp/Sources/ViewModels/PreviewPanelViewModel.swift` to copy images and update latest_copy_time
- [x] T009 [US1] Add Cmd+Enter handling in `macos/PastyApp/Sources/AppKitViews/ClipboardPanelWindow.swift` to trigger copy without paste and keep search focus

**Checkpoint**: User Story 1 complete and independently testable.

---

## Phase 4: User Story 2 - Copy and Paste in Single Action (Priority: P1)

**Goal**: Copy selected entry and paste into the previously active application in one action, with graceful fallback.

**Independent Test**: Trigger paste action while a text editor is focused and confirm content appears without manual paste.

### Implementation for User Story 2

- [x] T010 [US2] Capture previous active app on panel show in `macos/PastyApp/Sources/AppKitViews/ClipboardPanelWindow.swift` (or coordinator) and expose for paste decisions
- [x] T011 [US2] Update `MainPanelViewModel.pasteEntry` in `macos/PastyApp/Sources/ViewModels/MainPanelViewModel.swift` to skip Cmd+V when previous app is this app and to handle no-focused-app case
- [x] T012 [US2] Update Enter key handling and down-arrow wrap-around in `macos/PastyApp/Sources/AppKitViews/ClipboardPanelWindow.swift` for paste+close and list navigation
- [x] T013 [US2] Align `PreviewPanelViewModel.handlePasteAction` in `macos/PastyApp/Sources/ViewModels/PreviewPanelViewModel.swift` with previous-app skip logic

**Checkpoint**: User Stories 1 and 2 both independently functional.

---

## Phase 5: User Story 4 - Delete Clipboard Entries (Priority: P2)

**Goal**: Delete single or multiple entries with confirmation and proper list/preview updates.

**Independent Test**: Delete selected entries and confirm they are removed from list, DB, and image storage.

### Implementation for User Story 4

- [x] T014 [US4] Present delete confirmation as a sheet above the panel in `macos/PastyApp/Sources/AppKitViews/ClipboardPanelWindow.swift`
- [x] T015 [US4] Update `MainPanelViewModel.deleteEntry`/`deleteEntries` in `macos/PastyApp/Sources/ViewModels/MainPanelViewModel.swift` to call `ClipboardHistory` delete APIs and adjust selection per spec
- [x] T016 [US4] Update Cmd+D handling in `macos/PastyApp/Sources/AppKitViews/ClipboardPanelWindow.swift` to trigger delete flow and keep search focus

**Checkpoint**: Delete flow is functional, confirmed, and fully synchronized with storage.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Logging, error feedback, and quickstart validation.

- [x] T017 [P] Add operation logging and user-facing error messages in `macos/PastyApp/Sources/ViewModels/MainPanelViewModel.swift` and `macos/PastyApp/Sources/ViewModels/PreviewPanelViewModel.swift`
- [x] T018 Validate quickstart steps and update `specs/004-clipboard-operations/quickstart.md` if deviations are found

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Stories (Phases 3-5)**: All depend on Foundational phase completion
- **Polish (Phase 6)**: Depends on all desired user stories being complete

### User Story Dependencies

- **User Story 1 (P1)**: Can start after Foundational (Phase 2) - no dependencies
- **User Story 2 (P1)**: Depends on US1 copy behavior and Foundational APIs
- **User Story 4 (P2)**: Depends on Foundational delete APIs; can proceed after US1/US2 if needed

### Within Each User Story

- Models/FFI before ViewModel usage
- ViewModel updates before panel window key handling
- Story complete before moving to next priority

### Parallel Opportunities

- **Phase 2**: T001, T002, T003, T004, T005 can run in parallel (different files/layers)
- **US1**: T007 and T008 can run in parallel (different view models)
- **US2**: T011 and T013 can run in parallel after T010
- **US4**: T014 and T015 can run in parallel after FFI is available

---

## Parallel Example: User Story 1

```text
Task: "Update MainPanelViewModel copy flow in macos/PastyApp/Sources/ViewModels/MainPanelViewModel.swift"
Task: "Update PreviewPanelViewModel copy flow in macos/PastyApp/Sources/ViewModels/PreviewPanelViewModel.swift"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational (CRITICAL - blocks all stories)
3. Complete Phase 3: User Story 1
4. **STOP and VALIDATE**: Test User Story 1 independently

### Incremental Delivery

1. Setup + Foundational → Foundation ready
2. Add User Story 1 → Validate copy
3. Add User Story 2 → Validate paste
4. Add User Story 4 → Validate delete

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story
- Each user story should be independently completable and testable
