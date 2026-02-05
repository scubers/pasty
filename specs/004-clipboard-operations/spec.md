# Feature Specification: Clipboard Operation Logic

**Feature Branch**: `004-clipboard-operations`
**Created**: 2026-02-06
**Status**: Draft
**Input**: User description: "004-clipboard-operation-logic"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Copy Entry to System Clipboard (Priority: P1)

Users need to copy clipboard entries from their history back to the system clipboard for reuse. When they select an entry and trigger a copy action, the system should place the content on the system clipboard, making it available for pasting in other applications.

**Why this priority**: This is the fundamental operation that makes clipboard history useful. Without the ability to copy entries back to the system clipboard, the history serves no practical purpose. This delivers immediate value by enabling users to access and reuse previous clipboard content.

**Independent Test**: Can be fully tested by selecting an entry from history, copying it, then pasting in another application. The test passes when the pasted content matches the original clipboard entry exactly and the system clipboard contains the entry's content.

**Acceptance Scenarios**:

1. **Given** a text clipboard entry exists in history, **When** user triggers copy action, **Then** the full text content is placed on the system clipboard
2. **Given** an image clipboard entry exists in history, **When** user triggers copy action, **Then** the full image content is placed on the system clipboard
3. **Given** a clipboard entry is copied to system clipboard, **When** user switches to another application and pastes, **Then** the pasted content matches the original entry
4. **Given** user copies an entry to system clipboard, **When** the system clipboard is accessed, **Then** the entry's timestamp is updated to reflect the most recent copy time

---

### User Story 2 - Copy and Paste in Single Action (Priority: P1)

Users need to copy an entry from history and immediately paste it into the active application in one seamless action. When they trigger a paste action, the system should copy the entry to the system clipboard and then paste it into the currently focused application.

**Why this priority**: This is a key workflow optimization that saves users a step. Users frequently want to paste content immediately without manually switching applications. This is equal priority with basic copy because both are essential for efficient clipboard management.

**Independent Test**: Can be fully tested by triggering a paste action on an entry while a text editor is focused. The test passes when the content appears in the text editor without the user needing to manually paste.

**Acceptance Scenarios**:

1. **Given** a clipboard entry is selected, **When** user triggers paste action, **Then** the entry is copied to system clipboard and pasted into active application
2. **Given** no application is currently focused, **When** user triggers paste action, **Then** the entry is copied to system clipboard but pasting fails gracefully
3. **Given** the active application does not support pasting, **When** user triggers paste action, **Then** the entry is copied to system clipboard and appropriate error feedback is provided
4. **Given** user triggers paste action multiple times rapidly, **Then** each paste action completes independently without interference

---

### User Story 4 - Delete Clipboard Entries (Priority: P2)

Users need to remove unwanted or sensitive clipboard entries from history. When they delete entries, those entries should be removed from the database and any associated files should be cleaned up.

**Why this priority**: Privacy and data management are important for users who may copy sensitive information. Deletion provides control over what data is retained. This is medium priority because users can benefit from the clipboard manager without deleting entries, but deletion provides essential privacy and storage management.

**Independent Test**: Can be fully tested by selecting entries and deleting them, then verifying they no longer appear in the list and are removed from the database. The test passes when deleted entries are completely removed and cannot be recovered through normal operations.

**Acceptance Scenarios**:

1. **Given** a clipboard entry exists, **When** user deletes the entry, **Then** the entry is removed from the database
2. **Given** an image clipboard entry is deleted, **When** the deletion completes, **Then** the associated image file is removed from the file system
3. **Given** multiple entries are selected and deleted, **When** the deletion completes, **Then** all selected entries are removed from the database

---

### Edge Cases

- What happens when the system clipboard is locked or cannot be written to during a copy operation?
- What happens when the active application does not support pasting during a copy-and-paste action?
- What happens when file system cleanup fails during entry deletion?
- What happens when copy operation is triggered on an entry that no longer exists (concurrent deletion)?
- What happens when paste action is triggered with no active application focused?
- What happens when entry content is too large to fit on the system clipboard?

## Requirements *(mandatory)*

### Functional Requirements

#### Copy Operations
- **FR-001**: System MUST copy the full content of a selected clipboard entry to the system clipboard
- **FR-002**: System MUST handle text entries by placing plain text content on the system clipboard
- **FR-003**: System MUST handle image entries by placing image data on the system clipboard
- **FR-004**: System MUST update the clipboard entry's latest_copy_time_ms timestamp when copied to system clipboard
- **FR-005**: System MUST update the clipboard entry's accessed timestamp when copied to system clipboard
- **FR-006**: System MUST handle copy operation failures gracefully with user-appropriate error messages
- **FR-007**: System MUST verify that content was successfully placed on the system clipboard before reporting success

#### Paste Operations
- **FR-008**: System MUST perform copy-to-clipboard operation followed by paste-to-active-application action in single user action
- **FR-009**: System MUST identify the currently focused application for paste operation
- **FR-010**: System MUST send paste command (Cmd+V on macOS) to the active application
- **FR-011**: System MUST handle case where no application is focused (copy to clipboard only)
- **FR-012**: System MUST handle case where active application does not support pasting (copy to clipboard only with error feedback)
- **FR-013**: System MUST complete paste action within 500 milliseconds of user trigger

#### Delete Operations
- **FR-014**: System MUST remove clipboard entries from the database when deleted by user
- **FR-015**: System MUST remove associated image files from the file system when image entries are deleted
- **FR-016**: System MUST provide confirmation prompt before deleting entries to prevent accidental deletion
- **FR-017**: System MUST support deletion of single clipboard entries
- **FR-018**: System MUST support deletion of multiple selected entries
- **FR-019**: System MUST clean up file system references when entries are deleted
- **FR-020**: System MUST remove entry from all search indexes and caches when deleted
- **FR-021**: System MUST handle deletion failures gracefully (e.g., database locked, file system permission denied)

#### Operation Validation and Error Handling
- **FR-022**: System MUST validate that clipboard entry exists before performing operations
- **FR-023**: System MUST validate that user has permission to perform operation on entry
- **FR-024**: System MUST handle concurrent operations on same entry with appropriate locking
- **FR-025**: System MUST provide meaningful error messages for operation failures
- **FR-026**: System MUST log all operations for audit purposes (excluding content itself)
- **FR-027**: System MUST handle clipboard content size limits enforced by operating system
- **FR-028**: System MUST verify operation results (e.g., verify file was deleted, verify clipboard was updated)

#### Cross-Platform Architecture
- **FR-029**: System MUST implement clipboard operations (copy, paste) in platform-specific layer to interact with OS clipboard APIs
- **FR-030**: System MUST implement delete operation business logic in cross-platform layer for code reuse
- **FR-031**: System MUST provide clear interface between platform-specific and cross-platform layers
- **FR-032**: System MUST use async operations for file system and database operations to avoid blocking UI
- **FR-033**: System MUST implement error propagation from platform-specific layer to UI layer

#### Main Panel Operation Logic
- **FR-034**: System MUST open the main panel when user presses Cmd+Shift+V after app launch
- **FR-035**: System MUST close the main panel when user presses Escape
- **FR-036**: System MUST close the main panel when user clicks outside the panel
- **FR-037**: System MUST render the main panel above other applications' windows when shown
- **FR-038**: System MUST keep other in-app UI above the main panel when shown
- **FR-039**: System MUST focus the search input immediately when the panel is shown
- **FR-040**: System MUST select the first history entry by default when the panel is shown
- **FR-041**: System MUST keep the selected history entry within the visible list viewport
- **FR-042**: System MUST update the history list in real time when entries change
- **FR-043**: System MUST select the next entry after deletion; if no next entry exists, select the previous entry
- **FR-044**: System MUST allow text in the preview area to be selectable
- **FR-045**: System MUST update the preview area immediately when selection changes
- **FR-046**: System MUST show the selected state on active filter buttons after filtering
- **FR-047**: System MUST handle all panel key actions at the panel layer while the panel is shown
- **FR-048**: System MUST keep search input focus during all panel key actions
- **FR-049**: System MUST disable panel key actions when other in-app panels are shown
- **FR-050**: System MUST move selection up/down on arrow key presses, with wrap-around at list ends
- **FR-051**: System MUST copy the selected entry to the clipboard on Cmd+Enter
- **FR-052**: System MUST delete the selected entry on Cmd+D after confirmation dialog shown above the main panel
- **FR-053**: System MUST copy the selected entry to the clipboard, close the panel, and send Cmd+V to the previously active app on Enter
- **FR-054**: System MUST skip sending Cmd+V when the previously active app is this app

### Key Entities

- **ClipboardOperation**: Represents a clipboard operation that can be performed on entries. Attributes: operation type (copy, paste, delete), operation timestamp, target entry ID(s), operation status (success, failed, in_progress), error message (if failed)
- **ClipboardCopyAction**: Represents the action of copying content to the system clipboard. Attributes: source entry ID, content type (text/image), content data, operation timestamp, success flag, error details
- **PasteAction**: Represents the action of pasting content into the active application. Attributes: source entry ID, target application identifier, paste timestamp, success flag, error details

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Users can copy a clipboard entry to the system clipboard in under 200 milliseconds
- **SC-002**: Copy operations succeed for 99% of entries when clipboard is not locked or unavailable
- **SC-003**: Copy-and-paste actions complete successfully (copy + paste) in under 500 milliseconds when target application is ready
- **SC-004**: Deleted entries are completely removed from database and file system in under 500 milliseconds
- **SC-005**: Operation failures result in user-friendly error messages in 100% of cases
- **SC-006**: All clipboard operations are logged for audit purposes (excluding content itself)
- **SC-007**: File system cleanup succeeds for 95% of deleted image entries

## Assumptions

- System clipboard APIs on macOS provide reliable access for copy and paste operations
- Active application can be determined and receive paste commands via system APIs
- SQLite database supports atomic transactions for multiple entry operations
- File system operations (delete for image files) are atomic and reliable
- Clipboard entry content is always valid (text or image data is not corrupted)
- Paste action failure when no application is focused is acceptable (fallback to copy-only)
- Copy operations update timestamp metadata to track access patterns
