# Cloud Drive Sync Protocol (v1)

**Schema Version**: `1`

This protocol defines the on-disk format for cross-device clipboard synchronization via a shared cloud directory. It is designed to be:

- **Portable**: No provider-specific assumptions (works with iCloud, Dropbox, OneDrive, or any file sync)
- **Conflict-free**: Per-device log streams avoid write conflicts
- **Idempotent**: Event-based semantics with stable merge ordering
- **Resilient**: Graceful handling of corruption, oversize events, and temporary network failures

---

## 1. Directory Structure

```
<sync_root>/
├── meta/
│   └── protocol-info.json       # Schema version metadata (optional but recommended)
├── logs/
│   ├── <device_id_A>/
│   │   ├── events-0001.jsonl    # Current log file (or oldest if rotated)
│   │   ├── events-0002.jsonl    # Rotated files (incremental naming)
│   │   └── ...
│   ├── <device_id_B>/
│   │   └── events-0001.jsonl
│   └── ...
└── assets/
    ├── <content_hash>.png        # Images referenced by events
    ├── <content_hash>.jpeg
    └── ...
```

### Directory Rules

- `meta/`: Metadata files for protocol evolution
- `logs/<device_id>/`: Event streams, one directory per device
- `assets/`: Binary assets (images only for v1), named by content hash

### Device ID Format

- Type: `string` (ASCII lowercase hex, recommended: 16-byte UUID v4 as hex without dashes)
- Example: `"550e84040e2941b5410143358c0991e8"`
- Stability: Generated once per device installation, persisted in local state (not in sync root)
- Uniqueness: Must be globally unique across all devices sharing the sync directory
- Directory mapping: The `device_id` field in events must match the directory name in `logs/<device_id>/`

---

## 2. Log File Naming and Rotation

### File Naming Pattern

- Pattern: `events-<sequence>.jsonl`
- `<sequence>`: 4-digit zero-padded integer, starting at `0001`
- Increment: Sequential (0001, 0002, 0003, ...) for each rotation
- Sorting: String sort equals chronological order (lexicographic works due to zero-padding)

### Rotation Trigger

- **Size limit**: 10 MiB (10,485,760 bytes) per file
- **Behavior**: Before writing a line, if `current_file_size + line_length` would exceed 10 MiB, close current file and create next sequence file
- **Atomicity**: Write operations are single-line append + `fflush()` (no cross-file transaction needed)
- **Implementation**: Measure line length before writing to avoid race conditions with concurrent writes from other devices

### Rotation Example

```
logs/device-A/
├── events-0001.jsonl    # 10 MiB, closed
├── events-0002.jsonl    # 3 MiB, current (being written to)
└── events-0003.jsonl    # (does not exist yet)
```

---

## 3. JSONL Line Schema

Each line in a log file is a JSON object with the following schema.

### Schema Version Field

**Required**: `{"schema_version": 1}`

- Type: `integer`
- Value: Must be `1` for this protocol version
- Behavior: Unknown versions should be skipped with error log; v1 parser must handle `1` only

### Event ID (Unique Identifier)

**Field**: `event_id`

- Type: `string`
- Format: `<device_id>:<seq>`
- Example: `"550e84040e2941b5410143358c0991e8:42"`
- Components:
  - `<device_id>`: Device that generated the event (MUST match the `device_id` field and the `logs/<device_id>/` directory name)
  - `<seq>`: Per-device monotonically increasing sequence number (64-bit unsigned integer, base-10)
- Uniqueness: Globally unique across all devices and time
- Purpose: Idempotent replay detection, merge tie-breaking
- Consistency requirement: The `<device_id>` prefix in `event_id` MUST equal the `device_id` field

### Sequence Number

**Field**: `seq`

- Type: `integer` (64-bit unsigned, represented as JSON number)
- Range: `1` to `2^64 - 1`
- Monotonicity: Strictly increasing per-device across all files
- Persisted: Next sequence number stored in local state (not in sync root)

### Timestamp

**Field**: `ts_ms`

- Type: `integer` (64-bit signed, milliseconds since Unix epoch)
- Range: Valid Unix timestamp (positive)
- Purpose: Event ordering, retention calculation
- Note: Clock skew across devices is expected; tie-breaker ensures deterministic merge

### Operation Type

**Field**: `op`

- Type: `string`
- Values:
  - `"upsert_text"`: Insert/update text content
  - `"upsert_image"`: Insert/update image content (reference to asset)
  - `"delete"`: Delete content (tombstone)
- Forward compatibility: Unknown `op` values must be skipped with error log

### Content Hash

**Field**: `content_hash`

- Type: `string` (hexadecimal, lowercase, exactly 16 characters)
- Algorithm: 64-bit FNV-1a hash of content bytes (same algorithm/normalization/encoding as Core's existing `content_hash` semantics)
  - For text: CRLF normalized to LF before hashing
  - For images: Raw bytes hashed directly
  - Output: Fixed-width 16-character lowercase hex string
- Format constraint: Must match regex `[0-9a-f]{16}`
- Purpose: Deduplication, tombstone target, asset naming
- Uniqueness: Identifies content across devices (sufficient probability-based uniqueness for clipboard use case)
- Validation: Implementations should validate that `content_hash` is a valid 16-character lowercase hex string

### Item Type

**Field**: `item_type`

- Type: `string`
- Values: `"text"` or `"image"`
- Purpose: Tombstone target (combined with `content_hash`)

### Content Fields (Operation-Specific)

#### For `op = "upsert_text"`:

- `text`: `string` (UTF-8) - The text content
- `content_type`: `string` (optional) - MIME type (e.g., `"text/plain"`)
- `size_bytes`: `integer` (optional) - Length in bytes

#### For `op = "upsert_image"`:

- `asset_key`: `string` (required) - Filename in `assets/` directory (e.g., `"a1b2c3d4...png"`)
- `width`: `integer` (optional) - Image width in pixels
- `height`: `integer` (optional) - Image height in pixels
- `content_type`: `string` (optional) - MIME type (e.g., `"image/png"`)
- `size_bytes`: `integer` (optional) - File size in bytes

#### For `op = "delete"`:

- No additional content fields (tombstone targets `item_type` + `content_hash`)

### Optional Metadata Fields (All Operations)

- `source_app_id`: `string` (optional) - Application that generated the event
- `is_concealed`: `boolean` (optional) - Sensitive content (default: `false`)
- `is_transient`: `boolean` (optional) - Temporary content (default: `false`)
- `encryption`: `string` (optional) - Encryption mode: `"none"` (v1 default), `"e2ee"` (future)
- `note`: `string` (optional) - User-provided note/comment

### Forward Compatibility

**Rule**: Unknown fields must be ignored by readers.

**Behavior**:
- Parse: Accept any additional fields not defined in this schema (do not reject)
- Unknown `op` values: Skip entire line with error log (forward compatibility)
- Note: v1 does not rewrite events, so "preserving" unknown fields is not applicable; readers simply ignore them

---

## 4. Full JSONL Examples

### Example 1: Upsert Text Event

```json
{
  "schema_version": 1,
  "event_id": "550e84040e2941b54141a41e541f7543:1",
  "device_id": "550e84040e2941b54141a41e541f7543",
  "seq": 1,
  "ts_ms": 1739414400000,
  "op": "upsert_text",
  "item_type": "text",
  "content_hash": "d73e413808d85447",
  "text": "Hello, world!",
  "content_type": "text/plain",
  "size_bytes": 13,
  "source_app_id": "com.apple.TextEdit",
  "is_concealed": false,
  "is_transient": false,
  "encryption": "none"
}
```

**Consistency check**:
- `event_id` prefix `"550e84040e2941b54141a41e541f7543"` equals `device_id` field
- `content_hash` is valid 16-character lowercase hex (64-bit FNV-1a)
- This event would be stored in `logs/550e84040e2941b54141a41e541f7543/events-0001.jsonl`

### Example 2: Upsert Image Event

```json
{
  "schema_version": 1,
  "event_id": "550e84040e2941b54141a41e541f7543:2",
  "device_id": "550e84040e2941b54141a41e541f7543",
  "seq": 2,
  "ts_ms": 1739414460000,
  "op": "upsert_image",
  "item_type": "image",
  "content_hash": "a1b2c3d4e5f67890",
  "asset_key": "a1b2c3d4e5f67890.png",
  "width": 1920,
  "height": 1080,
  "content_type": "image/png",
  "size_bytes": 245678,
  "source_app_id": "com.apple.Preview",
  "is_concealed": false,
  "is_transient": false,
  "encryption": "none"
}
```

**Consistency check**:
- `event_id` prefix `"550e84040e2941b54141a41e541f7543"` equals `device_id` field
- `content_hash` is valid 16-character lowercase hex (64-bit FNV-1a)
- `asset_key` follows `<content_hash>.<ext>` format: same hash + `.png`
- Asset file would be stored at `assets/a1b2c3d4e5f67890.png`

### Example 3: Delete (Tombstone) Event

```json
{
  "schema_version": 1,
  "event_id": "880e85040e2941b5410143358c0991e8:15",
  "device_id": "880e85040e2941b5410143358c0991e8",
  "seq": 15,
  "ts_ms": 1739415000000,
  "op": "delete",
  "item_type": "text",
  "content_hash": "d73e413808d85447"
}
```

**Consistency check**:
- `event_id` prefix `"880e85040e2941b5410143358c0991e8"` equals `device_id` field
- `content_hash` is valid 16-character lowercase hex (64-bit FNV-1a)
- This tombstone targets `(item_type="text", content_hash)` for deletion
- `content_hash` matches Example 1's hash (deletes that text content)

---

## 5. Deterministic Merge Ordering

When multiple devices produce events with similar timestamps, the merge order must be deterministic.

### Primary Ordering Field

- **Primary**: `ts_ms` (timestamp in milliseconds)

### Tie-Breaker (When `ts_ms` Is Equal)

When timestamps are identical (clock skew or rapid local operations), use:

**Order**: `(ts_ms, device_id, seq)`

- All fields are compared in ascending order
- `device_id` is compared as string (lexicographic)
- `seq` is compared as integer (numeric)

### Deterministic Merge Algorithm

1. Collect all events from all devices (parsed JSONL lines)
2. Filter out events with `schema_version` != `1` or unknown `op`
3. Sort by: `ts_ms` ASC, then `device_id` ASC, then `seq` ASC
4. Apply events in sorted order (upserts then deletes, tombstones override)

### Example: Clock Skew Resolution

Device A (clock fast, ts=1000): `event_id = "A:1"` (upsert text)
Device B (clock slow, ts=999): `event_id = "B:1"` (upsert same text)

Merge order:
1. `"B:1"` (ts=999) - Applied first
2. `"A:1"` (ts=1000) - Applied second (wins, same content)

If timestamps equal:
```
Device A (ts=1000, seq=1): "A:1"
Device B (ts=1000, seq=1): "B:1"
```

Merge order: `"A:1"` before `"B:1"` (device_id "A" < "B")

---

## 6. Tombstone Semantics

### Purpose

Tombstones prevent deletion resurrection across devices. Without tombstones, an old event from a slow device could re-insert deleted content.

### Tombstone Target

A tombstone references content by:

- `item_type`: `"text"` or `"image"`
- `content_hash`: 64-bit FNV-1a hash of content (same algorithm/normalization/encoding as Core's existing `content_hash` semantics)

This tuple uniquely identifies content across all devices.

### Delete Behavior

When processing a `delete` event:

1. Look up local history items matching `(item_type, content_hash)`
2. Delete all matching items from local history
3. Record the tombstone locally (to prevent re-import from older events)

### Retention Requirement

**Rule**: Tombstones must be retained for at least the retention window (default: 180 days).

**Rationale**: If an old event (older than tombstone) arrives via delayed sync or offline cache, it must be rejected based on the tombstone.

### Tombstone Persistence

Tombstones are persisted in the log stream as `delete` events. They are kept until retention pruning removes them.

### Example: Resurrection Prevention

1. Device A: upsert text "hello" (hash=H1) at t=1000
2. Device B: receives "hello" at t=1010
3. Device A: delete text "hello" (tombstone, hash=H1) at t=1020
4. Device B: receives tombstone at t=1030, deletes local "hello"
5. Device C: offline, syncs A's old event from t=1000
6. Device C sees tombstone (t=1020, H1), skips re-insertion of "hello"

---

## 7. Caps and Limits

### Maximum Image Size

**Cap**: `max_image_bytes = 25 MiB` (26,214,400 bytes)

**Behavior on oversize**:
- Skip writing the event to log
- Skip writing the asset file
- Record an error in error log with: `{device_id, seq, content_hash, reason: "image_too_large"}`
- Do not crash; continue processing next event

**Configuration**: Can be overridden in Core settings (default: 25 MiB)

### Maximum Event Line Size

**Cap**: `max_event_line_bytes = 1 MiB` (1,048,576 bytes)

**Behavior on oversize**:
- Skip writing the entire line to log
- Record an error: `{device_id, seq, reason: "event_line_too_large"}`
- Do not truncate or split; atomic skip

**Measurement**: Measure length of UTF-8 JSON string before writing (excluding newline)

### Maximum Text Content Size

**Cap**: `max_text_bytes = 1 MiB` (same as event line cap, adjusted for JSON overhead)

**Behavior**: Same as image oversize (skip + error log)

### Asset File Naming

**Format**: `<content_hash>.<extension>`

- `<content_hash>`: 64-bit FNV-1a hash (exactly 16 hex characters, lowercase) - MUST match event's `content_hash` field
- `<extension>`: Based on content type: `"png"`, `"jpeg"`, `"gif"`, etc.
- Example: `"a1b2c3d4e5f67890.png"` where `a1b2c3d4e5f67890` is full 16-character hash
- Consistency requirement: The hash prefix in `asset_key` MUST equal the event's `content_hash` field

---

## 8. Corruption Handling

### Malformed JSON Lines

**Detection**: JSON parsing fails (invalid syntax, incomplete JSON object)

**Behavior**:
1. Log error with: `{file_path, line_offset, reason: "invalid_json"}`
2. Increment error counter for that file
3. Skip the line (do not process, do not crash)
4. Continue parsing next line

### Truncated Lines

**Detection**: Last line of file does not end with newline and JSON is incomplete

**Behavior**:
1. Log error with: `{file_path, line_offset, reason: "truncated_line"}`
2. Skip the line
3. Store the byte offset as `last_valid_offset` in state (resumable after cloud sync completes)

### Missing Required Fields

**Detection**: Parsed JSON but missing required field (e.g., no `event_id`)

**Behavior**:
1. Log error with: `{file_path, line_offset, event_id_or_seq, reason: "missing_required_field"}`
2. Skip the event
3. Continue parsing

### Schema Version Mismatch

**Detection**: `schema_version` field exists but value != `1`

**Behavior**:
1. Log error with: `{file_path, line_offset, schema_version, reason: "unsupported_schema_version"}`
2. Skip the event
3. Continue parsing

### Unknown Operation Type

**Detection**: `op` field has value not in `{"upsert_text", "upsert_image", "delete"}`

**Behavior**:
1. Log error with: `{file_path, line_offset, event_id, op, reason: "unknown_operation"}`
2. Skip the event (forward compatibility)
3. Continue parsing

### Error Recovery State

Each device maintains a state file with:

```json
{
  "device_id": "<device_id>",
  "next_seq": 1234,
  "files": {
    "logs/remote-device/events-0001.jsonl": {
      "last_offset": 1048576,
      "error_count": 3,
      "last_sync_ts_ms": 1739415000000
    }
  },
  "tombstones": [
    {"item_type": "text", "content_hash": "...", "ts_ms": 1739415000000}
  ]
}
```

**Resumption**: On next sync, resume from `last_offset` for each file.

---

## 9. Encryption (Placeholder)

### v1 Behavior

**Mode**: Always `"none"` (plaintext)

**Field**: `encryption` is present but fixed to `"none"` for v1.

### Future Extensions (Reserved)

Planned fields (reserved but unused in v1):

- `encryption`: `"e2ee"` (end-to-end encryption)
- `key_id`: `string` - Encryption key identifier
- `nonce`: `string` - Nonce for AEAD encryption
- `ciphertext`: `string` - Encrypted content (for `upsert_text`)

**v1 Rule**: These fields must be ignored if present (forward compatibility).

---

## 10. File System Assumptions

### Platform-Independent Constraints

**Supported**:
- UTF-8 filenames (`assets/<hash>.png`)
- Files up to 2^31-1 bytes (most filesystems)
- Directory creation with atomic `mkdir`
- Atomic file rename (temp file + rename)

**Not Assumed**:
- File mtime reliability (use `ts_ms` field instead)
- Case-sensitive filenames (use lowercase hex for hashes)
- Symlink/hardlink semantics (no symlinks used)
- POSIX permissions (rely on provider sync)

### Atomic Write Pattern

For both log files and asset files:

1. Write to temporary file: `<target>.tmp`
2. Flush and sync to disk
3. Rename: `rename(<target>.tmp, <target>)` (atomic on POSIX and modern Windows)

### Conflict Copy Handling

Some cloud providers create "conflicted copy" files when merge conflicts occur.

**Detection**: Filename contains `"conflict"`, `"copy"`, or timestamp suffix

**Behavior**:
1. Treat as additional log file (read and parse)
2. Parse events normally (event_id deduplication prevents duplicate processing)
3. Do not write to conflicted files (only write to clean `events-NNNN.jsonl`)

---

## 11. Retention and Pruning

### Retention Policy

**Default**: 180 days AND 5000 events per device

**Pruning Action**:

1. Remove events older than retention window
2. Keep tombstones within window (prevent resurrection)
3. After pruning, remove orphaned assets (unreferenced by any event)

### Asset Pruning Safety

**Rule**: Never delete assets referenced by any event (even tombstones).

**Algorithm**:
1. Collect all `asset_key` references from all events
2. List all files in `assets/` directory
3. Delete unreferenced assets (safe, no active references)

### Tombstone Retention

**Minimum**: Same as event retention window (180 days default)

**Rationale**: Older tombstones are irrelevant if all corresponding events are also pruned.

---

## 12. Protocol Versioning

### Version Negotiation

Reader behavior:

```python
if schema_version not in supported_versions:
    skip_event(log_error("unsupported version"))
```

Writer behavior:

- Always write `schema_version = 1` (v1)
- Never write events with unknown `op` values

### Backward Compatibility

**v1 Requirements**:
- Must read and parse v1 events only
- Must ignore unknown fields
- Must reject events with `schema_version != 1`

### Forward Compatibility

**v1 Requirements**:
- Must ignore unknown fields when reading (do not reject)
- Must skip unknown `op` values with error log
- Must handle missing optional fields (use defaults)
- Note: v1 does not rewrite events, so field stripping is not a concern

---

## 13. Summary of Required Fields

### All Events (Required)

- `schema_version`: `integer` (=1)
- `event_id`: `string`
- `device_id`: `string`
- `seq`: `integer`
- `ts_ms`: `integer`
- `op`: `string`
- `item_type`: `string`
- `content_hash`: `string`

### Upsert Text (Additional Required)

- `text`: `string`

### Upsert Image (Additional Required)

- `asset_key`: `string`

### Delete (No Additional Required Fields)

### Optional Fields (All Operations)

- `content_type`: `string`
- `size_bytes`: `integer`
- `width`: `integer` (image only)
- `height`: `integer` (image only)
- `source_app_id`: `string`
- `is_concealed`: `boolean`
- `is_transient`: `boolean`
- `encryption`: `string`
- `note`: `string`
- (and any unknown future fields)

---

## 14. Implementation Notes

### State File Location

- **Path**: Local to each device, NOT in sync directory
- **Recommended**: `<baseDirectory>/sync_state.json`
- **Format**: JSON (same forward compatibility rules as events)

### Polling Strategy

- **Target**: 5–15 seconds between scans
- **Implementation**: CoreRuntime tick or platform timer
- **Optimization**: Track `last_offset` per file to avoid full re-scans

### Error Reporting

All errors should be:

- Logged (with timestamp and context)
- Counted (per file, per session)
- Exposed to UI (recent error, error count)

### Testing Requirements

For v1 compliance, implementations must test:

1. **Parsing**: Valid events parse, invalid events skip
2. **Unknown fields**: Preserved and ignored
3. **Merge**: Deterministic ordering with tie-breaker
4. **Tombstones**: Prevent resurrection
5. **Rotation**: Seamless read across rotated files
6. **Corruption**: Skip malformed lines, resume later
7. **Oversize**: Skip and log, do not crash
8. **Idempotency**: Re-processing same event_id is no-op

---

**End of Protocol v1 Specification**
