# Feature Specification: Clipboard Main Panel (macOS)

**Feature Branch**: `002-clipboard-main-panel`  
**Created**: 2026-02-07  
**Status**: Draft  
**Input**: Define the application's primary main panel UI and base interaction model (search, results list, preview, footer shortcuts). Panel is shown via a global shortcut and appears on the current mouse screen. Search uses like-matching over stored clipboard history. Retire the previous feature's demo UI styling/behavior.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Open and dismiss the main panel (Priority: P1)

As a user, I can press a global shortcut to show the main panel, and I can dismiss it to return to what I was doing.

**Why this priority**: Without a reliable show/dismiss flow, the panel is not usable.

**Independent Test**: With the app running and no visible windows, press the shortcut to open the panel; dismiss it; repeat multiple times.

**Acceptance Scenarios**:

1. **Given** the app is running and the main panel is hidden, **When** I press `cmd+shift+v`, **Then** the main panel becomes visible.
2. **Given** the main panel is visible, **When** I dismiss it (Escape or clicking outside), **Then** it becomes hidden.
3. **Given** the main panel is visible, **When** I press `cmd+shift+v` again, **Then** it becomes hidden (toggle behavior).

---

### User Story 2 - Search and see results update (Priority: P2)

As a user, I can type in a search field and see a list of matching clipboard history items update as I type, so I can quickly find a past copy.

**Why this priority**: Searching is the main reason to open the panel.

**Independent Test**: Ensure there are known history items, open the panel, type a query, and confirm the results list changes immediately based on like-matching.

**Acceptance Scenarios**:

1. **Given** clipboard history contains items, **When** I type a query, **Then** the results list updates to show only items that like-match the query.
2. **Given** the query matches no items, **When** I type that query, **Then** the results list shows an explicit empty state.
3. **Given** the query is cleared to empty, **When** the query becomes empty, **Then** the results list shows a default set of items (assumed: most recent items).

---

### User Story 3 - Select an item and preview it (Priority: P3)

As a user, I can click a result item to preview its content and basic information so I can confirm I selected the right item.

**Why this priority**: Preview reduces mistakes and makes search results actionable.

**Independent Test**: With both text and image items present, open the panel, click different items, and verify the preview updates accordingly.

**Acceptance Scenarios**:

1. **Given** the results list contains a text item, **When** I click it, **Then** the preview shows the text content and basic item information.
2. **Given** the results list contains an image item, **When** I click it, **Then** the preview shows an image preview and basic item information.
3. **Given** I select different items, **When** I click another item, **Then** the preview updates to the newly selected item without manual refresh.

---

### Edge Cases

- Clipboard history is empty: panel still opens; results show an empty state.
- Very large text entries: list remains responsive; preview remains usable (scrolling or truncation).
- Very large images: preview fits within its area and does not overflow the panel.
- Multiple screens and scaling: panel appears fully visible on the screen containing the mouse cursor.
- Fast typing: results remain responsive and do not show stale results.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The app MUST run as a background utility and MUST NOT appear in the Dock during normal use.
- **FR-002**: The system MUST provide a global keyboard shortcut `cmd+shift+v` that toggles the visibility of the main panel.

- **FR-003**: When the main panel is shown, the search input MUST receive focus automatically.
- **FR-004**: When the main panel is shown, it MUST appear on the screen where the mouse cursor is located at the time of opening.
- **FR-005**: When shown, the main panel MUST be positioned centered horizontally and slightly above the vertical center of the target screen.

- **FR-006**: The main panel MUST contain three regions: (1) top search input, (2) middle area split into left results list and right preview, (3) footer that describes available shortcuts.
- **FR-006a**: The footer MUST display, at minimum, the shortcuts to toggle the panel (`cmd+shift+v`) and dismiss it (Escape).

- **FR-007**: The system MUST support searching clipboard history items based on the user-entered query.
- **FR-008**: Search matching MUST behave like a like-match (partial match) against each item's searchable text.
- **FR-009**: When the query is empty, the results list MUST display a default set of items (assumed: most recent items).
- **FR-010**: When there are no matches, the results list MUST show an explicit empty state.

- **FR-011**: Users MUST be able to select a result item via mouse click.
- **FR-012**: When an item is selected, the preview region MUST update to show content appropriate to the selected item's type.
- **FR-013**: For text items, the preview MUST display the stored text content.
- **FR-014**: For image items, the preview MUST display an image preview scaled to fit within the preview area.
- **FR-015**: The preview MUST display basic item information (at minimum: item type and last-copied timestamp).

- **FR-016**: The application MUST remove or disable the prior feature's demo UI styling and demo-only behavior so it is not part of the product experience.
- **FR-017**: The application MUST NOT automatically open any demo/history window on launch.

### Key Entities *(include if feature involves data)*

- **Clipboard History Item**: A single clipboard entry available for search and preview; key attributes: `id`, `type` (text/image), searchable text, and timestamps including last-copied time.
- **Search Query**: The user-entered string used to filter items.
- **Selection**: The currently selected clipboard history item that drives the preview.

## Assumptions

- Clipboard history capture and local persistence already exist (from feature 001) and are the data source for search and preview.
- Like-matching is case-insensitive for typical user expectations where supported by the underlying store.
- Default results for an empty query are the most recent items.
- Dismiss behavior includes Escape and clicking outside the panel.

## Dependencies

- A local store of clipboard history items exists and can be queried by recency and by like-matching over a searchable text representation.
- The app can register a global hotkey and show a panel on the active screen.

## Out of Scope

- Pasting/applying the selected item into the frontmost application
- Editing, deleting, pinning, tagging, or favoriting history items
- Advanced query operators (filters, regex, tokenization)
- Keyboard navigation within the list (may be added in a later feature)

### Acceptance Criteria Mapping

- FR-001 to FR-006 are accepted when User Story 1 acceptance scenarios pass.
- FR-007 to FR-010 are accepted when User Story 2 acceptance scenarios pass.
- FR-011 to FR-015 are accepted when User Story 3 acceptance scenarios pass.
- FR-016 to FR-017 are accepted when the prior demo UI is no longer visible/used in normal app operation.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: In a manual test session of 20 shortcut activations, the panel becomes visible within 0.25 seconds for at least 95% of activations.
- **SC-002**: In a manual test session of 20 panel opens, the search input is focused on open 100% of the time.
- **SC-003**: With up to 1000 stored history items, results update within 0.15 seconds after each keystroke for at least 95% of keystrokes during typical typing.
- **SC-004**: Switching selection between two items updates the preview within 0.2 seconds for at least 95% of selections.
- **SC-005**: On app launch, the app does not appear in the Dock during normal use and no demo/history window opens automatically.
