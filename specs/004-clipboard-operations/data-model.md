# Data Model: Clipboard Operation Logic

**Date**: 2026-02-06
**Scope**: Copy, paste, delete operations and panel-triggered actions. Reuse existing models where possible.

## Existing Models (Reference Only)

- `core/src/models/clipboard_entry.rs` — Core `ClipboardEntry` (id, content_hash, content_type, timestamp, latest_copy_time_ms, content, source)
- `macos/PastyApp/Sources/Models/ClipboardEntry.swift` — Swift `ClipboardEntry` mirror for UI
- `macos/PastyApp/Sources/Models/ClipboardEntryListItem.swift` — UI list model with derived fields

## Operation Entities (Feature 004)

### ClipboardOperation
Represents a user-triggered clipboard operation on an entry.

**Fields**:
- `operation_id`: string (UUID)
- `operation_type`: enum (`copy`, `paste`, `delete`)
- `entry_ids`: string[] (one or many)
- `timestamp`: datetime
- `status`: enum (`success`, `failed`, `in_progress`)
- `error_message`: string? (present when failed)

**Relationships**:
- `ClipboardOperation` references one or more existing `ClipboardEntry` records by id.

### ClipboardCopyAction
Represents a copy-to-clipboard action for a single entry.

**Fields**:
- `entry_id`: string
- `content_type`: enum (`text`, `image`)
- `timestamp`: datetime
- `success`: boolean
- `error_message`: string?

### PasteAction
Represents a copy+paste action into the active application.

**Fields**:
- `entry_id`: string
- `target_application_id`: string? (bundle id when known)
- `timestamp`: datetime
- `success`: boolean
- `error_message`: string?

## Validation Rules

- `entry_ids` must refer to existing clipboard entries.
- `copy` and `paste` actions require an entry with valid content data.
- `delete` actions must remove the entry from storage and associated image files.

## State Transitions

- `ClipboardOperation.status`: `in_progress` → `success` or `failed`
