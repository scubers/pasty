# Research: Clipboard History (macOS)

**Feature**: [spec.md](./spec.md)  
**Branch**: `001-clipboard-history`  
**Date**: 2026-02-06

This document resolves the key unknowns needed to implement macOS clipboard history capture while respecting the project constitution (privacy, performance, portability, data integrity).

## Decision 1: Clipboard change detection

**Decision**: Detect clipboard changes by polling `NSPasteboard.general.changeCount` on a timer.

**Rationale**:
- macOS does not provide a reliable notification callback for general pasteboard changes; polling `changeCount` is the common approach.
- Checking `changeCount` is cheap; the work happens only when the count changes.

**Alternatives considered**:
- System “notifications” approach: not available for the general pasteboard.
- Background schedulers: energy-efficient but unsuitable for sub-second responsiveness.

**Notes / constraints**:
- Use an adaptive polling interval: faster when active/foregrounded, slower when backgrounded.
- Debounce rapid changes to avoid duplicate processing.

## Decision 2: Reading clipboard content (text + image)

**Decision**: Use pasteboard type detection before reading, then read using class-based reads with a preference order.

**Rationale**:
- The pasteboard often contains multiple representations (plain text, rich text, HTML, TIFF/PNG).
- Class-based reads allow retrieving the best available representation without hardcoding every UTI.

**Alternatives considered**:
- Reading raw data for specific UTIs directly: more control but more edge cases.

**Edge-case handling**:
- Clipboard can contain file/folder references (e.g., Finder Copy) via file URLs; MVP behavior is to ignore these and write a diagnostic log entry.
- Finder “Copy” on an image file may put a file URL on the pasteboard rather than an image payload; treat file-URL-as-image as a future enhancement.

**Supported image formats (MVP)**:
- Accept common image formats when present on the pasteboard: PNG, JPEG/JPG, TIFF, WebP, HEIC/HEIF, GIF, BMP.

## Decision 3: Source application attribution (`source_app_id`)

**Decision**: Use a hybrid attribution strategy:
1) If the pasteboard includes `org.nspasteboard.source`, use it as the bundle id.
2) Else fall back to the frontmost application bundle id at the time of capture (best-effort).
3) If neither is available, store an empty string (unknown source).

**Rationale**:
- macOS does not provide a first-class API to identify the pasteboard writer.
- `org.nspasteboard.source` is a quasi-standard used by some apps; when present it is the most accurate.
- Frontmost-app fallback is common but not fully reliable.

**Alternatives considered**:
- “Always frontmost app”: simplest but more frequently incorrect.
- “No attribution at all”: loses useful debugging/context.

**Known limitations**:
- Race conditions: a user can copy and switch apps before polling observes the change.
- Many apps will not set `org.nspasteboard.source`.

## Decision 4: Privacy filtering (transient + concealed)

**Decision**:
- If pasteboard indicates transient content (e.g., `org.nspasteboard.TransientType`), do not persist it.
- If pasteboard indicates concealed/sensitive content (e.g., `org.nspasteboard.ConcealedType`), default to not persisting it in this MVP.

**Rationale**:
- Clipboard history frequently contains passwords/tokens; default local-only is not sufficient if we persist concealed content indiscriminately.
- Skipping transient reduces noise (many productivity tools emit short-lived clipboard content).

**Alternatives considered**:
- Persist concealed but mask in UI: improves completeness but increases risk; revisit when settings exist.
- Persist transient with a flag: increases noise; not needed for MVP validation.

## Decision 5: Persistence approach (SQLite + asset files)

**Decision**: Store metadata rows in a local SQLite database and store image payloads as files on disk; DB stores only a relative path + width/height + hashes.

**Rationale**:
- Spec explicitly calls for SQLite.
- SQLite transactions provide strong integrity guarantees for metadata.
- Storing images as files avoids bloating the DB and supports efficient deletion.

**Alternatives considered**:
- Single JSON file: simpler but weaker integrity/concurrency; harder to evolve safely.
- Store images as SQLite BLOBs: simpler single-store but larger DB churn and slower deletes/compaction.

**Crash consistency rule**:
- Write image file first (to a temp name), fsync if applicable, then rename atomically.
- Insert/update DB row in a transaction after the asset path is final.

## Decision 6: Dedupe strategy

**Decision**: Exact-content dedupe in Core by content hash per type.

**Rationale**:
- The spec requires dedupe and `last_copy_time_ms` updates.
- Hash-based equality is deterministic and portable.

**Details**:
- Text: normalize line endings (`\r\n` -> `\n`) before hashing.
- Image: hash the persisted bytes (after choosing a normalized on-disk encoding).
- On match: update `last_copy_time_ms`, `update_time_ms`, and refresh `source_app_id` to the most recent observed value.

**Alternatives considered**:
- Time-window dedupe only: can create duplicates across longer intervals.
- Full DB scan for equality: too slow at scale.

## Decision 7: macOS 16+ clipboard privacy prompts (future-proofing)

**Decision**: Treat “pasteboard access prompts” as a known future risk; keep capture logic minimal and prepare to adopt detection-before-reading when available.

**Rationale**:
- New OS behavior may warn users when apps programmatically read the pasteboard without user intent.
- MVP should remain functional on current targets; document the risk and mitigation path.

**Mitigations to plan**:
- Prefer type detection before content reads.
- Consider gating full reads behind explicit user intent (e.g., “Start capturing”) if prompts become disruptive.

## Summary of resolved unknowns

- Clipboard change detection: poll `changeCount`.
- Reading text/image: class-based reads with preference order and type checks.
- `source_app_id`: `org.nspasteboard.source` if present, else frontmost app, else empty.
- Privacy filtering: skip transient; default-skip concealed.
- Storage: SQLite (metadata) + files (images).
- Dedupe: exact hash-based.
