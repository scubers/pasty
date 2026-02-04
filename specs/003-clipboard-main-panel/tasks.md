# Tasks: Clipboard Main Panel UI

**Feature**: 003-clipboard-main-panel
**Branch**: `003-clipboard-main-panel`
**Input**: Design documents from `/specs/003-clipboard-main-panel/`

**Tests**: ⏸️ Deferred to Phase 9 (Tests will be added after core implementation is complete)

**Implementation Status**: 🟢 **Core Features Complete** (Phases 1-8)

## Summary

**Completed Phases:**
- ✅ Phase 1: Setup (T001-T005)
- ✅ Phase 2: Foundational (T006-T016) - Note: T014 (EncryptionService) and T015 (ThumbnailCache) deferred
- ✅ Phase 3: User Story 1 - Display Clipboard History List (T021-T037, tests T017-T020 deferred)
- ✅ Phase 4: User Story 2 - Select and Copy (T040-T052, tests T037-T039 deferred)
- ✅ Phase 5: User Story 3 - Search (T057-T063, tests T053-T055 deferred, T056 modified)
- ✅ Phase 6: User Story 5 - Pin Important Entries (T067-T073, tests T064-T066 deferred)
- ✅ Phase 7: User Story 6 - Keyboard Navigation (T076-T081, tests T074-T075 deferred)
- ✅ Phase 8: User Story 4 - Delete Clipboard Entries (T085-T092, tests T082-T084 deferred)

**Phase 9 (Polish) Progress:**
- ✅ Filter buttons (T093-T095)
- ✅ Error handling & loading states (T101-T102)
- ✅ Structured logging (T104)
- ✅ Window persistence (T105)
- ✅ Accessibility permissions (T110)
- ⏸️ Remaining: T097-T100, T103, T106-T109

**Known Limitations:**
- Using mock data (MockClipboardHistory) - Rust FFI integration pending
- In-memory state management only (no database persistence yet)
- Tests not yet implemented (deferred to Phase 9)
- No encryption/decryption functionality yet
- No thumbnail caching yet

---

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story (US1-US6)
- **Paths**: Based on plan.md structure: `src/macos/`, `tests/`

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization and SPM dependencies setup

- [x] T001 Create src/macos directory structure per plan.md (Models, ViewModels, AppKitViews, SwiftUIViews, Services, Coordinators, Utils)
- [x] T002 Add SPM dependencies via xcodegen project.yml: SnapKit 5.7+, KeyboardShortcuts 1.0+, SQLite.swift 0.14+ (packages section with dependencies)
- [x] T003 [P] Create tests/macos directory structure (ViewModels, Services, AppKitViews, Integration)
- [x] T004 [P] Create Logging utility in src/macos/Utils/Logging/Logger.swift with structured JSON output (error, warn, info, debug levels)
- [x] T005 [P] Create String+Extensions, Date+Formatter, NSImage+Thumbnail extensions in src/macos/Utils/Extensions/

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure that MUST be complete before ANY user story can be implemented

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

### Data Models (UI-Agnostic)

- [x] T006 [P] Create ClipboardEntry model in src/macos/Models/ClipboardEntry.swift (id, content, contentType, timestamp, sourceApp, isPinned, isEncrypted, sensitiveType) - *Already exists from previous features*
- [x] T007 [P] Create ContentType enum in src/macos/Models/ContentType.swift (text, image) - *Already exists from previous features*
- [x] T008 [P] Create ClipboardEntryListItem model in src/macos/Models/ClipboardEntryListItem.swift (title, preview, timestamp, sourceApp, sourceIcon, contentType, isPinned, isSelected, isSensitive)
- [x] T009 [P] Create ContentFilter enum in src/macos/Models/ContentFilter.swift (all, text, images)
- [x] T010 [P] Create PreviewContent enum in src/macos/Models/PreviewContent.swift (text, image, empty)
- [x] T011 [P] Create UserAction enum in src/macos/Models/UserAction.swift (loadEntries, selectEntry, copyEntry, pasteEntry, deleteEntry, pinEntry, search, filter)

### Service Layer (Stateless, Combine Publishers)

- [x] T012 Implement ClipboardService protocol - *Uses existing ClipboardHistory from previous features*
- [x] T013 Implement SearchService in src/macos/Services/SearchService.swift (search, filterByContentType, filterByPinned, applyFilters - pure functions)
- [ ] T014 Implement EncryptionService in src/macos/Services/EncryptionService.swift (encrypt, decrypt, generateKey, deleteKey - async/await, Keychain integration) - *Deferred to Phase 9*
- [ ] T015 Implement ThumbnailCache in src/macos/Services/ThumbnailCache.swift (get, set, clear - in-memory LRU cache, max 100 entries) - *Deferred to Phase 9*
- [x] T016 Create Date+Formatter extension in src/macos/Utils/Extensions/Date+Formatter.swift (formatAsTimeAgo, formatAsDateTime)

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

### Tests Status: ⏸️ Deferred (Tests will be added in Phase 9)

### Implementation for User Story 1

#### ViewModels

- [x] T021 [US1] Create MainPanelViewModel in src/macos/ViewModels/MainPanelViewModel.swift (@Published var allEntries, filteredEntries, searchText, contentFilter, selectedEntryId, isLoading - handleUserAction, setupBindings, loadEntries, updateFilters)
- [x] T022 [US1] Create ClipboardListViewModel in src/macos/ViewModels/ClipboardListViewModel.swift (@Published var entries, isLoading, selectedRow - onSelectEntry, loadEntries, bindToMainPanelViewModel)

#### AppKit Views (Performance-Critical)

- [x] T023 [US1] Create ClipboardPanelWindow (NSPanel) in src/macos/AppKitViews/ClipboardPanelWindow.swift (init with contentRect and styleMask .borderless, showPanel, hidePanel, setupTableView, setupLayout using SnapKit, floating panel behavior)
- [x] T024 [US1] NSTableView embedded in ClipboardPanelWindow with dataSource, delegate, and Combine binding
- [x] T025 [US1] Create ClipboardTableCellView in src/macos/AppKitViews/ClipboardTableCellView.swift (titleLabel: NSTextField, sourceIcon: NSImageView, timestampLabel: NSTextField, typeIndicator: NSView, pinnedIndicator: NSView - configure with entry using SnapKit layout)
- [x] T026 [US1] Empty state view embedded in ClipboardPanelWindow (NSView with message label and icon, centered layout using SnapKit)

#### SwiftUI Views (Simple Components - Optional for US1)

- [x] T027 [P] [US1] PinnedIndicatorView embedded in ClipboardTableCellView (AppKit custom view with red pushpin icon)
- [x] T028 [P] [US1] TypeIndicatorView embedded in ClipboardTableCellView (AppKit custom view with colored circle: blue for text, green for image)
- [x] T027-B [P] [US1] Create SearchBarView in src/macos/SwiftUIViews/SearchBarView.swift (search input with clear button)
- [x] T028-B [P] [US1] Create FilterButtonsView in src/macos/SwiftUIViews/FilterButtonsView.swift (filter buttons and pinned toggle)

#### Coordinator

- [x] T029 [US1] Create ClipboardPanelCoordinator in src/macos/Coordinators/ClipboardPanelCoordinator.swift (init with ClipboardPanelWindow and MainPanelViewModel, showPanel, hidePanel, setupBindings between window and ViewModel)

#### Integration

- [x] T030 [US1] Wire up ClipboardHistory.retrieveAllEntries to MainPanelViewModel in MainPanelViewModel.loadEntries (load from existing FFI, map to ClipboardEntryListItem, update @Published allEntries, handle errors)
- [x] T031 [US1] Bind MainPanelViewModel.$filteredEntries to NSTableView.reloadData using Combine in ClipboardPanelWindow
- [x] T032 [US1] Implement NSTableViewDataSource numberOfRows and viewFor tableColumn in ClipboardPanelWindow (return viewModel.filteredEntries.count, create/dequeue ClipboardTableCellView, configure with entry data)
- [x] T033 [US1] Implement NSTableViewDelegate selection handling in ClipboardPanelWindow (shouldSelectRow, update selectedEntryId in ViewModel)
- [x] T034 [US1] Add SnapKit Auto Layout constraints in ClipboardTableCellView.setupLayout (title.leadingAnchor, sourceIcon.trailingAnchor, timestamp.topAnchor, etc.)
- [x] T035 [US1] Add SnapKit Auto Layout constraints for main panel layout in ClipboardPanelWindow.setupLayout (searchBar, filterButtons, tableView edges, emptyState overlay)
- [x] T036 [US1] Show empty state when viewModel.filteredEntries.isEmpty in ClipboardPanelWindow (hide tableView, show EmptyStateView)
- [x] T037 [US1] Implement global keyboard shortcut using KeyboardShortcuts library in ClipboardPanelCoordinator (register togglePanel shortcut with ⌘+Shift+V)

**Checkpoint**: User Story 1 complete - Main panel opens and displays clipboard list. Can be tested and validated independently.

---

## Phase 4: User Story 2 - Select and Copy Clipboard Entry (Priority: P1)

**Goal**: Select entries and copy content to system clipboard

**Independent Test**: Click entry → copy to clipboard → paste in another app → content matches original

### Tests for User Story 2

- [ ] T037 [P] [US2] Write unit test in tests/macos/ViewModels/PreviewPanelViewModelTests.swift (testHandleCopyAction_CallsClipboardService)
- [ ] T038 [P] [US2] Write unit test in tests/macos/Services/ClipboardServiceTests.swift (testCopyToClipboard_WithValidId_SetsClipboardContent)
- [ ] T039 [P] [US2] Write integration test in tests/macos/Integration/ClipboardPanelIntegrationTests.swift (testSelectEntry_CopiesToClipboard)

### Tests Status: ⏸️ Deferred (Tests will be added in Phase 9)

### Implementation for User Story 2

#### ViewModels

- [x] T040 [US2] Create PreviewPanelViewModel in src/macos/ViewModels/PreviewPanelViewModel.swift (@Published var previewContent, copyButtonEnabled, pasteButtonEnabled - handleCopyAction, handlePasteAction, loadPreviewContent)
- [x] T041 [US2] Selection handling integrated into MainPanelViewModel (selectedEntryId triggers preview load via Combine binding)

#### AppKit Views

- [x] T042 [US2] Preview panel integrated into ClipboardPanelWindow with two-panel layout (70% list, 30% preview with divider)
- [x] T043 [US2] Copy and Paste buttons implemented in SwiftUI PreviewPanelView with proper binding to ViewModel

#### SwiftUI Views

- [x] T044 [P] [US2] Create PreviewPanelView in src/macos/SwiftUIViews/PreviewPanel/PreviewPanelView.swift (observes PreviewPanelViewModel, TextPreviewView, ImagePreviewView, Copy button, Paste button)
- [x] T045 [P] [US2] Create TextPreviewView in src/macos/SwiftUIViews/PreviewPanel/TextPreviewView.swift (ScrollView with Text, monospaced font)
- [x] T046 [P] [US2] Create ImagePreviewView in src/macos/SwiftUIViews/PreviewPanel/ImagePreviewView.swift (Image.resizable, scaledToFit with scroll)

#### Service Implementation

- [x] T047 [US2] Implement copyToClipboard in PreviewPanelViewModel (uses NSPasteboard.general for text and images)
- [x] T048 [US2] Implement copyAndPaste in PreviewPanelViewModel (copyToClipboard + simulate Cmd+V using CGEvent)

#### Integration

- [x] T049 [US2] Wire up NSTableView selection to PreviewPanelViewModel.loadPreviewContent (Combine binding: $selectedEntryId.sink → loadPreviewContent)
- [x] T050 [US2] Connect Copy button to PreviewPanelViewModel.handleCopyAction (SwiftUI Button action)
- [x] T051 [US2] Connect Paste button to PreviewPanelViewModel.handlePasteAction (SwiftUI Button action)
- [x] T052 [US2] PreviewPanelViewModel.$previewContent binding updates PreviewPanelView automatically via @ObservedObject

**Checkpoint**: User Stories 1 AND 2 complete - Can display list, preview content, and copy/paste entries. Core MVP functionality ready!

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

- [x] T056 [US3] Search functionality integrated directly into MainPanelViewModel (no separate SearchBarViewModel needed - @Published var searchText with debounce in setupBindings)
- [x] T057 [US3] Add search handling to MainPanelViewModel.updateFilters in src/macos/ViewModels/MainPanelViewModel.swift (call searchService.applyFilters when searchText changes)

#### SwiftUI Views

- [x] T058 [P] [US3] Create SearchBarView in src/macos/SwiftUIViews/SearchBarView.swift (TextField with "Search clipboard..." placeholder, $viewModel.searchText binding, .textFieldStyle(.roundedBorder))

#### Service Implementation

- [x] T059 [US3] Implement SearchService.search in src/macos/Services/SearchService.swift (filter entries where title.localizedCaseInsensitiveContains(query) or text content contains query, return filtered array)
- [x] T060 [US3] Implement SearchService.applyFilters in src/macos/Services/SearchService.swift (combine search + contentFilter + pinnedFilter, sort with pinned first, return filtered array)

#### Integration

- [x] T061 [US3] Embed SearchBarView into ClipboardPanelWindow via NSHostingController in src/macos/AppKitViews/ClipboardPanelWindow.swift (add searchBarHost, setupSnapKitLayout for top bar)
- [x] T062 [US3] Wire MainPanelViewModel.$searchText to trigger updateFilters via Combine binding in setupBindings (debounce for 100ms)
- [x] T063 [US3] Show "no results found" message when filteredEntries.isEmpty in ClipboardPanelWindow (display overlay label with dynamic icon)

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

- [x] T067 [US5] Add togglePin action to MainPanelViewModel.handle in src/macos/ViewModels/MainPanelViewModel.swift (toggle isPinned state in memory, update pinnedTimestamp)
- [x] T068 [US5] Update SearchService.sortEntries to sort pinned entries first (pinned entries before unpinned, sorted by pinnedTimestamp DESC, then by sortTimestamp DESC)

#### SwiftUI Views

- [x] T069 [P] [US5] PinnedIndicatorView in ClipboardTableCellView shows red pushpin icon (AppKit custom view with NSBezierPath drawing, shown when entry.isPinned == true)

#### Service Implementation

- [x] T070 [US5] Pin state managed in-memory (Database UPDATE deferred - ClipboardEntryListItem updated with new isPinned state)
- [x] T071 [US5] Add pinned filtering to SearchService.applyFilters in src/macos/Services/SearchService.swift (isPinned == true when pinnedFilterEnabled, sort with pinned entries first)

#### Integration

- [x] T072 [US5] Add pin/unpin context menu to ClipboardTableCellView in src/macos/AppKitViews/ClipboardTableCellView.swift (right-click menu with "Pin Entry" / "Unpin Entry" item, calls viewModel.handle(.togglePin))
- [x] T073 [US5] Update filteredEntries after pin toggle via updateFilters in MainPanelViewModel (reapply filters to update display order)

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

- [x] T076 [US6] Created KeyboardHandlingTableView in src/macos/AppKitViews/KeyboardHandlingTableView.swift (override keyDown, handle arrow keys for selection, Enter for copy+paste, Escape to close, Delete for deletion)
- [x] T077 [US6] First responder management in ClipboardPanelWindow (makeTableViewFirstResponder in showPanel, acceptsFirstResponder override)

#### Global Shortcut

- [x] T078 [US6] Register global keyboard shortcut ⌘+Shift+V using KeyboardShortcuts in src/macos/Coordinators/ClipboardPanelCoordinator.swift (KeyboardShortcuts.Name.togglePanel with onKeyUp observer, calls togglePanel)
- [x] T079 [US6] Create KeyboardShortcuts.Name extension in ClipboardPanelCoordinator.swift (static let togglePanel = Name("togglePanel", default: .init(.v, modifiers: [.command, .shift])))

#### Integration

- [x] T080 [US6] Wire up NSTableView selection updates with keyboard via KeyboardTableViewDelegate (tableViewDidChangeSelection updates selectedEntryId in viewModel)
- [x] T081 [US6] Connect Enter key to copy+paste action in ClipboardPanelWindow (tableViewDidPressEnter calls handle(.pasteEntry), then hidePanel)

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

- [x] T085 [US4] Add delete action to MainPanelViewModel.handle in src/macos/ViewModels/MainPanelViewModel.swift (handle .deleteEntry(id) and .deleteEntries(ids), remove from allEntries in-memory)
- [x] T086 [US4] Add confirmation dialog in MainPanelViewModel (show NSAlert before deletion with entry title/count, only proceed if "Delete" button clicked)

#### Service Implementation

- [x] T087 [US4] Entry deletion managed in-memory (Database DELETE deferred - allEntries.removeAll where id matches)
- [x] T088 [US4] Multiple entry deletion supported (allEntries.removeAll where ids contains id)

#### Integration

- [x] T089 [US4] Add delete button to context menu in ClipboardTableCellView (right-click menu with "Delete" item, shows confirmation alert via viewModel.handle)
- [x] T090 [US4] Multi-select support enabled in NSTableView (allowsMultipleSelection = true, supports Cmd+click and Shift+click)
- [x] T091 [US4] Deletion via keyboard in KeyboardHandlingTableView (Delete/Forward Delete key triggers tableViewDidPressDelete)
- [x] T092 [US4] Empty state shown when filteredEntries.isEmpty (updateEmptyStateVisibility checks allEntries vs filteredEntries for "No entries" vs "No results")

**Checkpoint**: User Story 4 complete - Delete with confirmation functional. All 6 user stories complete.

---

## Phase 9: Polish & Cross-Cutting Concerns

**Purpose**: Improvements that affect multiple user stories

- [x] T093 [P] Add content type filter buttons (All/Text/Images) via FilterButtonsView SwiftUI component embedded in ClipboardPanelWindow
- [x] T094 [P] Add pinned filter toggle button in FilterButtonsView (binds to MainPanelViewModel.$isPinnedFilterActive)
- [x] T095 [P] FilterButtonsView created in src/macos/SwiftUIViews/FilterButtonsView.swift (button group with ContentFilter cases, observes MainPanelViewModel)
- [ ] T096 [P] Create FilterViewModel in src/macos/ViewModels/FilterViewModel.swift (@Published var activeFilter, pinnedFilterEnabled - toggleFilter, resetFilters) - *Deferred: Filter integrated into MainPanelViewModel*
- [ ] T097 [P] Implement sensitive content detection in src/macos/Services/SensitiveContentDetector.swift (regex patterns for passwords, API keys, tokens - detect method returning sensitiveType or nil)
- [ ] T098 [P] Add warning icon for sensitive entries in ClipboardTableCellView (sensitiveIndicatorView added, shown when entry.isSensitive == true)
- [ ] T099 [P] Implement encryption offer dialog in PreviewPanelView in src/macos/SwiftUIViews/PreviewPanel/PreviewPanelView.swift (when sensitive entry selected, show "Encrypt this entry?" button)
- [ ] T100 [P] Implement FIFO eviction for 10,000 entry limit in src/macos/Services/ClipboardService.swift (after insert, if count > 10000, DELETE oldest unpinned entries ORDER BY timestamp ASC LIMIT excess)
- [x] T101 [P] Add error handling to MainPanelViewModel (@Published var errorMessage: String?, logs errors via Logger)
- [x] T102 [P] Add loading states to MainPanelViewModel (@Published var isLoading, used in updateEmptyStateVisibility)
- [ ] T103 [P] Implement database lock retry logic in ClipboardService in src/macos/Services/ClipboardService.swift (3 retries with 100ms backoff using Combine delay)
- [x] T104 [P] Add structured logging via Logger utility (Logger.info, Logger.debug, Logger.warning, Logger.error used throughout ViewModels and Coordinators)
- [x] T105 [P] Add window size/position persistence to ClipboardPanelWindow (save/restore frame to UserDefaults, save on hide, restore on show)
- [ ] T106 [P] Add scroll position persistence to ClipboardTableView in src/macos/ViewModels/ClipboardListViewModel.swift (save scrollPosition to UserDefaults on close, restore on open)
- [ ] T107 [P] Run performance tests per quickstart.md (test with 1000 entries, verify 60 FPS scrolling, <300ms search, <500ms panel render)
- [ ] T108 [P] Manual testing checklist per quickstart.md (test all 6 user stories, verify keyboard shortcuts, test edge cases from spec.md)
- [ ] T109 [P] Code cleanup: Remove unused imports, consolidate duplicate code, ensure MVVM separation (no SwiftUI imports in ViewModels, no Service calls in Views)
- [x] T110 [P] Add accessibility permission checking to ClipboardPanelCoordinator (hasAccessibilityPermissions check, showAccessibilityPermissionAlert with System Settings link)

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
