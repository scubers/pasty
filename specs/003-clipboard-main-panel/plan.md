# Implementation Plan: Clipboard Main Panel UI

**Branch**: `003-clipboard-main-panel` | **Date**: 2026-02-04 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/003-clipboard-main-panel/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/commands/plan.md` for the execution workflow.

## Summary

Build a macOS main panel UI for clipboard history management with two-panel layout (list + preview), supporting display, selection, copy/paste, search, filter, delete, pin, and keyboard navigation. The UI will be implemented in Swift 5.9+ using SwiftUI/AppKit, integrating directly with the Rust-based clipboard history storage from feature 002 via shared database access.

## Technical Context

**Language/Version**: Swift 5.9+ (macOS UI layer), Rust 1.70+ (shared storage layer)

**Primary Dependencies**:
- **UI Framework**: AppKit (NSPanel, NSTableView) for performance-critical components
- **UI Framework**: SwiftUI (SearchBar, FilterButtons, PreviewPanel) for simple components
- **Reactive**: Combine framework (data flow, bindings)
- **Layout**: SnapKit (Auto Layout DSL for AppKit views) - managed via SPM
- **Global Shortcuts**: KeyboardShortcuts (global hotkey management) - managed via SPM
- **Database**: SQLite.swift (type-safe database wrapper) - managed via SPM
- **Encryption**: CryptoKit (AES-256-GCM), Security framework (Keychain)
- **Package Management**: SPM (Swift Package Manager) - Apple's official dependency manager

**Storage**: SQLite database (shared with feature 002 clipboard history), macOS Keychain (encryption keys)

**Testing**: XCTest (Swift unit tests), cargo test (Rust integration tests)

**Target Platform**: macOS 14+ (Sonoma and later)

**Project Type**: Single project with Swift/Rust hybrid architecture

**Architecture Pattern**: MVVM (Model-View-ViewModel) with hybrid UI approach
- **Performance-critical**: AppKit NSPanel + NSTableView (window management, list rendering)
- **Simple UI**: SwiftUI components (SearchBar, FilterButtons, PreviewPanel)
- **Data Flow**: User Action → ViewModel updates data → View observes and reacts (unidirectional)

**Third-Party Libraries** (explicitly approved):
| Library | Version | SPM URL | Purpose | License |
|---------|---------|---------|---------|---------|
| [SnapKit](https://github.com/SnapKit/SnapKit) | 5.7.0+ | https://github.com/SnapKit/SnapKit.git | Auto Layout DSL for AppKit (reduces layout code by 70%) | MIT |
| [KeyboardShortcuts](https://github.com/soffes/KeyboardShortcuts) | 1.0+ | https://github.com/soffes/KeyboardShortcuts.git | Global keyboard shortcut registration | MIT |
| [SQLite.swift](https://github.com/stephencelis/SQLite.swift) | 0.14+ | https://github.com/stephencelis/SQLite.swift.git | Type-safe SQLite database access | MIT |
| (Apple) Combine | Built-in | - | Reactive data flow | - |
| (Apple) CryptoKit | Built-in | - | AES-256-GCM encryption | - |

**Package Management**: SPM (Swift Package Manager)
- **Why SPM**: Apple's official dependency manager, zero configuration, native Xcode integration
- **Setup**: File → Add Package Dependencies... in Xcode (GUI) or Package.swift
- **No CocoaPods**: Outdated, slower, requires Ruby workspace
- **No Carthage**: Deprecated, manual integration required

**Performance Goals**: <500ms panel render, <300ms search filtering, 60+ FPS scrolling with 1000+ entries, <300ms entry selection

**Constraints**:
- Direct database access (no IPC layer)
- AppKit NSTableView for performance-critical list rendering (not SwiftUI LazyVStack)
- Memory-efficient table view cell reuse (NSTableView built-in recycling)
- 10,000 entry soft limit with FIFO eviction
- Strict MVVM separation, data-driven UI updates only
- No additional third-party libraries without plan update

**Scale/Scope**: Single-user desktop application, 10,000 max clipboard entries, 50 visible entries per viewport, ~10 UI screens (main panel, settings, dialogs)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### I. User Story Priority ✅ PASS
- **Status**: PASS
- **Evidence**: Spec contains 6 user stories clearly prioritized P1-P3 (Stories 1-2: P1, Stories 3, 5-6: P2, Story 4: P3)
- **Validation**: Each story has independent test and acceptance criteria
- **Dependencies**: Story 2 depends on Story 1 (must display before can select), others are independent

### II. Test-First Development ✅ PASS
- **Status**: PASS (will enforce during implementation phase)
- **Plan**: All acceptance scenarios from spec will have corresponding XCTest tests
- **Validation**: Tests will be written before implementation in TDD cycle

### III. Documentation Before Implementation ✅ PASS
- **Status**: PASS
- **Evidence**: spec.md complete with clarifications, plan.md in progress
- **Next**: data-model.md and contracts/ to be generated in Phase 1

### IV. Simplicity & YAGNI ✅ PASS
- **Status**: PASS
- **Evidence**: Features scoped to current user stories only
- **Validation**: No premature abstractions or "future features" included
- **Architecture**: MVVM pattern is standard for SwiftUI apps, not over-engineering
- **Data Flow**: Unidirectional data flow (User Action → ViewModel → State → UI) prevents complexity
- **Complexity Justification**: None needed - MVVM is industry standard for SwiftUI apps

### V. Cross-Platform Compatibility ⚠️ NOT APPLICABLE
- **Status**: N/A
- **Rationale**: This feature is macOS-specific (feature 003). Future platform implementations will reference this design but implement platform-specific UI
- **Documentation**: Spec clarifies macOS 14+ target platform

### VI. Privacy & Security First ✅ PASS
- **Status**: PASS
- **Evidence**:
  - FR-065 to FR-069: Sensitive content detection and optional encryption
  - FR-078: No clipboard content logged (only metadata)
  - Clarification: Detect sensitive patterns, offer optional encryption
  - Encryption keys stored in macOS Keychain (FR-068)
- **Validation**: All clipboard data remains local, encrypted at rest when sensitive

### VII. Architecture Compliance ✅ PASS (MVVM + Data-Driven)

- **Status**: PASS
- **Architecture Pattern**: Strict MVVM (Model-View-ViewModel) with reactive data flow
- **Data Flow**: Unidirectional - User Action → ViewModel updates data → View reacts to data changes
- **Framework**: Combine framework for reactive programming (@Published, Publishers, Subscribers)
- **Separation of Concerns**:
  - **Model**: Immutable data structs, no logic
  - **ViewModel**: Business logic, @Published state, Combine operators
  - **View**: Pure UI rendering, observes ViewModel, sends actions
  - **Service**: Stateless data access, no UI dependencies
- **Data-Driven Rules**:
  - ✅ All UI updates triggered by data changes (never direct manipulation)
  - ✅ Views use @ObservedObject/@StateObject to observe ViewModels
  - ✅ ViewModels expose @Published properties for automatic UI updates
  - ✅ Combine operators (debounce, map, filter) for data transformation
  - ✅ No imperative UI updates (e.g., view.needsDisplay = true)
- **Enforcement**:
  - ViewModels MUST NOT import SwiftUI (only Foundation, Combine)
  - Views MUST NOT call Services directly (delegate to ViewModel)
  - Services MUST NOT have @Published properties (stateless)
  - Data flows ONE WAY: Action → Data → UI (no bidirectional coupling)
- **Validation**: Architecture enables testable ViewModels (no UI dependencies) and reusable Services

### Overall Gate Status: ✅ PASS
All applicable constitution principles satisfied. May proceed to Phase 0 research.

## Project Structure

### Documentation (this feature)

```text
specs/003-clipboard-main-panel/
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output (/speckit.plan command)
├── data-model.md        # Phase 1 output (/speckit.plan command)
├── quickstart.md        # Phase 1 output (/speckit.plan command)
├── contracts/           # Phase 1 output (/speckit.plan command)
├── spec.md              # Feature specification (already complete)
└── checklists/          # Generated checklists
```

### Source Code (repository root)

Based on existing Rust/Swift hybrid architecture from features 001 and 002, with **strict MVVM architecture**:

```text
src/
├── macos/                           # macOS UI layer (Swift) - MVVM Architecture
│   │
│   ├── Models/                      # MODEL LAYER: Data models (no UI logic)
│   │   ├── ClipboardEntry.swift     # Database entity model
│   │   ├── ClipboardEntryListItem.swift  # UI display model
│   │   ├── ContentFilter.swift      # Filter enum
│   │   └── PreviewContent.swift     # Preview content enum
│   │
│   ├── ViewModels/                  # VIEWMODEL LAYER: Business logic & state management
│   │   │                            # - Exposes @Published properties for View to observe
│   │   │                            # - Handles user actions and converts to data updates
│   │   │                            # - Uses Combine for reactive data streams
│   │   │
│   │   ├── MainPanelViewModel.swift     # Main panel state coordinator
│   │   │   ├── @Published var allEntries: [ClipboardEntryListItem]
│   │   │   ├── @Published var filteredEntries: [ClipboardEntryListItem]
│   │   │   ├── @Published var searchText: String
│   │   │   ├── @Published var contentFilter: ContentFilter
│   │   │   ├── @Published var selectedEntryId: String?
│   │   │   └── func handleUserAction(_ action: UserAction)
│   │   │
│   │   ├── ClipboardListViewModel.swift  # List-specific logic
│   │   │   ├── @Published var entries: [ClipboardEntryListItem]
│   │   │   ├── @Published var isLoading: Bool
│   │   │   ├── @Published var scrollPosition: CGFloat
│   │   │   └── func onSelectEntry(_ id: String)
│   │   │
│   │   ├── PreviewPanelViewModel.swift   # Preview-specific logic
│   │   │   ├── @Published var previewContent: PreviewContent?
│   │   │   ├── @Published var copyButtonEnabled: Bool
│   │   │   ├── @Published var pasteButtonEnabled: Bool
│   │   │   └── func handleCopyAction()
│   │   │
│   │   ├── SearchBarViewModel.swift      # Search state management
│   │   │   ├── @Published var searchText: String
│   │   │   ├── @Published var isSearching: Bool
│   │   │   └── private var searchCancellable: AnyCancellable?
│   │   │
│   │   └── FilterViewModel.swift         # Filter state management
│   │       ├── @Published var activeFilter: ContentFilter
│   │       ├── @Published var pinnedFilterEnabled: Bool
│   │       └── func toggleFilter(_ filter: ContentFilter)
│   │
│   ├── Views/                      # VIEW LAYER: SwiftUI views (pure UI rendering)
│   │   │                            # - Observe @Published properties from ViewModel
│   │   │                            # - Render UI based on data state
│   │   │                            # - Send user actions to ViewModel
│   │   │                            # - NO business logic, NO direct state manipulation
│   │   │
│   │   ├── ClipboardPanel/              # Main panel views
│   │   │   ├── ClipboardPanelView.swift      # Root SwiftUI view (observes MainPanelViewModel)
│   │   │   ├── ClipboardListView.swift       # Left panel list view
│   │   │   ├── ClipboardListItemView.swift   # Single entry cell
│   │   │   └── EmptyStateView.swift          # Empty state view
│   │   │
│   │   ├── PreviewPanel/                 # Right panel views
│   │   │   ├── PreviewPanelView.swift       # Preview container (observes PreviewPanelViewModel)
│   │   │   ├── TextPreviewView.swift        # Text content preview
│   │   │   └── ImagePreviewView.swift       # Image content preview
│   │   │
│   │   ├── Controls/                     # Reusable control views
│   │   │   ├── SearchBarView.swift            # Search input (observes SearchBarViewModel)
│   │   │   ├── FilterButtonsView.swift        # Filter toggle buttons
│   │   │   ├── PinnedIndicatorView.swift      # Pin icon component
│   │   │   └── TypeIndicatorView.swift        # Type badge component
│   │   │
│   │   └── ActionButtons/                 # Action button views
│   │       ├── CopyButtonView.swift           # Copy button
│   │       └── PasteButtonView.swift          # Paste button
│   │
│   ├── Services/                   # SERVICES: Data access & business logic (stateless)
│   │   │                            # - Called by ViewModels to fetch/modify data
│   │   │                            # - Return data via Combine publishers or async/await
│   │   │                            # - No UI dependencies, no @Published properties
│   │   │
│   │   ├── ClipboardService.swift       # Database access service
│   │   │   ├── func loadEntries() -> AnyPublisher<[ClipboardEntry], Error>
│   │   │   ├── func copyToClipboard(id: String) async throws
│   │   │   └── func deleteEntry(id: String) async throws
│   │   │
│   │   ├── SearchService.swift          # Search logic service
│   │   │   ├── func search(entries: [ClipboardEntryListItem], query: String) -> [ClipboardEntryListItem]
│   │   │   └── func applyFilters(...) -> [ClipboardEntryListItem]
│   │   │
│   │   ├── EncryptionService.swift       # Encryption service
│   │   │   ├── func encrypt(_ data: Data) async throws -> (Data, String)
│   │   │   └── func decrypt(_ data: Data, keyId: String) async throws -> Data
│   │   │
│   │   └── ThumbnailCache.swift          # Image caching service
│   │       ├── func getThumbnail(for entryId: String) -> NSImage?
│   │       └── func setThumbnail(_ image: NSImage, for entryId: String)
│   │
│   ├── Coordinators/               # COORDINATORS: Navigation & flow control
│   │   └── ClipboardPanelCoordinator.swift  # Panel lifecycle management
│   │       ├── func showPanel()
│   │       ├── func hidePanel()
│   │       └── func handleKeyboardShortcut(_ key: String)
│   │
│   ├── AppKit/                     # AppKit integration (window management)
│   │   ├── ClipboardPanelWindow.swift       # NSPanel subclass
│   │   ├── ClipboardPanelController.swift   # Window controller
│   │   └── KeyboardHandler.swift            # Global keyboard shortcut handler
│   │
│   └── Utils/                      # UTILITIES: Helpers & extensions
│       ├── Extensions/
│       │   ├── String+Extensions.swift
│       │   ├── Date+Formatter.swift
│       │   └── NSImage+Thumbnail.swift
│       └── Logging/
│           └── Logger.swift
│
├── core/                            # Shared Rust layer (from features 001-002)
│   ├── clipboard/                   # Clipboard history storage
│   │   ├── models.rs                # Entry, Database schema
│   │   └── storage.rs              # SQLite operations
│   └── encryption/                  # Encryption utilities
│       └── mod.rs
│
tests/
├── macos/                           # Swift tests (XCTest)
│   ├── ViewModels/                  # ViewModel unit tests
│   │   ├── MainPanelViewModelTests.swift
│   │   ├── ClipboardListViewModelTests.swift
│   │   └── PreviewPanelViewModelTests.swift
│   ├── Services/                    # Service unit tests
│   │   ├── ClipboardServiceTests.swift
│   │   ├── SearchServiceTests.swift
│   │   └── EncryptionServiceTests.swift
│   └── Integration/                 # Integration tests
│       └── ClipboardPanelIntegrationTests.swift
│
└── core/                            # Rust tests (cargo test)
    └── clipboard/
        └── storage_tests.rs
```

**Architecture Decision**: **Strict MVVM pattern with reactive data flow using Combine framework**.

### MVVM Data Flow (Unidirectional)

```
User Action (View)
      ↓
  View.send(action) ──────────────┐
      ↓                           │
ViewModel.handle(action)           │
      ↓                           │
  Update @Published properties     │
      ↓                           │
Combine Publisher emits ────┐     │
      ↓                    │     │
View automatically         │     │
reacts to changes          │     │
      ↓                    │     │
  UI updates               │     │
                             │     │
◀────────────────────────────┘     │
     Combine subscribers          │
                                    │
Service Layer (background) ────────┘
  - ClipboardService (data fetching)
  - SearchService (filtering)
  - EncryptionService (encryption)
```

### MVVM Layer Responsibilities

**Model Layer** (Immutable data structures):
- ✅ Data structs: `ClipboardEntry`, `ClipboardEntryListItem`
- ✅ Value types: Enums, structs representing domain entities
- ❌ NO UI logic, NO state management, NO Combine publishers

**ViewModel Layer** (State & business logic coordinator):
- ✅ `@Published` properties for View to observe
- ✅ `func handle(_ action: UserAction)` to receive user actions
- ✅ Combine operators for data transformation (`map`, `filter`, `debounce`)
- �️ Coordinate Service calls and update state
- ❌ NO SwiftUI views, NO direct UI manipulation
- ❌ NO view lifecycle code (e.g., `.onAppear`, `.onDisappear`)

**View Layer** (Pure UI rendering):
- ✅ SwiftUI views that observe ViewModel: `@ObservedObject var viewModel`
- ✅ Render UI based on data state: `if viewModel.isLoading { ProgressView() }`
- ✅ Send actions to ViewModel: `Button("Copy") { viewModel.handle(.copy) }`
- ❌ NO business logic, NO direct state manipulation
- ❌ NO Service calls (delegate to ViewModel)

**Service Layer** (Stateless data access):
- ✅ Fetch/modify data via Combine publishers or async/await
- ✅ Pure functions, no side effects except I/O
- ❌ NO UI dependencies, NO @Published properties
- ❌ NO view logic

### Key Combine Patterns Used

1. **@Published + $publisher**: ViewModels expose state changes
   ```swift
   @Published var filteredEntries: [ClipboardEntryListItem] = []
   ```

2. **flatMap**: Chain async operations
   ```swift
   $selectedEntryId
       .compactMap { $0 }
       .flatMap { id in clipboardService.loadEntry(id: id) }
       .assign(to: &$previewContent)
   ```

3. **debounce**: Search debouncing
   ```swift
   $searchText
       .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
       .sink { [weak self] text in self?.performSearch(text) }
       .store(in: &cancellables)
   ```

4. **combineLatest**: Multiple dependency coordination
   ```swift
   Publishers.CombineLatest($entries, $contentFilter)
       .map { entries, filter in applyFilter(entries, filter) }
       .assign(to: &$filteredEntries)
   ```

### Enforcement Rules

1. **Views NEVER call Services directly** - All data access through ViewModel
2. **ViewModels NEVER import SwiftUI** - Only Foundation, Combine
3. **Models are immutable value types** - Use `struct` and `let`
4. **Data flows unidirectionally** - User Action → ViewModel → State Update → UI Update
5. **No imperative UI updates** - Use `@Published` and reactive bindings, never `view.needsDisplay = true`

This strict MVVM separation ensures:
- ✅ Testability: ViewModels are pure Swift logic (no UI dependencies)
- ✅ Reusability: Services can be used by multiple ViewModels
- ✅ Maintainability: Clear layer boundaries prevent spaghetti code
- ✅ Reactive: Combine publishers enable automatic UI updates

---

## Phase Completion Status

- ✅ **Phase 0: Research** - Complete (see `research.md`)
- ✅ **Phase 1: Design & Contracts** - Complete (see `data-model.md`, `contracts/`, `quickstart.md`)
- ⏸️ **Phase 2: Task Breakdown** - Pending (run `/speckit.tasks` to generate `tasks.md`)

## Artifacts Generated

| Artifact | Path | Description |
|----------|------|-------------|
| Implementation Plan | `plan.md` | This file |
| Research | `research.md` | Technical decisions and findings |
| Data Model | `data-model.md` | Entity definitions and relationships |
| Service Contracts | `contracts/ClipboardService.md` | Database access service |
| Service Contracts | `contracts/SearchService.md` | Search and filter service |
| Service Contracts | `contracts/EncryptionService.md` | Encryption key management |
| Quickstart Guide | `quickstart.md` | Local development setup |
| Feature Spec | `spec.md` | Original specification (pre-existing) |

## Constitution Re-Check (Post-Design)

### Updated Assessment: ✅ PASS

All constitution principles remain satisfied after Phase 1 design:

- **I. User Story Priority**: ✅ Data model supports independent story implementation
- **II. Test-First Development**: ✅ Contracts include test specifications
- **III. Documentation Before Implementation**: ✅ All design artifacts complete
- **IV. Simplicity & YAGNI**: ✅ No unnecessary abstractions introduced
- **V. Cross-Platform Compatibility**: ⚠️ N/A (macOS-specific UI)
- **VI. Privacy & Security First**: ✅ Encryption service designed with Keychain storage

**Gate Status**: ✅ PASS - Proceed to Phase 2 task generation


