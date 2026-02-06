# Tasks: Clipboard History Source Management (macOS)

**Input**: Design documents from `/Users/j/Documents/git-repo/pasty2/specs/001-clipboard-history/`
**Prerequisites**: `/Users/j/Documents/git-repo/pasty2/specs/001-clipboard-history/plan.md`, `/Users/j/Documents/git-repo/pasty2/specs/001-clipboard-history/spec.md`

**Organization**: Tasks are grouped by user story to enable independent implementation and testing.

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Add minimal scaffolding to build, link, and run the new Core+macOS pieces.

- [ ] T001 Add sqlite3 SDK dependency (libsqlite3.tbd) for Pasty2 in /Users/j/Documents/git-repo/pasty2/platform/macos/project.yml
- [ ] T002 [P] Add Core history types in /Users/j/Documents/git-repo/pasty2/core/include/ClipboardHistoryTypes.h
- [ ] T003 [P] Add Core history service API in /Users/j/Documents/git-repo/pasty2/core/include/ClipboardHistory.h
- [ ] T004 [P] Add Core store interface in /Users/j/Documents/git-repo/pasty2/core/include/ClipboardHistoryStore.h
- [ ] T005 Add Core history service implementation skeleton in /Users/j/Documents/git-repo/pasty2/core/src/ClipboardHistory.cpp
- [ ] T006 Add Core store implementation skeleton in /Users/j/Documents/git-repo/pasty2/core/src/ClipboardHistoryStore.cpp
- [ ] T007 Expose new Core headers via /Users/j/Documents/git-repo/pasty2/core/include/module.modulemap
- [ ] T008 Update Core build script to compile new Core sources in /Users/j/Documents/git-repo/pasty2/scripts/core-build.sh

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure that MUST be complete before any user story is complete end-to-end.

- [ ] T009 Define stable IDs and timestamps utilities in /Users/j/Documents/git-repo/pasty2/core/include/ClipboardHistoryTypes.h
- [ ] T010 Implement content hashing helpers (text normalization + byte hashing) in /Users/j/Documents/git-repo/pasty2/core/src/ClipboardHistory.cpp
- [ ] T011 Define SQLite schema (items table + indexes) in /Users/j/Documents/git-repo/pasty2/core/src/ClipboardHistoryStore.cpp
- [ ] T012 Implement database open/close + schema migration (versioning) in /Users/j/Documents/git-repo/pasty2/core/src/ClipboardHistoryStore.cpp
- [ ] T013 Implement atomic image asset write (temp + rename) in /Users/j/Documents/git-repo/pasty2/core/src/ClipboardHistoryStore.cpp
- [ ] T014 Implement basic list query (limit + ordering by last_copy_time_ms desc) in /Users/j/Documents/git-repo/pasty2/core/src/ClipboardHistoryStore.cpp
- [ ] T015 Implement delete-by-id with cascading asset deletion in /Users/j/Documents/git-repo/pasty2/core/src/ClipboardHistoryStore.cpp
- [ ] T016 Implement retention enforcement (max 1000 items) in /Users/j/Documents/git-repo/pasty2/core/src/ClipboardHistoryStore.cpp
- [ ] T017 Add minimal Core logging helper (stderr) in /Users/j/Documents/git-repo/pasty2/core/src/ClipboardHistory.cpp

**Checkpoint**: Core can store/list/delete history items from a local SQLite DB directory with image assets stored on disk.

---

## Phase 3: User Story 1 - Automatically capture copy history (Priority: P1) 🎯 MVP

**Goal**: When user copies text or image in macOS, create a persisted history item (text stored in DB; image stored as file + metadata).

**Independent Test**: Run app, copy a text snippet and an image, then refresh UI list and see both items; restart app and confirm items persist.

- [ ] T018 [P] [US1] Add macOS clipboard watcher skeleton (timer + changeCount) in /Users/j/Documents/git-repo/pasty2/platform/macos/ClipboardWatcher.swift
- [ ] T019 [P] [US1] Add macOS “App data directory” resolver (Application Support) in /Users/j/Documents/git-repo/pasty2/platform/macos/AppPaths.swift
- [ ] T020 [P] [US1] Add source attribution helper (org.nspasteboard.source -> frontmost app -> empty) in /Users/j/Documents/git-repo/pasty2/platform/macos/ClipboardSourceAttribution.swift

- [ ] T021 [US1] Extend Core API to accept base storage directory in /Users/j/Documents/git-repo/pasty2/core/include/Pasty.h
- [ ] T022 [US1] Initialize Core history subsystem on app launch in /Users/j/Documents/git-repo/pasty2/core/src/Pasty.cpp

- [ ] T023 [US1] Implement pasteboard read: preferred text (attributed -> plain) in /Users/j/Documents/git-repo/pasty2/platform/macos/ClipboardWatcher.swift
- [ ] T024 [US1] Implement pasteboard read: images via NSImage readObjects in /Users/j/Documents/git-repo/pasty2/platform/macos/ClipboardWatcher.swift
- [ ] T025 [US1] Detect file/folder clipboard content (file URLs) and ignore + log in /Users/j/Documents/git-repo/pasty2/platform/macos/ClipboardWatcher.swift
- [ ] T026 [US1] Filter transient/concealed markers (skip persist) in /Users/j/Documents/git-repo/pasty2/platform/macos/ClipboardWatcher.swift

- [ ] T027 [US1] Implement Core ingestion API for new text items (no dedupe yet) in /Users/j/Documents/git-repo/pasty2/core/src/ClipboardHistory.cpp
- [ ] T028 [US1] Implement Core ingestion API for new image items (persist asset + store metadata) in /Users/j/Documents/git-repo/pasty2/core/src/ClipboardHistory.cpp

- [ ] T029 [US1] Plumb source_app_id into ingestion calls in /Users/j/Documents/git-repo/pasty2/platform/macos/ClipboardWatcher.swift

---

## Phase 4: User Story 2 - Prevent duplicates by updating recency (Priority: P2)

**Goal**: Copying identical content does not create a new record; it updates last_copy_time_ms (and update_time_ms) and bumps recency.

**Independent Test**: Copy the same text 10 times; list count stays 1 and last_copy_time_ms increases each time. Repeat for same image.

- [ ] T030 [US2] Define dedupe key rules (text normalization + image bytes hash) in /Users/j/Documents/git-repo/pasty2/core/src/ClipboardHistory.cpp
- [ ] T031 [US2] Add content_hash column and index migration in /Users/j/Documents/git-repo/pasty2/core/src/ClipboardHistoryStore.cpp
- [ ] T032 [US2] Implement upsert-by-hash for text (update timestamps instead of insert) in /Users/j/Documents/git-repo/pasty2/core/src/ClipboardHistoryStore.cpp
- [ ] T033 [US2] Implement upsert-by-hash for images (update timestamps instead of insert; do not write duplicate asset) in /Users/j/Documents/git-repo/pasty2/core/src/ClipboardHistoryStore.cpp
- [ ] T034 [US2] Update source_app_id to the most recent source on dedupe hit in /Users/j/Documents/git-repo/pasty2/core/src/ClipboardHistoryStore.cpp
- [ ] T035 [US2] Ensure retention enforcement runs after insert/upsert in /Users/j/Documents/git-repo/pasty2/core/src/ClipboardHistory.cpp

---

## Phase 5: User Story 3 - Review and delete items in a demo UI (Priority: P3)

**Goal**: Demo UI lists recent items (all fields), has refresh and delete; deleting image also deletes stored file.

**Independent Test**: Use only UI to refresh, inspect fields, delete a text item and an image item; restart app and confirm state persists.

- [ ] T036 [P] [US3] Create demo window + layout skeleton in /Users/j/Documents/git-repo/pasty2/platform/macos/HistoryWindowController.swift
- [ ] T037 [P] [US3] Create view controller with table/list for items in /Users/j/Documents/git-repo/pasty2/platform/macos/HistoryViewController.swift
- [ ] T038 [P] [US3] Define Swift view model matching displayed fields in /Users/j/Documents/git-repo/pasty2/platform/macos/HistoryItemViewModel.swift

- [ ] T039 [US3] Expose Core list API to Swift in /Users/j/Documents/git-repo/pasty2/core/include/ClipboardHistory.h
- [ ] T040 [US3] Implement Core list API in /Users/j/Documents/git-repo/pasty2/core/src/ClipboardHistory.cpp
- [ ] T041 [US3] Implement refresh button: call Core list API and render rows in /Users/j/Documents/git-repo/pasty2/platform/macos/HistoryViewController.swift

- [ ] T042 [US3] Expose Core delete API to Swift in /Users/j/Documents/git-repo/pasty2/core/include/ClipboardHistory.h
- [ ] T043 [US3] Implement Core delete API in /Users/j/Documents/git-repo/pasty2/core/src/ClipboardHistory.cpp
- [ ] T044 [US3] Implement delete button per row and refresh list in /Users/j/Documents/git-repo/pasty2/platform/macos/HistoryViewController.swift

- [ ] T045 [US3] Wire demo window into app lifecycle (open on launch) in /Users/j/Documents/git-repo/pasty2/platform/macos/App.swift

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Performance, resilience, and quality improvements that affect multiple stories.

- [ ] T046 [P] Add structured logging strings for capture/ignore/delete in /Users/j/Documents/git-repo/pasty2/platform/macos/ClipboardWatcher.swift
- [ ] T047 Add structured logging strings for store operations (open/migrate/upsert/delete) in /Users/j/Documents/git-repo/pasty2/core/src/ClipboardHistoryStore.cpp
- [ ] T048 Add defensive handling for large payloads (size thresholds + skip+log) in /Users/j/Documents/git-repo/pasty2/platform/macos/ClipboardWatcher.swift
- [ ] T049 Add corruption handling: DB open failure -> recreate/repair strategy in /Users/j/Documents/git-repo/pasty2/core/src/ClipboardHistoryStore.cpp
- [ ] T050 Validate quickstart flow end-to-end and update docs in /Users/j/Documents/git-repo/pasty2/specs/001-clipboard-history/quickstart.md

---

## Dependencies & Execution Order

### Phase Dependencies

- Phase 1 (Setup) blocks everything else.
- Phase 2 (Foundational) blocks user story completion.
- US1 is required before US2/US3 can be meaningfully validated.
- US3 is required for the “UI-only validation” goal in the feature description.

### User Story Dependencies

- **US1 (P1)** depends on Phase 1 + Phase 2.
- **US2 (P2)** depends on US1.
- **US3 (P3)** depends on US1 (Core must store/list/delete for UI to work).

### Suggested MVP Scope

- For this feature, recommend MVP = US1 + a minimal slice of US3 (T036, T037, T039, T040, T041, T045) so the feature is testable via UI.

---

## Parallel Opportunities Identified

- Phase 1: T002-T005 can be done in parallel ([P]).
- Phase 3: T018, T019, T020 can be done in parallel ([P]).
- Phase 5: T036-T038 can be done in parallel ([P]).

---

## Parallel Example: US1

```text
Do these in parallel:
- T018 Create /Users/j/Documents/git-repo/pasty2/platform/macos/ClipboardWatcher.swift
- T019 Create /Users/j/Documents/git-repo/pasty2/platform/macos/AppPaths.swift
- T020 Create /Users/j/Documents/git-repo/pasty2/platform/macos/ClipboardSourceAttribution.swift
Then integrate wiring in T021, T022, T023-T029.
```

## Parallel Example: US3

```text
Do these in parallel:
- T036 Create /Users/j/Documents/git-repo/pasty2/platform/macos/HistoryWindowController.swift
- T037 Create /Users/j/Documents/git-repo/pasty2/platform/macos/HistoryViewController.swift
- T038 Create /Users/j/Documents/git-repo/pasty2/platform/macos/HistoryItemViewModel.swift
Then implement Core bridging + UI refresh/delete in T039-T045.
```

## Implementation Strategy

1) Complete Phase 1 + Phase 2 to make Core persistence real and testable.
2) Implement US1 capture + persist.
3) Add minimal UI slice from US3 so you can validate without dev tools.
4) Implement US2 dedupe.
5) Complete full US3 delete flow.
6) Polish.
