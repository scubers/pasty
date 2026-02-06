# Data Model: Clipboard History

**Feature**: [spec.md](./spec.md)  
**Research**: [research.md](./research.md)  
**Date**: 2026-02-06

This document describes the portable Core data model and invariants for clipboard history capture, deduplication, retention, and deletion.

## Entity: ClipboardHistoryItem

Represents one deduplicated clipboard content item.

**Fields**

- `id` (string): UUID.
- `type` (enum): `text` | `image`.
- `content` (string, optional): Present when `type=text`.
- `image_path` (string, optional): Relative path to stored image asset when `type=image`.
- `image_width` (int, optional): Pixels when `type=image`.
- `image_height` (int, optional): Pixels when `type=image`.
- `image_format` (string, optional): Original or stored image format hint (e.g., png, jpeg, tiff, webp, heic, gif, bmp).
- `create_time_ms` (int64): First time this item was created.
- `update_time_ms` (int64): Last time this item’s stored record changed.
- `last_copy_time_ms` (int64): Last time this content was copied (used for recency ordering).
- `source_app_id` (string): Best-effort bundle id; empty means unknown.

**Derived/implementation-facing fields (Core-owned policy, may be stored)**

- `content_hash` (string): Stable hash used for dedupe.
- `content_size_bytes` (int64): For retention policy by bytes.
- `flags` (set): `is_transient`, `is_concealed`.

## Entity: StoredAssetBlob (images)

Represents a stored on-disk asset referenced by one or more history items.

**Fields**

- `blob_key` (string): Content-addressed key (derived from bytes hash).
- `relative_path` (string): Where the blob is stored (relative to the feature’s base storage directory).
- `file_ext` (string): File extension used for the stored blob (e.g., png, jpg, tiff, webp, heic).
- `mime_or_uti` (string, optional): Best-effort content type hint.
- `byte_len` (int64): Size on disk.
- `ref_count` (int): Number of referencing items (optional if not shared in MVP).

## Relationships

- `ClipboardHistoryItem (image)` references exactly one `StoredAssetBlob` via `image_path` (and optionally `blob_key`).
- `ClipboardHistoryItem (text)` has no blob reference.

## Invariants & Validation Rules

- `id` is unique and immutable.
- `create_time_ms <= update_time_ms` and `create_time_ms <= last_copy_time_ms`.
- `last_copy_time_ms` is updated on dedupe hits; ordering uses descending `last_copy_time_ms`.
- If `type=text`: `content` is non-empty; image fields are absent.
- If `type=image`: `image_path` is non-empty; `image_width` and `image_height` are > 0; `content` is absent.
- `source_app_id` may be empty (unknown) but must be stable text when present.

## Dedupe Key

- Text items dedupe by `(type=text, content_hash)` where `content_hash` is computed from normalized text (line ending normalization).
- Image items dedupe by `(type=image, content_hash)` where `content_hash` is computed from the persisted bytes.

## Retention Policy

- Maintain a maximum of 1000 items (ordered by `last_copy_time_ms`).
- When exceeding the limit, delete oldest items first.
- Deletion of an image item triggers deletion of its blob file if no other items reference it.

## State Transitions

1) **New capture**
- Create new `ClipboardHistoryItem` and (if image) create associated `StoredAssetBlob`.

2) **Dedupe hit**
- Update existing item: `last_copy_time_ms`, `update_time_ms`, and update `source_app_id` to the most recent known source.

3) **Delete item**
- Remove item record.
- If image: remove blob file if unreferenced.
