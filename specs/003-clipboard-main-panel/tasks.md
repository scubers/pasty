# Tasks: Clipboard Main Panel UI

**Feature**: 003-clipboard-main-panel
**Branch**: `003-clipboard-main-panel`
**Input**: Design documents from `/specs/003-clipboard-main-panel/`

**Tests**: Included - following Test-First Development (TDD) per constitution requirements

**Organization**: Tasks grouped by user story to enable independent implementation and testing

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story (US1-US6)
- **Paths**: Based on plan.md structure: `src/macos/`, `tests/`

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization and SPM dependencies setup

- [ ] T001 Create src/macos directory structure per plan.md (Models, ViewModels, AppKitViews, SwiftUIViews, Services, Coordinators, Utils)
- [ ] T002 Add SPM dependencies via Xcode: SnapKit 5.7+, KeyboardShortcuts 1.0+, SQLite.swift 0.14+ (File → Add Package Dependencies)
- [ ] T003 [P] Create tests/macos directory structure (ViewModels, Services, AppKitViews, Integration)
- [ ] T004 [P] Create Logging utility in src/macos/Utils/Logging/Logger.swift with structured JSON output (error, warn, info, debug levels)
- [ ] T005 [P] Create String+Extensions, Date+Formatter, NSImage+Thumbnail extensions in src/macos/Utils/Extensions/

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure that MUST be complete before ANY user story can be implemented

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

### Data Models (UI-Agnostic)

- [ ] T006 [P] Create ClipboardEntry model in src/macos/Models/ClipboardEntry.swift (id, content, contentType, timestamp, sourceApp, isPinned, isEncrypted, sensitiveType)
- [ ] T007 [P] Create ContentType enum in src/macos/Models/ContentType.swift (text, image)
- [ ] T008 [P] Create ClipboardEntryListItem model in src/macos/Models/ClipboardEntryListItem.swift (title, preview, timestamp, sourceApp, sourceIcon, contentType, isPinned, isSelected, isSensitive)
- [ ] T009 [P] Create ContentFilter enum in src/macos/Models/ContentFilter.swift (all, text, images)
- [ ] T010 [P] Create PreviewContent enum in src/macos/Models/PreviewContent.swift (text, image, empty)
- [ ] T011 [P] Create UserAction enum in src/macos/Models/UserAction.swift (loadEntries, selectEntry, copyEntry, pasteEntry, deleteEntry, pinEntry, search, filter)

### Service Layer (Stateless, Combine Publishers)

- [ ] T012 Implement ClipboardService protocol in src/macos/Services/ClipboardService.swift (loadEntries, loadEntry, copyToClipboard, copyAndPaste, deleteEntry, deleteEntries, setPinned, encryptEntry, decryptEntry - all return AnyPublisher)
- [ ] T013 Implement SearchService in src/macos/Services/SearchService.swift (search, filterByContentType, filterByPinned, applyFilters - pure functions)
- [ ] T014 Implement EncryptionService in src/macos/Services/EncryptionService.swift (encrypt, decrypt, generateKey, deleteKey - async/await, Keychain integration)
- [ ] T015 Implement ThumbnailCache in src/macos/Services/ThumbnailCache.swift (get, set, clear - in-memory LRU cache, max 100 entries)
- [ ] T016 Create Date+Formatter extension in src/macos/Utils/Extensions/Date+Formatter.swift (formatAsTimeAgo, formatAsDateTime)

**Checkpoint**: Foundation ready - Models, Services, and Extensions in place. User story implementation can now begin in parallel.

---

## Phase 3: User Story 1 - Display Clipboard History List (Priority: P1) 🎯 MVP

**Goal**: Display clipboard history in scrollable list with timestamps, source apps, content previews

**Independent Test**: Open main panel → shows list of 10+ entries in reverse chronological order with content preview, timestamp, source app

### Tests for User Story 1

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation**

- [ ] T017 [P] [US1] Write unit test in tests/macos/ViewModels/MainPanelViewModelTests.swift (testLoadEntries_UpdatesPublishedEntriesProperty)
- [ ] T018 [P] [US1] Write unit test in tests/macos/ViewModels/MainPanelViewModelTests.swift (testLoadEntries_SortsByTimestampDescending)
- [ ] T019 [P] [US1] Write unit test in tests/macos/Services/ClipboardServiceTests.swift (testLoadEntries_ReturnsPublisherWithEntries)
- [ ] T020 [P] [US1] Write integration test in tests/macos/Integration/ClipboardPanelIntegrationTests.swift (testOpenPanel_DisplaysClipboardList)

### Implementation for User Story 1

#### ViewModels

- [ ] T021 [US1] Create MainPanelViewModel in src/macos/ViewModels/MainPanelViewModel.swift (@Published var allEntries, filteredEntries, searchText, contentFilter, selectedEntryId, isLoading - handleUserAction, setupBindings, loadEntries, updateFilters)
- [ ] T022 [US1] Create ClipboardListViewModel in src/macos/ViewModels/ClipboardListViewModel.swift (@Published var entries, isLoading, selectedRow - onSelectEntry, loadEntries, bindToMainPanelViewModel)

#### AppKit Views (Performance-Critical)

- [ ] T023 [US1] Create ClipboardPanelWindow (NSPanel) in src/macos/AppKitViews/ClipboardPanelWindow.swift (init with contentRect and styleMask .borderless, showPanel, hidePanel, setupTableView, setupLayout using SnapKit, floating panel behavior)
- [ ] T024 [US1] Create ClipboardTableView wrapper in src/macos/AppKitViews/ClipboardTableView.swift (NSTableView setup, dataSource, delegate, reloadData, bind to ViewModel via Combine $entries.sink { tableView.reloadData() })
- [ ] T025 [US1] Create ClipboardTableCellView in src/macos/AppKitViews/ClipboardTableCellView.swift (titleLabel: NSTextField, sourceIcon: NSImageView, timestampLabel: NSTextField, typeIndicator: NSView, pinnedIndicator: NSView - configure with entry using SnapKit layout)
- [ ] T026 [US1] Create EmptyStateView in src/macos/AppKitViews/EmptyStateView.swift (NSView with message label and icon, centered layout)

#### SwiftUI Views (Simple Components - Optional for US1)

- [ ] T027 [P] [US1] Create PinnedIndicatorView in src/macos/SwiftUIViews/Components/PinnedIndicatorView.swift (red pushpin icon)
- [ ] T028 [P] [US1] Create TypeIndicatorView in src/macos/SwiftUIViews/Components/TypeIndicatorView.swift (colored square: red for text, green for image)

#### Coordinator

- [ ] T029 [US1] Create ClipboardPanelCoordinator in src/macos/Coordinators/ClipboardPanelCoordinator.swift (init with ClipboardPanelWindow and MainPanelViewModel, showPanel, hidePanel, setupBindings between window and ViewModel)

#### Integration

- [ ] T030 [US1] Wire up ClipboardService.loadEntries to MainPanelViewModel in MainPanelViewModel.loadEntries (subscribe to publisher, map to ClipboardEntryListItem, update @Published allEntries, handle errors)
- [ ] T031 [US1] Bind MainPanelViewModel.$filteredEntries to ClipboardTableView.reloadData using Combine in ClipboardPanelCoordinator
- [ ] T032 [US1] Implement NSTableViewDataSource numberOfRows and viewFor tableColumn in ClipboardTableView (return viewModel.entries.count, dequeue ClipboardTableCellView, configure with entry data)
- [ ] T033 [US1] Implement NSTableViewDelegate selection handling in ClipboardTableView (didClickTableRowAt, call viewModel.onSelectEntry(row))
- [ ] T034 [US1] Add SnapKit Auto Layout constraints in ClipboardTableCellView.configure (title.leadingAnchor, sourceIcon.trailingAnchor, timestamp.topAnchor, etc.)
- [ ] T035 [US1] Add SnapKit Auto Layout constraints for main panel layout in ClipboardPanelWindow.setupLayout (tableView edges, previewPanel edges, divider)
- [ ] T036 [US1] Show empty state when viewModel.entries.isEmpty in ClipboardTableView (hide tableView, show EmptyStateView)

**Checkpoint**: User Story 1 complete - Main panel opens and displays clipboard list. Can be tested and validated independently.

---

## Phase 4: User Story 2 - Select and Copy Clipboard Entry (Priority: P1)

**Goal**: Select entries and copy content to system clipboard

**Independent Test**: Click entry → copy to clipboard → paste in another app → content matches original

### Tests for User Story 2

- [ ] T037 [P] [US2] Write unit test in tests/macos/ViewModels/PreviewPanelViewModelTests.swift (testHandleCopyAction_CallsClipboardService)
- [ ] T038 [P] [US2] Write unit test in tests/macos/Services/ClipboardServiceTests.swift (testCopyToClipboard_WithValidId_SetsClipboardContent)
- [ ] T039 [P] [US2] Write integration test in tests/macos/Integration/ClipboardPanelIntegrationTests.swift (testSelectEntry_CopiesToClipboard)

### Implementation for User Story 2

#### ViewModels

- [ ] T040 [US2] Create PreviewPanelViewModel in src/macos/ViewModels/PreviewPanelViewModel.swift (@Published var previewContent, copyButtonEnabled, pasteButtonEnabled - handleCopyAction, handlePasteAction, loadPreviewContent)
- [ ] T041 [US2] Add onSelectEntry(id: String) to ClipboardListViewModel (update selectedRow, notify MainPanelViewModel)

#### AppKit Views

- [ ] T042 [US2] Create PreviewPanelContainer in src/macos/AppKitViews/PreviewPanelContainer.swift (NSView container with NSHostingController<PreviewPanelView>, SnapKit layout for preview area and action buttons)
- [ ] T043 [US2] Add Copy and Paste buttons to PreviewPanelContainer in src/macos/AppKitViews/PreviewPanelContainer.swift (NSButton with target-action, bind to PreviewPanelViewModel.$copyButtonEnabled)

#### SwiftUI Views

- [ ] T044 [P] [US2] Create PreviewPanelView in src/macos/SwiftUIViews/PreviewPanel/PreviewPanelView.swift (observes PreviewPanelViewModel, TextPreviewView, ImagePreviewView, Copy button, Paste button, keyboard shortcut hints)
- [ ] T045 [P] [US2] Create TextPreviewView in src/macos/SwiftUIViews/PreviewPanel/TextPreviewView.swift (ScrollView with Text, line wrapping)
- [ ] T046 [P] [US2] Create ImagePreviewView in src/macos/SwiftUIViews/PreviewPanel/ImagePreviewView.swift (Image.resizable, scaledToFit)

#### Service Implementation

- [ ] T047 [US2] Implement ClipboardService.copyToClipboard in src/macos/Services/ClipboardService.swift (loadEntry from database, decrypt if encrypted, set NSPasteboard.general.content, return Void publisher)
- [ ] T048 [US2] Implement ClipboardService.copyAndPaste in src/macos/Services/ClipboardService.swift (copyToClipboard + simulate keyboard Cmd+V using CGEvent, return Void publisher)

#### Integration

- [ ] T049 [US2] Wire up NSTableView selection to PreviewPanelViewModel.loadPreviewContent in ClipboardPanelCoordinator (on selection change, call clipboardService.loadEntry(id), update previewContent)
- [ ] T050 [US2] Connect Copy button to PreviewPanelViewModel.handleCopyAction in PreviewPanelContainer.button target-action
- [ ] T051 [US2] Connect Paste button to PreviewPanelViewModel.handlePasteAction in PreviewPanelContainer.button target-action
- [ ] T052 [US2] Update PreviewPanelViewModel.$previewContent binding to refresh PreviewPanelView in PreviewPanelContainer (NSHostingController rootView update)

**Checkpoint**: User Stories 1 AND 2 complete - Can display list and copy/paste entries. Core MVP functionality ready.

---

## Phase 5: User Story 3 - Search Clipboard History (Priority: P2)

**Goal**: Filter clipboard list by search text with debouncing

**Independent Test**: Type search text → list filters to show only matching entries

### Tests for User Story 3

- [ ] T053 [P] [US3] Write unit test in tests/macos/ViewModels/SearchBarViewModelTests.swift (testSearchText_DebouncesFor300ms)
- [ ] T054 [P] [US3] Write unit test in tests/macos/Services/SearchServiceTests.swift (testSearch_FiltersEntriesByQuery)
- [ ] T055 [P] [US3] Write unit test in tests/macos/ViewModels/MainPanelViewModelTests.swift (testSearchText_UpdatesFilteredEntries)

### Implementation for User Story 3

#### ViewModels

- [ ] T056 [US3] Create SearchBarViewModel in src/macos/ViewModels/SearchBarViewModel.swift (@Published var searchText, isSearching - private var searchCancellable, setupDebouncing with Combine $searchText.debounce(for: .milliseconds(300)))
- [ ] T057 [US3] Add search handling to MainPanelViewModel.updateFilters in src/macos/ViewModels/MainPanelViewModel.swift (call searchService.applyFilters when searchText changes)

#### SwiftUI Views

- [ ] T058 [P] [US3] Create SearchBarView in src/macos/SwiftUIViews/SearchBarView.swift (TextField with "Search clipboard..." placeholder, $viewModel.searchText binding, .textFieldStyle(.roundedBorder))

#### Service Implementation

- [ ] T059 [US3] Implement SearchService.search in src/macos/Services/SearchService.swift (filter entries where title.localizedCaseInsensitiveContains(query) or text content contains query, return filtered array)
- [ ] T060 [US3] Implement SearchService.applyFilters in src/macos/Services/SearchService.swift (combine search + contentFilter + pinnedFilter, sort with pinned first, return filtered array)

#### Integration

- [ ] T061 [US3] Embed SearchBarView into ClipboardPanelWindow via NSHostingController in src/macos/AppKitViews/ClipboardPanelWindow.swift (add searchBarHost, setupSnapKitLayout for top bar)
- [ ] T062 [US3] Wire SearchBarViewModel.$searchText to MainPanelViewModel in ClipboardPanelCoordinator (subscribe to searchText, trigger updateFilters)
- [ ] T063 [US3] Show "no results found" message when filteredEntries.isEmpty in ClipboardTableView (display overlay label)

**Checkpoint**: User Story 3 complete - Search functional and debounced.

---

## Phase 6: User Story 5 - Pin Important Entries (Priority: P2)

**Goal**: Pin entries to keep them at top of list

**Independent Test**: Pin entry → entry moves to top with pushpin icon → stays at top when new content copied

### Tests for User Story 5

- [ ] T064 [P] [US5] Write unit test in tests/macos/Services/ClipboardServiceTests.swift (testSetPinned_UpdatesDatabase)
- [ ] T065 [P] [US5] Write unit test in tests/macos/ViewModels/MainPanelViewModelTests.swift (testPinnedEntries_AppearAtTopOfList)
- [ ] T066 [P] [US5] Write integration test in tests/macos/Integration/ClipboardPanelIntegrationTests.swift (testPinEntry_MovesEntryToTop)

### Implementation for User Story 5

#### ViewModels

- [ ] T067 [US5] Add togglePin action to MainPanelViewModel.handleUserAction in src/macos/ViewModels/MainPanelViewModel.swift (call clipboardService.setPinned(id: !entry.isPinned))
- [ ] T068 [US5] Update MainPanelViewModel.updateFilters to sort pinned entries first in src/macos/ViewModels/MainPanelViewModel.swift (pinned entries before unpinned, within each group sort by timestamp DESC)

#### SwiftUI Views

- [ ] T069 [P] [US5] Update ClipboardTableCellView to show pinned icon in src/macos/AppKitViews/ClipboardTableCellView.swift (add pinnedIcon: NSImageView, show when entry.isPinned == true, SnapKit layout constraints)

#### Service Implementation

- [ ] T070 [US5] Implement ClipboardService.setPinned in src/macos/Services/ClipboardService.swift (UPDATE clipboard_entries SET is_pinned = ?, pinned_timestamp = ? WHERE id = ?, return Void publisher)
- [ ] T071 [US5] Add pinned filtering to SearchService.applyFilters in src/macos/Services/SearchService.swift (isPinned == true when pinnedFilterEnabled, sort logic)

#### Integration

- [ ] T072 [US5] Add pin/unpin context menu to ClipboardTableCellView in src/macos/AppKitViews/ClipboardTableView.swift (right-click menu with "Pin" / "Unpin" item, calls viewModel.handleUserAction(.togglePin))
- [ ] T073 [US5] Update ClipboardListViewModel to handle pin action in src/macos/ViewModels/ClipboardListViewModel.swift (onTogglePin entry, reload row after update)

**Checkpoint**: User Story 5 complete - Pin/unpin functional with visual indicator.

---

## Phase 7: User Story 6 - Keyboard Navigation (Priority: P2)

**Goal**: Navigate and select entries using keyboard only

**Independent Test**: Use arrow keys → Navigate list, Enter → Copy, Escape → Close panel

### Tests for User Story 6

- [ ] T074 [P] [US6] Write unit test in tests/macos/AppKitViews/ClipboardTableViewTests.swift (testKeyDownEvent_ArrowKeys_MoveSelection)
- [ ] T075 [P] [US6] Write integration test in tests/macos/Integration/ClipboardPanelIntegrationTests.swift (testKeyboardNavigation_SelectAndCopy)

### Implementation for User Story 6

#### AppKit Views

- [ ] T076 [US6] Add keyboard event handling to ClipboardTableView in src/macos/AppKitViews/ClipboardTableView.swift (override keyDown, handle arrow keys for selection, Enter for copy, Escape to close panel)
- [ ] T077 [US6] Implement Tab focus management in ClipboardPanelWindow in src/macos/AppKitViews/ClipboardPanelWindow.swift (Tab cycles: search → filter → tableView, makeTableViewFirstResponder)

#### Global Shortcut

- [ ] T078 [US6] Register global keyboard shortcut ⌘+Shift+V using KeyboardShortcuts in src/macos/Coordinators/ClipboardPanelCoordinator.swift (KeyboardShortcuts.Shortcut.togglePanel, addObserver to call showPanel/hidePanel)
- [ ] T079 [US6] Create KeyboardShortcuts.Shortcut extension in src/macos/Utils/KeyboardShortcuts+Extensions.swift (static let togglePanel = Shortcut("togglePanel"), defaultValue = Shortcut(.v, modifiers: [.command, .shift]))

#### Integration

- [ ] T080 [US6] Wire up NSTableView selection updates with keyboard in src/macos/AppKitViews/ClipboardTableView.swift (keyDown → update selectedRow → notify viewModel)
- [ ] T081 [US6] Connect Enter key to copy action in src/macos/AppKitViews/ClipboardTableView.swift (keyDown .carriageReturn → viewModel.handleUserAction(.copySelected))

**Checkpoint**: User Story 6 complete - Full keyboard navigation functional.

---

## Phase 8: User Story 4 - Delete Clipboard Entries (Priority: P3)

**Goal**: Remove entries from history and database

**Independent Test**: Delete entry → removed from list → doesn't reappear on reopen

### Tests for User Story 4

- [ ] T082 [P] [US4] Write unit test in tests/macos/Services/ClipboardServiceTests.swift (testDeleteEntry_RemovesFromDatabase)
- [ ] T083 [P] [US4] Write unit test in tests/macos/ViewModels/MainPanelViewModelTests.swift (testDeleteEntry_UpdatesEntriesArray)
- [ ] T084 [P] [US4] Write integration test in tests/macos/Integration/ClipboardPanelIntegrationTests.swift (testDeleteEntry_EntryRemovedFromUI)

### Implementation for User Story 4

#### ViewModels

- [ ] T085 [US4] Add delete action to MainPanelViewModel.handleUserAction in src/macos/ViewModels/MainPanelViewModel.swift (handle .deleteEntry(id) and .deleteEntries(ids), call clipboardService, remove from allEntries)
- [ ] T086 [US4] Add confirmation dialog in MainPanelViewModel.handleUserAction in src/macos/ViewModels/MainPanelViewModel.swift (show NSAlert before deletion, only proceed if OK clicked)

#### Service Implementation

- [ ] T087 [US4] Implement ClipboardService.deleteEntry in src/macos/Services/ClipboardService.swift (DELETE FROM clipboard_entries WHERE id = ?, return Void publisher)
- [ ] T088 [US4] Implement ClipboardService.deleteEntries in src/macos/Services/ClipboardService.swift (DELETE FROM clipboard_entries WHERE id IN (...), return Void publisher)

#### Integration

- [ ] T089 [US4] Add delete button to context menu in src/macos/AppKitViews/ClipboardTableView.swift (right-click menu with "Delete" item, shows confirmation alert)
- [ ] T090 [US4] Add multi-select support to ClipboardTableView in src/macos/AppKitViews/ClipboardTableView.swift (allowsMultipleSelection, Cmd+click for multi-select, Shift+click for range)
- [ ] T091 [US4] Update selection handling after delete in src/macos/ViewModels/ClipboardListViewModel.swift (move selection to next entry after deletion, clear if no entries remain)
- [ ] T092 [US4] Show empty state when all entries deleted in ClipboardTableView (display EmptyStateView with "No clipboard entries")

**Checkpoint**: User Story 4 complete - Delete with confirmation functional. All 6 user stories complete.

---

## Phase 9: Polish & Cross-Cutting Concerns

**Purpose**: Improvements that affect multiple user stories

- [ ] T093 [P] Add content type filter buttons (All/Text/Images) to ClipboardPanelWindow in src/macos/AppKitViews/ClipboardPanelWindow.swift (NSButton stack, bind to MainPanelViewModel.$contentFilter, SnapKit layout)
- [ ] T094 [P] Add pinned filter toggle switch in src/macos/AppKitViews/ClipboardPanelWindow.swift (NSSwitch, bind to MainPanelViewModel.$isPinnedFilterActive)
- [ ] T095 [P] Create FilterButtonsView in src/macos/SwiftUIViews/FilterButtonsView.swift (segmented control or button group, observes FilterViewModel)
- [ ] T096 [P] Create FilterViewModel in src/macos/ViewModels/FilterViewModel.swift (@Published var activeFilter, pinnedFilterEnabled - toggleFilter, resetFilters)
- [ ] T097 [P] Implement sensitive content detection in src/macos/Services/SensitiveContentDetector.swift (regex patterns for passwords, API keys, tokens - detect method returning sensitiveType or nil)
- [ ] T098 [P] Add warning icon for sensitive entries in ClipboardTableCellView in src/macos/AppKitViews/ClipboardTableCellView.swift (show when entry.isSensitive == true, tooltip "Sensitive content detected")
- [ ] T099 [P] Implement encryption offer dialog in PreviewPanelView in src/macos/SwiftUIViews/PreviewPanel/PreviewPanelView.swift (when sensitive entry selected, show "Encrypt this entry?" button)
- [ ] T100 [P] Implement FIFO eviction for 10,000 entry limit in src/macos/Services/ClipboardService.swift (after insert, if count > 10000, DELETE oldest unpinned entries ORDER BY timestamp ASC LIMIT excess)
- [ ] T101 [P] Add error handling to all ViewModels in src/macos/ViewModels/*.swift (@Published var errorMessage: String?, display in UI, Combine .sink case .failure)
- [ ] T102 [P] Add loading states to all async operations in ViewModels in src/macos/ViewModels/*.swift (@Published var isLoading, show ProgressView in SwiftUI, overlay in AppKit)
- [ ] T103 [P] Implement database lock retry logic in ClipboardService in src/macos/Services/ClipboardService.swift (3 retries with 100ms backoff using Combine delay)
- [ ] T104 [P] Add structured logging to all Services in src/macos/Services/*.swift (Logger.shared.debug("Loading entries"), Logger.shared.error("Failed to copy: \(error)"))
- [ ] T105 [P] Add window size/position persistence to ClipboardPanelWindow in src/macos/AppKitViews/ClipboardPanelWindow.swift (save frame to UserDefaults on close, restore on open)
- [ ] T106 [P] Add scroll position persistence to ClipboardTableView in src/macos/ViewModels/ClipboardListViewModel.swift (save scrollPosition to UserDefaults on close, restore on open)
- [ ] T107 [P] Run performance tests per quickstart.md (test with 1000 entries, verify 60 FPS scrolling, <300ms search, <500ms panel render)
- [ ] T108 [P] Manual testing checklist per quickstart.md (test all 6 user stories, verify keyboard shortcuts, test edge cases from spec.md)
- [ ] T109 [P] Code cleanup: Remove unused imports, consolidate duplicate code, ensure MVVM separation (no SwiftUI imports in ViewModels, no Service calls in Views)

**Checkpoint**: All user stories complete with polish, optimizations, and error handling.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Stories (Phase 3-8)**: All depend on Foundational phase completion
  - US1 and US2 are co-dependent (display before select) → implement sequentially
  - US3, US5, US6 can proceed in parallel after US2 (if team capacity allows)
  - US4 (delete) is P3 - implement after higher priority stories
- **Polish (Phase 9)**: Depends on all desired user stories being complete

### User Story Dependencies

- **User Story 1 (P1)**: Must start after Foundational (Phase 2) - Blocks US2
- **User Story 2 (P1)**: Must start after US1 complete (requires list from US1)
- **User Story 3 (P2)**: Can start after US2 (integrates with existing list)
- **User Story 5 (P2)**: Can start after US2 (modifies existing list behavior)
- **User Story 6 (P2)**: Can start after US2 (adds navigation to existing list)
- **User Story 4 (P3)**: Can start after US2 (removes from existing list)

### Critical Path (Sequential)

1. Phase 1: Setup (T001-T005)
2. Phase 2: Foundational (T006-T016)
3. Phase 3: US1 Display List (T017-T036)
4. Phase 4: US2 Select & Copy (T037-T052)
5. Phase 5: US3 Search (T053-T063) OR Phase 6: US5 Pin (T064-T073) OR Phase 7: US6 Keyboard (T074-T081) - **Can parallelize after US2**
6. Phase 8: US4 Delete (T082-T092)
7. Phase 9: Polish (T093-T109)

### Parallel Opportunities

Within each phase, tasks marked [P] can run in parallel:

**Setup (Phase 1)**:
```bash
Task T003, T004, T005  # Different directories
```

**Foundational (Phase 2)**:
```bash
Task T006-T011  # All models in parallel
Task T015, T016  # Independent services/extensions
```

**User Story 1**:
```bash
Task T017-T020  # All tests in parallel
Task T027-T028  # SwiftUI components in parallel
```

**User Story 2**:
```bash
Task T037-T039  # Tests in parallel
Task T044-T046  # SwiftUI views in parallel
```

**User Stories 3, 5, 6** (after US2 complete):
```bash
# Can run entire phases in parallel with 3 developers:
Developer A: Phase 5 (US3 Search) T053-T063
Developer B: Phase 6 (US5 Pin) T064-T073
Developer C: Phase 7 (US6 Keyboard) T074-T081
```

**Polish (Phase 9)**:
```bash
Task T093-T109  # Most polish tasks independent
```

---

## Parallel Example: User Story 1

```bash
# Launch all tests for User Story 1 together:
Task T017: "Write unit test in tests/macos/ViewModels/MainPanelViewModelTests.swift"
Task T018: "Write unit test in tests/macos/ViewModels/MainPanelViewModelTests.swift"
Task T019: "Write unit test in tests/macos/Services/ClipboardServiceTests.swift"
Task T020: "Write integration test in tests/macos/Integration/ClipboardPanelIntegrationTests.swift"

# After tests written and failing, launch models in parallel:
Task T027: "Create PinnedIndicatorView in src/macos/SwiftUIViews/Components/"
Task T028: "Create TypeIndicatorView in src/macos/SwiftUIViews/Components/"
```

---

## Implementation Strategy

### MVP First (User Stories 1 + 2 Only)

1. Complete Phase 1: Setup (T001-T005)
2. Complete Phase 2: Foundational (T006-T016) - **CRITICAL**
3. Complete Phase 3: User Story 1 (T017-T036)
4. Complete Phase 4: User Story 2 (T037-T052)
5. **STOP and VALIDATE**: Test MVP independently - Can display list and copy/paste entries
6. Deploy/demo MVP if ready

**MVP Deliverable**: Functional clipboard history viewer with copy/paste - Core value delivered!

### Incremental Delivery

1. **Sprint 1**: Setup + Foundational → Infrastructure ready (0 value, 2-3 days)
2. **Sprint 2**: User Story 1 → Display list (50% value, 3-5 days) ✅ **MVP checkpoint**
3. **Sprint 3**: User Story 2 → Select & copy (80% value, 2-3 days) ✅ **MVP complete!**
4. **Sprint 4**: User Story 3 → Search (90% value, 2-3 days)
5. **Sprint 5**: User Story 5 → Pin entries (95% value, 2-3 days)
6. **Sprint 6**: User Story 6 → Keyboard nav (98% value, 1-2 days)
7. **Sprint 7**: User Story 4 → Delete (100% value, 1-2 days)
8. **Sprint 8**: Polish → Production ready (2-3 days)

Each sprint adds user value without breaking previous stories.

### Parallel Team Strategy

With 2-3 developers:

**Week 1-2**: All developers on Setup + Foundational (critical path)

**Week 3+**: Once US1+US2 complete:
- **Developer A**: User Story 3 (Search)
- **Developer B**: User Story 5 (Pin)
- **Developer C**: User Story 6 (Keyboard Nav)

Stories integrate into shared codebase without conflicts (different ViewModels, different Views, same Services).

---

## Notes

- **[P] tasks**: Different files, no blocking dependencies - can run in parallel
- **[Story] label**: Maps task to user story for traceability and independent validation
- **TDD enforced**: Tests written first (T017-T020, etc.), verified to fail, then implementation
- **MVVM enforced**: ViewModels UI-agnostic (no SwiftUI/AppKit imports), Views observe ViewModels, Services stateless
- **Hybrid UI**: AppKit for performance-critical (NSTableView, NSPanel), SwiftUI for simple (SearchBar, FilterButtons, PreviewPanel)
- **Commit frequently**: After each task or logical group (e.g., all tests for a story)
- **Stop at checkpoints**: Validate each user story independently before proceeding
- **No additional dependencies**: Only SnapKit, KeyboardShortcuts, SQLite.swift - all via SPM
- **Performance targets**: 60 FPS with 1000+ entries, <300ms search, <500ms panel render
