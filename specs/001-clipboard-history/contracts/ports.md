# Contracts: Core Ports & Local Interfaces

**Feature**: [spec.md](../spec.md)  
**Research**: [research.md](../research.md)  
**Date**: 2026-02-06

This feature is a pure local application. The “contracts” in this folder define stable internal boundaries between:

- macOS shell (event source + UI)
- portable C++ Core (policy, dedupe, retention)
- local persistence (SQLite + asset files)

They are not network APIs.

## Contract: Clipboard Event Ingestion

**Purpose**: macOS shell reports a new pasteboard change to Core.

**ClipboardEvent**

- `timestamp_ms` (int64)
- `source_app_id` (string; empty if unknown)
- `payload`
  - `type`: `text` | `image`
  - `text` (string; required if type=text)
  - `image` (required if type=image)
    - `byte_len` (int64)
    - `width` (int)
    - `height` (int)
    - `format_hint` (string; optional: png/jpg/jpeg/tiff/webp/heic/heif/gif/bmp)
- `flags`
  - `is_transient` (bool)
  - `is_concealed` (bool)
  - `is_file_or_folder_reference` (bool)

**Rules**

- If `is_file_or_folder_reference=true`: Core MUST ignore the event and emit a diagnostic log entry.
- If `is_transient=true`: Core MUST ignore the event.
- If `is_concealed=true`: Core MUST ignore the event by default in MVP (privacy-first).

## Contract: History Query

**Purpose**: UI requests a page of recent history items.

**ListHistoryRequest**

- `limit` (int; default 200; max 1000)
- `cursor` (string; optional)

**ListHistoryResponse**

- `items`: array of `ClipboardHistoryItem`
- `next_cursor` (string; optional)

**Ordering**

- Descending by `last_copy_time_ms`.

## Contract: Delete Item

**Purpose**: UI requests deletion of a single item.

**DeleteHistoryItemRequest**

- `id` (string UUID)

**Semantics**

- On delete success, item is removed from persistent storage.
- If the item references a stored file (image asset), the file is deleted as part of the delete operation.
- If the referenced file is missing, deletion still succeeds.

## Contract: Local Storage (persistence boundary)

**Purpose**: Core persists metadata and assets using an implementation behind a stable interface.

**Operations (conceptual)**

- `UpsertTextItem(dedupe_key, content, timestamps, source_app_id) -> item_id`
- `UpsertImageItem(dedupe_key, image_path, width, height, format, timestamps, source_app_id) -> item_id`
- `ListItems(limit, cursor) -> items, next_cursor`
- `DeleteItem(id) -> ok`
- `EnforceRetention(max_items=1000)`

**Crash-consistency constraints**

- Image asset write uses temp+rename semantics.
- Metadata write uses atomic DB transactions.
