# Feature Specification: Clipboard Main Panel UI

**Feature Branch**: `003-clipboard-main-panel`
**Created**: 2026-02-04
**Status**: Draft
**Input**: User description: "003-clipboard-main-panel"

## Clarifications

### Session 2026-02-04
- Q: How should pinned entry state persist across application restarts? → A: Store pinned flag and pinned timestamp in clipboard history database (persists across restarts)
- Q: How should the main panel communicate with the clipboard history service from feature 002? → A: Direct database access with read-only queries (same process space)
- Q: How should sensitive clipboard content (passwords, API keys, etc.) be handled? → A: Detect common sensitive patterns and offer optional encryption for sensitive entries
- Q: What is the maximum clipboard history size limit and eviction policy? → A: Soft limit at 10,000 entries with FIFO eviction (pinned entries exempt)
- Q: What logging and observability strategy should be used? → A: Structured logging with configurable levels (error/warn/info/debug)

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Display Clipboard History List (Priority: P1)

Users need to view their clipboard history in a main panel that shows all previously copied items. When they open the panel, they should see a scrollable list of clipboard entries organized chronologically with the most recent items at the top.

**Why this priority**: This is the primary user interface for accessing clipboard history. Without a visible list, users cannot access the data being captured by feature 002. This delivers immediate user value by making clipboard history visible and accessible.

**Independent Test**: Can be fully tested by opening the main panel and verifying it displays a list of previously copied clipboard entries. The test passes when the panel appears, shows at least 10 entries in reverse chronological order, and each entry displays basic information (content preview, timestamp, source app).

**Acceptance Scenarios**:

1. **Given** the application is running with clipboard history enabled, **When** user presses Cmd+Shift+V, **Then** a window appears displaying all recorded clipboard entries in a list
2. **Given** the main panel is open with clipboard entries displayed, **When** user scrolls through the list, **Then** all entries are accessible and scroll smoothly without lag
3. **Given** clipboard entries with different content types, **When** main panel displays the list, **Then** each entry shows appropriate preview (text snippet for text, thumbnail for image)
4. **Given** the main panel is open, **When** user copies new content to clipboard, **Then** the list updates automatically to show the new entry at the top
5. **Given** the main panel is shown, **When** it appears, **Then** the search input is focused and the first entry is selected

---

### User Story 2 - Select and Copy Clipboard Entry (Priority: P1)

Users need to select an item from the clipboard history and copy it back to the system clipboard. When they trigger a copy action, the content should be copied to the clipboard, making it available for pasting in other applications.

**Why this priority**: This is the core utility of the clipboard manager - allowing users to reuse previous clipboard content. Without selection and copy functionality, the history is just a display with no utility. This is equal priority with Story 1 because both are needed for basic functionality.

**Independent Test**: Can be fully tested by selecting an entry from the history list, triggering copy (Cmd+Enter) or paste (Enter), and verifying the content in a target application. The test passes when the pasted content matches the original clipboard entry.

**Acceptance Scenarios**:

1. **Given** the main panel displays clipboard entries, **When** user selects an entry, **Then** the preview updates without copying to clipboard
2. **Given** user has selected a clipboard entry, **When** user presses Cmd+Enter, **Then** the selected entry's full content is copied to the system clipboard
3. **Given** user has selected a clipboard entry, **When** user presses Enter, **Then** the entry is copied to the system clipboard, the panel closes, and Cmd+V is sent to the previously active application unless the previous application is this app
4. **Given** user selects a text or image entry and triggers copy, **Then** the full content (not just preview) is copied to clipboard

---

### User Story 3 - Search Clipboard History (Priority: P2)

Users need to search through their clipboard history to find specific content. When they type in a search box, the list should filter to show only matching entries.

**Why this priority**: Search significantly improves usability when clipboard history grows large. Users can quickly find specific content without scrolling through hundreds of entries. This is lower priority than basic display and copy because users can still access content without search, just less efficiently.

**Independent Test**: Can be fully tested by typing search terms in the search box and verifying the list filters correctly. The test passes when only matching entries are displayed and non-matching entries are hidden.

**Acceptance Scenarios**:

1. **Given** the main panel displays many clipboard entries, **When** user types a search term, **Then** the list filters to show only entries containing the search term
2. **Given** search results are displayed, **When** user clears the search term, **Then** all entries are displayed again
3. **Given** text entries with various content, **When** user searches for a specific word or phrase, **Then** only text entries containing that word or phrase are shown
4. **Given** search results, **When** no entries match the search term, **Then** a "no results found" message is displayed

---

### User Story 4 - Delete Clipboard Entries (Priority: P3)

Users need to remove unwanted or sensitive clipboard entries from history. When they select entries and delete them, those entries should be removed from the database and no longer appear in the list.

**Why this priority**: Privacy and data management are important but not essential for basic functionality. Users can benefit from the clipboard manager without deleting entries, but deletion provides control over sensitive data. This is lower priority than access and search features.

**Independent Test**: Can be fully tested by selecting entries and deleting them, then verifying they no longer appear in the list. The test passes when deleted entries are removed immediately and cannot be recovered through normal UI.

**Acceptance Scenarios**:

1. **Given** the main panel displays clipboard entries, **When** user deletes a single entry, **Then** that entry is removed from the list and database
2. **Given** multiple entries selected, **When** user deletes them, **Then** all selected entries are removed from the list and database
3. **Given** deleted entries, **When** user refreshes or reopens the main panel, **Then** deleted entries do not reappear
4. **Given** all entries deleted, **When** user views the main panel, **Then** an empty state message is displayed

---

### User Story 5 - Pin Important Entries (Priority: P2)

Users need to pin important or frequently used clipboard entries so they remain easily accessible at the top of the list. When they pin an entry, it should stay at the top regardless of when newer entries are added.

**Why this priority**: Pinning improves productivity for users who frequently reuse specific content (e.g., code snippets, email templates, responses). This is medium priority because users can still access content without pinning, but pinning provides significant efficiency benefits for power users.

**Independent Test**: Can be fully tested by pinning multiple entries, adding new clipboard content, and verifying pinned entries remain at the top. The test passes when pinned entries are displayed above all unpinned entries and show a red pushpin icon.

**Acceptance Scenarios**:

1. **Given** the main panel displays clipboard entries, **When** user pins an entry, **Then** that entry moves to the top of the list and displays a red pushpin icon
2. **Given** multiple pinned entries, **When** user views the list, **Then** all pinned entries appear above unpinned entries in reverse chronological order (most recent pinned first)
3. **Given** a pinned entry, **When** user copies new content to clipboard, **Then** the pinned entry remains at the top above the new entry
4. **Given** the pinned filter toggle is activated, **When** user views the list, **Then** only pinned entries are displayed
5. **Given** a pinned entry, **When** user unpins it, **Then** the entry returns to its normal chronological position and the pushpin icon disappears

---

### User Story 6 - Keyboard Navigation (Priority: P2)

Users need to navigate and select clipboard entries using keyboard shortcuts for faster workflow. When they use arrow keys, they should be able to move through the list and select entries without touching the mouse.

**Why this priority**: Keyboard navigation significantly improves efficiency for power users who prefer keyboard over mouse. This is medium priority because mouse-based selection works, but keyboard navigation provides better user experience.

**Independent Test**: Can be fully tested by using keyboard shortcuts to navigate the list and select entries. The test passes when users can move through the list, select entries, and copy content using only keyboard.

**Acceptance Scenarios**:

1. **Given** the main panel is open with clipboard entries, **When** user presses arrow keys, **Then** the selection moves up/down through the list
2. **Given** the selection is on the first entry, **When** user presses Up, **Then** selection moves to the last entry (wrap-around)
3. **Given** the selection is on the last entry, **When** user presses Down, **Then** selection moves to the first entry (wrap-around)
4. **Given** an entry is selected, **When** user presses Cmd+Enter, **Then** the selected entry is copied to clipboard
5. **Given** an entry is selected, **When** user presses Enter, **Then** the selected entry is copied, the panel closes, and Cmd+V is sent to the previously active application unless the previous application is this app
6. **Given** the main panel is shown, **When** user presses Escape, **Then** the main panel closes

---

### Edge Cases

- What happens when clipboard history is empty (no entries recorded yet)? (Display empty state with helpful message)
- What happens when clipboard entry content is too large to display? (Show truncated preview with full content available in preview panel)
- What happens when clipboard entry content is empty or null? (Display placeholder text indicating empty content)
- What happens when image preview cannot be generated? (Show generic image icon as fallback)
- What happens when clipboard history contains thousands of entries? (Implement pagination or virtual scrolling for performance)
- What happens when user performs rapid searches (typing quickly)? (Debounce search to avoid excessive filtering operations)
- What happens when main panel is resized to very small dimensions? (Show scrollbars and maintain minimum usable width)
- What happens when clipboard entry source application is no longer installed? (Still display app name and icon from recorded metadata)
- What happens when user deletes entry that is currently selected? (Select next entry if available; otherwise select previous entry; preview updates accordingly)
- What happens when user has pinned all entries and adds new content? (New content appears below pinned entries)
- What happens when preview panel content is extremely long (e.g., 10,000 characters)? (Show scrollable text area with line wrapping)
- What happens when user toggles between All/Text/Images filters with active search? (Apply both filters in combination)
- What happens when application icon cannot be loaded? (Show generic app icon placeholder)
- What happens when user pins an entry, then unpins it? (Entry returns to its normal chronological position based on timestamp)
- What happens when sensitive content (password, API key) is detected in clipboard entry? (Display warning icon and offer encryption option)
- What happens when user encrypts a sensitive entry but forgets encryption password? (Encrypted content remains inaccessible; provide recovery warning)
- What happens when clipboard history reaches 10,000 entry soft limit? (Auto-delete oldest unpinned entries using FIFO eviction, preserve pinned entries)
- What happens when user has 10,000 pinned entries and limit is reached? (Stop auto-eviction, notify user to manually unp/delete entries)

## UI Design Specifications

### Overall Layout

- **Two-Panel Layout**: Main panel divided into left panel (clipboard list) and right panel (preview and actions)
- **Panel Split**: Left panel occupies ~70% of width, right panel ~30%
- **Window Style**: Dark-themed floating panel with rounded corners, no traditional title bar
- **Divider**: Thin separator line between left and right panels

### Left Panel - Clipboard List

#### Top Bar
- **Search Bar**: Left-aligned, rounded corners, magnifying glass icon, placeholder text "Search clipboard..."
- **Filter Buttons**: Right-aligned, four options:
  - "All" (show all entries)
  - "Text" (show text entries only)
  - "Images" (show image entries only)
  - Toggle switch (likely for "Pinned" filter)
- **Active State**: Selected filter button highlighted with blue background

#### List Items
Each clipboard entry displays as a card with:
- **Title**: Bold, medium-sized font showing content preview (first ~50 characters for text)
- **Source Information**: Below title, showing:
  - Application icon (16×16px) for source app
  - Application name (e.g., "Raycast", "Safari", "WeChat", "Terminal")
  - Type indicator (colored square: red for text, green for image)
  - Separator dot between elements
- **Timestamp**: Right-aligned, compact format (e.g., "2 min ago", "11 min ago")
- **Pinned Indicator**: Red pushpin icon next to source for pinned entries
- **Selection State**: Selected entry has blue background with subtle left border
- **Spacing**: ~8-10px between items, ~12px padding within each card

### Right Panel - Preview & Actions

#### Preview Section
- **Header**: "PREVIEW" in bold, uppercase text at top
- **Content Area**: Displays full preview of selected clipboard entry
  - For text: Full text content with line wrapping
  - For images: Image preview fitted to panel width
- **Action Buttons** (at bottom):
  - "Copy": Gray, outlined button (secondary action)
  - "Paste": Blue, filled button (primary action)
- **Keyboard Shortcuts Bar**: Bottom tip bar showing shortcuts (e.g., "Enter paste · Cmd+Enter copy")

### Visual Style

#### Color Scheme
- **Background**: Deep charcoal gray (#1a1a1a or similar)
- **Accent Color**: Bright blue (#3b82f6) for selected items, primary buttons, active states
- **Text**:
  - Primary (titles, labels): White (#ffffff)
  - Secondary (timestamps, sources): Light gray (#a0a0a0)
- **Borders/Dividers**: Thin, light gray lines
- **Type Indicators**: Red square for text, green for images

#### Typography
- **Headers**: Bold, uppercase, slightly larger font size
- **Titles**: Bold, medium-sized font for entry content
- **Secondary Text**: Regular, smaller font for metadata
- **Tips/Shortcuts**: Smallest font size, light gray

#### Icons
- **Search**: Magnifying glass icon
- **Type Indicators**: Colored squares (red for text, green for images)
- **Pinned Items**: Red pushpin icon
- **Source Applications**: App-specific icons (16×16px)

### Interactive Elements

#### Selection Behavior
- Clicking a list item selects it and shows preview in right panel
- Selected item highlighted with blue background
- Selection does NOT automatically copy to clipboard (user must explicitly click Copy or Paste)

#### Copy vs Paste Actions
- **Copy Button**: Copies selected entry to system clipboard (for later pasting)
- **Paste Button**: Copies selected entry to clipboard AND immediately pastes into active application
- **Keyboard Shortcuts**:
  - Cmd+Enter: Copy selected entry to clipboard
  - Enter: Copy selected entry, close panel, and paste into previously active application (Cmd+V), unless the previous application is this app

#### Filtering
- Filter buttons (All/Text/Images) immediately filter the list
- Toggle switch shows only pinned entries when activated
- Search text filters by entry title/content in real-time

## Requirements *(mandatory)*

### Functional Requirements

#### Main Panel Display
- **FR-001**: System MUST provide a main panel window that displays clipboard history entries and floats above other applications' windows while remaining below other in-app UI
- **FR-002**: System MUST display clipboard entries in reverse chronological order (most recent first)
- **FR-003**: System MUST show content preview for each entry (text snippet for text, thumbnail for image)
- **FR-004**: System MUST display timestamp for each clipboard entry in human-readable format (e.g., "2 minutes ago", "Today at 3:45 PM")
- **FR-005**: System MUST display source application name for each clipboard entry
- **FR-006**: System MUST support scrolling through clipboard history list when entries exceed visible area and keep the selected entry within the visible viewport
- **FR-007**: System MUST update the main panel automatically when new clipboard entries are added
- **FR-008**: System MUST display empty state message when no clipboard entries exist

#### Entry Selection and Preview
- **FR-009**: System MUST allow user to select a clipboard entry by clicking on it and select the first entry by default when the panel is shown
- **FR-010**: System MUST display selected entry in preview panel without automatically copying to clipboard
- **FR-011**: System MUST provide visual feedback indicating which entry is currently selected (blue background, left border)
- **FR-012**: System MUST show full content preview for selected entry in right panel
- **FR-013**: System MUST display text preview with line wrapping for text entries and allow text selection
- **FR-014**: System MUST display fitted image preview for image entries

#### Copy and Paste Actions
- **FR-015**: System MUST provide "Copy" button that copies selected entry to system clipboard
- **FR-016**: System MUST provide "Paste" button that copies entry to clipboard AND immediately pastes into active application
- **FR-017**: System MUST support keyboard shortcut Cmd+Enter to copy selected entry to clipboard
- **FR-018**: System MUST support Enter key to copy the selected entry, close the panel, and send Cmd+V to the previously active application unless the previous application is this app
- **FR-019**: System MUST display keyboard shortcut hints in bottom tip bar

#### Entry Display Information
- **FR-020**: System MUST display content title for each entry (first ~50 characters for text)
- **FR-021**: System MUST display source application icon for each entry
- **FR-022**: System MUST display source application name for each entry
- **FR-023**: System MUST display content type indicator for each entry (colored square: red for text, green for image)
- **FR-024**: System MUST display timestamp in compact format (e.g., "2 min ago", "11 min ago")
- **FR-025**: System MUST display separator dots between source name and type indicator

#### Pinned Entries
- **FR-026**: System MUST allow user to pin important clipboard entries
- **FR-027**: System MUST display red pushpin icon next to pinned entries
- **FR-028**: System MUST keep pinned entries at top of list regardless of timestamp
- **FR-029**: System MUST provide toggle switch to filter and show only pinned entries
- **FR-030**: System MUST allow user to unpin entries

#### Search and Filter
- **FR-031**: System MUST provide a search input field in the main panel top bar and focus it when the panel is shown
- **FR-032**: System MUST filter clipboard history list based on search text entered by user
- **FR-033**: System MUST search within text content of clipboard entries
- **FR-034**: System MUST support case-insensitive search
- **FR-035**: System MUST debounce search input to avoid excessive filtering (wait at least 300ms after user stops typing)
- **FR-036**: System MUST display "no results found" message when search returns zero matches
- **FR-037**: System MUST clear search filter and show all entries when search input is cleared

#### Content Type Filtering
- **FR-038**: System MUST provide "All" filter button to show all clipboard entries
- **FR-039**: System MUST provide "Text" filter button to show only text entries
- **FR-040**: System MUST provide "Images" filter button to show only image entries
- **FR-041**: System MUST highlight the active filter button with blue background
- **FR-042**: System MUST immediately filter list when user clicks a filter button

#### Delete Operations
- **FR-043**: System MUST allow user to delete a single clipboard entry, including via Cmd+D
- **FR-044**: System MUST allow user to delete multiple selected clipboard entries
- **FR-045**: System MUST remove deleted entries from database (not just hide from UI)
- **FR-046**: System MUST provide confirmation dialog above the main panel before deleting entries to prevent accidental deletion
- **FR-047**: System MUST refresh the main panel immediately after deletion and update selection to the next entry (or previous if no next entry exists)

#### Keyboard Navigation
- **FR-048**: System MUST support arrow keys (up/down) for navigating through clipboard list with wrap-around at list ends
- **FR-049**: System MUST support Escape key and outside click to close the main panel
- **FR-050**: System MUST handle panel key actions at the panel layer while the panel is shown and keep search input focus during those actions
- **FR-051**: System MUST disable panel key actions when other in-app panels are shown

#### Performance and Scalability
- **FR-053**: System MUST render main panel with visible entries in under 500 milliseconds
- **FR-054**: System MUST support displaying at least 1000 clipboard entries without performance degradation
- **FR-055**: System MUST use virtual scrolling or pagination when clipboard history exceeds 500 entries
- **FR-056**: System MUST cache thumbnails for image entries to avoid regenerating on each render
- **FR-070**: System MUST enforce soft limit of 10,000 total clipboard entries
- **FR-071**: System MUST auto-delete oldest unpinned entries (FIFO eviction) when soft limit is exceeded
- **FR-072**: System MUST exempt pinned entries from automatic eviction regardless of age
- **FR-073**: System MUST notify user when entries are approaching storage limit (at 90% capacity)

#### UI State and Persistence
- **FR-057**: System MUST remember main panel window size and position between sessions
- **FR-058**: System MUST remember search filter state between main panel open/close cycles
- **FR-059**: System MUST restore scroll position when main panel is reopened
- **FR-060**: System MUST support global keyboard shortcut Cmd+Shift+V to open the main panel

#### Content Display
- **FR-061**: System MUST truncate text titles that exceed display width (show first ~50 characters in list)
- **FR-062**: System MUST generate image thumbnails for image entries in list view
- **FR-063**: System MUST show generic placeholder icon when image thumbnail cannot be generated
- **FR-064**: System MUST display different visual indicators for text vs image entries (colored squares)

#### Security and Privacy
- **FR-065**: System MUST detect common sensitive patterns in clipboard content (passwords, API keys, credit card numbers, tokens)
- **FR-066**: System MUST provide visual indicator (warning icon) for entries containing detected sensitive content
- **FR-067**: System MUST offer option to encrypt sensitive clipboard entries at rest
- **FR-068**: System MUST store encryption keys securely in macOS Keychain when encryption is enabled
- **FR-069**: System MUST allow user to opt-out of sensitive content detection in settings

#### Observability and Logging
- **FR-074**: System MUST implement structured logging in JSON format with timestamp, level, and message fields
- **FR-075**: System MUST support configurable log levels (error, warn, info, debug) with default at info level
- **FR-076**: System MUST log errors to stderr including context (operation, entry ID, error message)
- **FR-077**: System MUST log performance metrics for slow operations (render time >500ms, search time >300ms)
- **FR-078**: System MUST not log clipboard content (only metadata like entry ID, operation type) to protect privacy

### Key Entities

- **ClipboardEntryListItem**: Represents a clipboard entry displayed in the main panel UI. Attributes: entry ID, content title (first ~50 characters), content preview (text snippet or thumbnail), timestamp (formatted for display, e.g., "2 min ago"), source application name, source application icon, content type indicator (colored square), pinned status, selection state
- **MainPanelState**: Represents the current state of the main panel. Attributes: filter/search text, active content type filter (All/Text/Images), pinned filter toggle state, scroll position, selected entry ID, window dimensions, panel visibility state
- **PreviewPanel**: Represents the right panel showing selected entry details. Attributes: selected entry ID, preview content (full text or image), action button states (Copy/Paste), keyboard shortcut hints display
- **PinnedEntry**: Represents a clipboard entry that has been pinned by the user. Attributes: entry ID, pinned timestamp, pinned position in list, pin/unpin toggle state. Pinned state persists in database across application restarts.
- **ApplicationIcon**: Represents the source application's icon for visual identification. Attributes: application name, bundle identifier, icon image data, icon size (16×16px)
- **ContentFilter**: Represents the active content type filter. Attributes: filter type (All/Text/Images), active state, filtered result count
- **SearchFilter**: Represents the active search filter criteria. Attributes: search text, filter scope (content only vs all fields), case sensitivity setting, match count
- **ThumbnailCache**: Represents cached image thumbnails for performance. Attributes: entry ID, thumbnail image data, cache timestamp, thumbnail dimensions
- **EmptyState**: Represents the UI state when no clipboard entries exist. Attributes: message text, icon/illustration, suggested actions

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Users can open the main panel using a keyboard shortcut (Cmd+Shift+V) and see their clipboard history in under 1 second
- **SC-002**: Main panel displays at least 50 visible clipboard entries without scrolling or lag
- **SC-003**: Users can select a clipboard entry and see its full preview in the right panel within 300 milliseconds
- **SC-004**: Users can copy a selected entry using the Copy button or Cmd+Enter, and paste using the Paste button or Enter
- **SC-005**: Search filters clipboard history list in under 300 milliseconds after user stops typing
- **SC-006**: Main panel remains responsive when displaying up to 1000 clipboard entries (scroll frame rate above 30 FPS)
- **SC-007**: Users can navigate the entire clipboard list using only keyboard (arrow keys, Cmd+Enter, Enter, Escape, Cmd+D)
- **SC-008**: Deleted entries are removed from database and UI immediately in under 500 milliseconds
- **SC-009**: 90% of users can successfully find and copy a clipboard entry from their history on first attempt without instructions
- **SC-010**: Main panel automatically updates to show new clipboard entries within 1 second of user copying content
- **SC-011**: Users can search through 1000 clipboard entries and find specific content in under 5 seconds
- **SC-012**: Users can pin entries and see them appear at the top of the list within 300 milliseconds
- **SC-013**: Pinned entries remain at the top of the list even after adding 100 new clipboard entries
- **SC-014**: Content type filters (All/Text/Images) update the list within 200 milliseconds

## Assumptions

- Main panel accesses clipboard history data via direct database read-only queries in the same process space (no IPC layer needed)
- Main panel is a standard window that can be opened via keyboard shortcut (Cmd+Shift+V) or menu bar icon
- Text title truncation at ~50 characters in list view provides enough context for users to identify content
- Full content preview in right panel provides complete text or image for verification before copying
- Image thumbnails in list view should be generated at reasonable size (e.g., 80×80 pixels) to balance UI space and performance
- Main panel should remember its size, position, and filter state between sessions to avoid user having to reconfigure
- Delete confirmation should use standard macOS alert dialog for consistency
- Search should work on text content only; image entries are not searchable by content (only by metadata)
- Virtual scrolling or pagination should load entries in chunks of 50-100 for optimal performance
- Empty state message should guide users on how to start using clipboard history
- Pinned entries are stored in database with a pinned flag and pinned timestamp
- Application icons are retrieved from macOS bundle identifier and cached for performance
- Copy button copies to clipboard but does not switch applications; Paste button copies and switches to active application for pasting
- Users understand the difference between Copy (Cmd+Enter) and Paste (Enter) actions based on button labels and tooltips
- Content type filters (All/Text/Images) operate independently from search text (both filters apply simultaneously)
