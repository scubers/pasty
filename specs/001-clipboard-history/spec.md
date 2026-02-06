# Feature Specification: Clipboard History Source Management (macOS)

**Feature Branch**: `001-clipboard-history`  
**Created**: 2026-02-06  
**Status**: Draft  
**Input**: Capture macOS clipboard changes, dedupe repeated copies, persist locally (including image files), and provide a demo UI to list/refresh/delete history items.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Automatically capture copy history (Priority: P1)

When I copy text or an image in macOS, the app automatically records it as a history item so I can later review what I copied.

**Why this priority**: Without reliable capture, there is no clipboard history to manage or validate.

**Independent Test**: Launch the app, copy new text and an image, and confirm both appear as history items after app restart.

**Acceptance Scenarios**:

1. **Given** the app is running, **When** I copy a new text snippet, **Then** a new history item is recorded with type `text` and the copied content.
2. **Given** the app is running, **When** I copy an image, **Then** a new history item is recorded with type `image` and image metadata (path, width, height).

---

### User Story 2 - Prevent duplicates by updating recency (Priority: P2)

When I copy the same content again, the app does not create a duplicate record; it updates the existing item’s “last copied” time so the list reflects what I used most recently.

**Why this priority**: Dedupe keeps history readable and is a core behavior for “source management” verification.

**Independent Test**: Copy the same text twice and verify item count does not increase while “last copied” changes.

**Acceptance Scenarios**:

1. **Given** a text item already exists in history, **When** I copy the exact same text again, **Then** no new item is created and the existing item’s `last_copy_time_ms` is updated.
2. **Given** an image item already exists in history, **When** I copy the exact same image again, **Then** no new item is created and the existing item’s `last_copy_time_ms` is updated.

---

### User Story 3 - Review and delete items in a demo UI (Priority: P3)

I can open a simple UI that lists recent clipboard history items (including their fields), refresh the list, and delete an item; deleting an image item also removes its stored file.

**Why this priority**: This is the fastest way to validate correctness end-to-end without needing developer tooling.

**Independent Test**: Use only the app UI to refresh, confirm displayed fields, and delete both a text item and an image item.

**Acceptance Scenarios**:

1. **Given** history contains items, **When** I open the demo UI, **Then** I can see a list of recent items including all required fields.
2. **Given** history contains items, **When** I press the refresh button, **Then** the list updates to reflect the latest stored history.
3. **Given** a history item exists, **When** I press delete for that item, **Then** the item is removed from the list and cannot be retrieved as part of history.
4. **Given** an image history item exists, **When** I delete that item, **Then** the referenced stored image file is also removed.

---

### Edge Cases

- Rapid consecutive clipboard changes (multiple copies within a second)
- Very large text or large images (ensure app remains responsive and does not corrupt stored history)
- Clipboard contains unsupported types (non-text, non-image): ignore or record as `unknown` without crashing (MVP default: ignore)
- Clipboard contains file or folder references (e.g., copied in Finder): ignore and write a diagnostic log entry
- Source app identifier is unavailable: item is still recorded with `source_app_id` empty/unknown
- Deleting an image item when the referenced file is already missing: deletion still succeeds and does not crash
- History reaches the retention limit: oldest items are removed to make room for new copies

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST detect clipboard content changes while the macOS app is running.
- **FR-002**: When clipboard content changes to supported types, system MUST create or update a persisted history item.
- **FR-003**: System MUST support at least two clipboard content types: `text` and `image`.
- **FR-004**: Each history item MUST have a stable unique identifier.
- **FR-005**: Each history item MUST store timestamps in milliseconds for creation, last update, and last copy time.
- **FR-006**: Each history item MUST store the identifier of the source application when available.

- **FR-007**: For `text` items, history MUST store the copied text content.
- **FR-008**: For `image` items, history MUST store a relative file path to the stored image and the image width/height.
- **FR-008a**: System MUST support capturing images in common formats including PNG, JPEG/JPG, TIFF, WebP, HEIC/HEIF, GIF, and BMP.

- **FR-009**: System MUST implement deduplication: when the newly copied clipboard content matches an existing history item, system MUST NOT create a new item and MUST update `last_copy_time_ms` (and `update_time_ms`).
- **FR-010**: When a duplicate copy occurs and the source application can be determined, system MUST update the existing item’s `source_app_id` to the most recent source.

- **FR-011**: System MUST provide a query to list recent history items in descending order of `last_copy_time_ms`.
- **FR-012**: System MUST provide a delete operation for a single history item by id.
- **FR-013**: Deleting a history item MUST remove it from persistent storage.
- **FR-014**: If the deleted history item references a stored file (e.g., an image), the system MUST delete that file as part of the delete operation.

- **FR-015**: System MUST provide a demo UI that lists recent history items and displays all stored fields for each item.
- **FR-016**: The demo UI MUST provide a manual refresh action to reload items from persistent storage.
- **FR-017**: The demo UI MUST provide a delete action per item, and deletion MUST be reflected after refresh.

- **FR-018**: System MUST store clipboard history locally on the user’s device and MUST NOT transmit clipboard history to a remote service within this feature scope.

- **FR-018a**: If clipboard content is a file or folder reference, system MUST ignore it (no history item created) and MUST write a diagnostic log entry.

- **FR-019**: System MUST bound history growth by retaining at least the most recent 1000 items (by `last_copy_time_ms`) and removing older items beyond this limit.
- **FR-020**: The demo UI MUST display at least the 200 most recent history items (or all items if fewer exist).

### Acceptance Criteria Mapping

- FR-001 to FR-008 are accepted when User Story 1 acceptance scenarios pass.
- FR-009 to FR-010 are accepted when User Story 2 acceptance scenarios pass and SC-002 is met.
- FR-011 to FR-017 and FR-020 are accepted when User Story 3 acceptance scenarios pass.
- FR-014 is additionally accepted when SC-003 is met.
- FR-018 is accepted when no clipboard history is transmitted to any remote service during normal use of this feature.
- FR-019 is accepted when copying more than the retention limit results in older items being removed while the most recent items remain available.

### Key Entities *(include if feature involves data)*

- **Clipboard History Item**: A single recorded clipboard copy event (deduped by content); key attributes: `id`, `type`, `content` (text), `image_path` (relative), `image_width`, `image_height`, `create_time_ms`, `update_time_ms`, `last_copy_time_ms`, `source_app_id`.
- **Source Application**: The application that placed the content onto the clipboard; key attributes: `source_app_id` and (optional) human-readable name for display.
- **Stored Asset File**: A locally stored file referenced by a history item (initially images); key attributes: `relative_path`, lifecycle tied to the owning history item.

## Assumptions

- Clipboard history is captured only while the app is running (no background daemon outside the app scope).
- “Matches an existing item” means the copied content is equivalent for the user in typical validation (copying the same text string or the same image again).
- Only `text` and `image` are in scope for MVP; other clipboard types are ignored.
- File/folder references copied to the clipboard are treated as unsupported types and ignored in this MVP.
- No cross-device sync, sharing, or cloud backup is included in this feature.

## Dependencies

- The app can read the current clipboard content while running.
- The app can write local files for stored images and can delete those files when requested.
- Source application attribution may be unavailable for some clipboard events; the feature remains functional without it.

## Out of Scope

- Search, filtering, pinning/favoriting, tagging, or editing history items
- Cross-device sync or cloud backup
- Capturing clipboard history while the app is not running
- Persisting file/folder clipboard content as history items

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: In a manual test session, at least 95% of copy actions (text or image) appear in the history list within 1 second after the copy.
- **SC-002**: Copying the same text 10 times results in exactly 1 stored history item for that text, with `last_copy_time_ms` updated each time.
- **SC-003**: Deleting an image history item removes it from the UI list after refresh and ensures the referenced stored file is no longer present on disk.
- **SC-004**: Users can verify the feature end-to-end (capture, list, refresh, delete, dedupe) using only the demo UI without external tools.
- **SC-005**: During normal use of this feature, there is no outbound network activity related to clipboard history.
