# Cloud Sync Origin Tracking Design

**Version**: `1`
**Status**: Draft
**Depends on**: `core/docs/cloud-drive-sync-protocol.md`

This document defines how clipboard items track their origin (local vs. cloud-synced), the rules for export/import precedence, and UI fallback behavior when app identity is unknown.

---

## 1. Problem Statement

When cloud sync is enabled, clipboard history can contain:
1. **Locally captured items** — copied on this device
2. **Cloud-synced items** — imported from another device

Without origin tracking:
- Re-exporting synced items creates sync loops or duplicate events
- The source app attribution may be overwritten incorrectly
- Users cannot distinguish which device an item originated from

---

## 2. Database Schema Changes

### 2.1 New Fields

Add two fields to `ClipboardHistoryItem` (or equivalent storage model):

| Field | Type | Nullable | Default | Description |
|-------|------|----------|---------|-------------|
| `origin_type` | `enum` | No | `"local_copy"` | Origin of the item |
| `origin_device_id` | `string` | Yes | `null` | Device ID that created the item (for cloud-synced items only) |

### 2.2 Origin Type Values

| Value | Meaning |
|-------|---------|
| `"local_copy"` | Item was captured locally via clipboard monitoring |
| `"cloud_sync"` | Item was imported from cloud sync (originated on another device) |

### 2.3 Field Semantics

```
┌──────────────────────────────────────────────────────────────────┐
│                    ORIGIN FIELD RULES                            │
├──────────────────────────────────────────────────────────────────┤
│                                                                  │
│  origin_type = "local_copy"                                      │
│  ├── origin_device_id = null (always)                            │
│  ├── source_app_id = captured from local OS                      │
│  └── Eligible for export to cloud                                │
│                                                                  │
│  origin_type = "cloud_sync"                                      │
│  ├── origin_device_id = <remote_device_id> (required)            │
│  ├── source_app_id = preserved from remote event                 │
│  └── NOT eligible for export to cloud                            │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
```

### 2.4 Storage Migration

Migration script should:
1. Add `origin_type` column with default `"local_copy"`
2. Add `origin_device_id` column with default `null`
3. Existing items implicitly become `"local_copy"` (correct behavior)

---

## 3. Export Rules

### 3.1 Eligibility Check

**Rule**: Only export items where `origin_type == "local_copy"`.

**Rationale**:
- Prevents sync loops (re-exporting already-synced content)
- Ensures each item has exactly one canonical source device
- Reduces redundant network traffic

> **Loop Prevention Note**: Sync loops are prevented by filtering on `origin_type`, NOT by mutating or prefixing `source_app_id`. The `source_app_id` field is preserved as-is (app identifier) and is never modified for loop prevention purposes.

### 3.2 Export Logic

```cpp
ExportResult exportItem(const ClipboardHistoryItem& item) {
    // Only export local copies
    if (item.origin_type != OriginType::LocalCopy) {
        return ExportResult::SkippedNonLocalOrigin;
    }
    
    // Proceed with normal export
    // source_app_id is included as-is (may be empty or configured value)
    // ...
}
```

### 3.3 Exported Event Fields

When exporting, the event contains:
- `device_id`: This device's ID (the exporter)
- `source_app_id`: From the local item (preserved as-is, may be empty)
- Note: `origin_type` is NOT written to the event; it's implicit (the event's existence means it's from the exporting device)

---

## 4. Import Rules

### 4.1 Import Logic

When importing an event from cloud sync:

```cpp
ClipboardHistoryItem importItem(const SyncEvent& event) {
    ClipboardHistoryItem item;
    
    // Mark as cloud-synced origin
    item.origin_type = OriginType::CloudSync;
    
    // Store which device this came from
    item.origin_device_id = event.device_id;  // Required
    
    // Preserve source app attribution from remote
    item.source_app_id = event.source_app_id.value_or("");
    
    // Copy content fields (text/image)
    item.content = event.content;
    item.content_hash = event.content_hash;
    // ...
    
    return item;
}
```

### 4.2 Field Mapping

| Event Field | Local Item Field | Notes |
|-------------|------------------|-------|
| `device_id` | `origin_device_id` | Stores which device created this item |
| `source_app_id` | `source_app_id` | Preserved from remote; may be empty |
| `content_hash` | `content_hash` | Used for deduplication/precedence |
| `ts_ms` | `created_at` | Timestamp from original copy |

---

## 5. Upsert Precedence Rules

### 5.1 Content Hash Matching

When importing an item with `content_hash` H that already exists locally:

```
┌──────────────────────────────────────────────────────────────────┐
│                    PRECEDENCE DECISION TREE                      │
├──────────────────────────────────────────────────────────────────┤
│                                                                  │
│  IF local_item.content_hash == remote_event.content_hash         │
│  │                                                               │
│  ├── IF local_item.origin_type == "local_copy"                   │
│  │   └── SKIP remote event (local wins)                          │
│  │       ─ Do NOT update any fields                              │
│  │       ─ Preserve local origin_type, source_app_id             │
│  │                                                               │
│  └── IF local_item.origin_type == "cloud_sync"                   │
│      └── APPLY remote event (normal sync update)                 │
│          ─ Update with newer timestamp if applicable             │
│          ─ Update origin_device_id to latest source              │
│          ─ Preserve or update source_app_id per merge rules      │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
```

### 5.2 Upsert Truth Table

| Local `origin_type` | Content Match | Action | `origin_type` After | `origin_device_id` After | `source_app_id` After |
|---------------------|---------------|--------|---------------------|--------------------------|----------------------|
| `local_copy` | Match | **SKIP** (local wins) | `local_copy` (unchanged) | `null` (unchanged) | unchanged |
| `local_copy` | No match | INSERT | `local_copy` | `null` | captured from OS |
| `cloud_sync` | Match | UPDATE if newer ts | `cloud_sync` | remote `device_id` | remote value |
| `cloud_sync` | No match | INSERT | `cloud_sync` | remote `device_id` | remote value |

### 5.3 Rationale

**Local copy always wins** because:
1. The user copied this content on THIS device — their intent is authoritative
2. Preserves local source app attribution (the app they actually used)
3. Avoids confusing "origin drift" where a local copy suddenly appears as from another device

### 5.3 Edge Case: Same Device Re-import

If `remote_event.device_id == local_device_id`:
- This should not happen under normal operation (export excludes non-local)
- Treat as a no-op: skip the event, log a warning

---

## 6. UI Fallback: Unknown App Display

### 6.1 Problem

`source_app_id` may be:
- Empty (not provided by remote device)
- Unresolvable (app not installed on this device)
- Obfuscated (some apps don't report bundle ID)

### 6.2 Fallback Behavior

When `source_app_id` is empty or unresolvable:

```
┌──────────────────────────────────────────────────────────────────┐
│                    UI FALLBACK DISPLAY                           │
├──────────────────────────────────────────────────────────────────┤
│                                                                  │
│  IF source_app_id is empty OR app not found in local registry    │
│  │                                                               │
│  ├── Display name: "Unknown" (localized)                         │
│  │                                                               │
│  └── Display icon: Color block                                   │
│      │                                                           │
│      │   ┌─────────────────────────────────────────────────┐    │
│      │   │  Color = palette[hash(source_app_id) % N]       │    │
│      │   │                                                   │    │
│      │   │  Where:                                          │    │
│      │   │  - source_app_id = raw string (may be empty)     │    │
│      │   │  - hash() = 32-bit FNV-1a of UTF-8 bytes         │    │
│      │   │  - N = palette size                              │    │
│      │   │  - palette = fixed array of hex colors           │    │
│      │   └─────────────────────────────────────────────────┘    │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
```

### 6.3 Color Palette

Use a fixed palette of visually distinct colors:

```cpp
// Fixed palette - DO NOT CHANGE (affects color consistency across devices)
constexpr std::array<const char*, 10> kFallbackColorPalette = {
    "#FF6B6B",  // Coral Red
    "#4ECDC4",  // Teal
    "#45B7D1",  // Sky Blue
    "#96CEB4",  // Sage
    "#FFEAA7",  // Cream
    "#DDA0DD",  // Plum
    "#98D8C8",  // Mint
    "#F7DC6F",  // Sunflower
    "#BB8FCE",  // Lavender
    "#85C1E9",  // Light Blue
};
```

### 6.4 Hash Function

```cpp
uint32_t hashSourceAppId(const std::string& source_app_id) {
    // FNV-1a 32-bit hash
    uint32_t hash = 2166136261u;
    for (char c : source_app_id) {
        hash ^= static_cast<uint8_t>(c);
        hash *= 16777619u;
    }
    return hash;
}

const char* getFallbackColor(const std::string& source_app_id) {
    uint32_t hash = hashSourceAppId(source_app_id);
    return kFallbackColorPalette[hash % kFallbackColorPalette.size()];
}
```

### 6.5 Empty/Unresolvable Handling

When `source_app_id` is empty or unresolvable, use a **fallback hash source**:

```
┌──────────────────────────────────────────────────────────────────┐
│                    COLOR FALLBACK PRIORITY                       │
├──────────────────────────────────────────────────────────────────┤
│                                                                  │
│  hash_input =                                                    │
│      IF source_app_id is non-empty:                              │
│          source_app_id                                           │
│      ELSE IF origin_device_id is non-null:                       │
│          origin_device_id                                        │
│      ELSE:                                                       │
│          "" (empty string - stable default)                      │
│                                                                  │
│  Color = palette[FNV1a(hash_input) % N]                          │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
```

**Rationale**:
- Non-empty `source_app_id` → same app always gets same color
- Empty `source_app_id` but present `origin_device_id` → items from same device get same color
- Both empty → fallback to empty string hash (stable default)

```cpp
std::string getColorHashInput(const ClipboardHistoryItem& item) {
    if (!item.source_app_id.empty()) {
        return item.source_app_id;
    }
    if (item.origin_device_id.has_value() && !item.origin_device_id->empty()) {
        return item.origin_device_id.value();
    }
    return "";  // Stable default
}

const char* getFallbackColor(const ClipboardHistoryItem& item) {
    std::string hash_input = getColorHashInput(item);
    uint32_t hash = hashSourceAppId(hash_input);
    return kFallbackColorPalette[hash % kFallbackColorPalette.size()];
}
```

**Empty String Hash** (stable default):
- Hash of empty string = `2166136261` (FNV-1a basis)
- Maps to palette index: `2166136261 % 10 = 1` → `"#4ECDC4"` (Teal)
- This provides a consistent "unknown" color when no identifier is available

---

## 7. Configuration

### 7.1 `source_app_id` Configuration

`source_app_id` is **optional** and can be:

1. **Auto-captured** (default): Platform layer detects source app from OS clipboard metadata
2. **User-configured**: User can set a custom `source_app_id` for this device's exports

### 7.2 Configuration Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `cloudSyncSourceAppId` | `string?` | `null` | Custom source_app_id to use for exports; `null` = auto-detect |

### 7.3 Behavior

```cpp
std::string getSourceAppIdForExport(const ClipboardHistoryItem& item) {
    // If user configured a custom source_app_id, use it
    if (m_config.cloudSyncSourceAppId.has_value()) {
        return m_config.cloudSyncSourceAppId.value();
    }
    
    // Otherwise, use the captured source_app_id (may be empty)
    return item.source_app_id;
}
```

### 7.4 Use Cases

| Scenario | Configuration | Result |
|----------|---------------|--------|
| Normal usage | `cloudSyncSourceAppId = null` | Auto-detect from OS |
| Privacy-focused user | `cloudSyncSourceAppId = ""` | Always empty (no app attribution) |
| Custom identifier | `cloudSyncSourceAppId = "my-device"` | All exports show "my-device" |

---

## 8. Summary

### 8.1 Quick Reference

| Aspect | Rule |
|--------|------|
| **DB: origin_type** | `"local_copy"` (default) or `"cloud_sync"` |
| **DB: origin_device_id** | `null` for local, `<device_id>` for synced |
| **Export** | Only export `origin_type == "local_copy"` |
| **Import** | Set `origin_type = "cloud_sync"`, `origin_device_id = event.device_id` |
| **Precedence** | Local copy wins; never override if `origin_type == "local_copy"` |
| **UI Fallback** | "Unknown" + color from hashed `source_app_id` → `origin_device_id` → `""` |
| **Loop Prevention** | Via `origin_type` filtering only; `source_app_id` never mutated |
| **Config** | `cloudSyncSourceAppId` is optional override |

### 8.2 Data Flow Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           SYNC DATA FLOW                                    │
└─────────────────────────────────────────────────────────────────────────────┘

DEVICE A (Local)                              DEVICE B (Remote)
─────────────────                             ─────────────────
                                                    │
┌─────────────────┐                                │
│ Clipboard       │                                │
│ Monitor         │                                │
└────────┬────────┘                                │
         │                                         │
         ▼                                         │
┌─────────────────┐                                │
│ Local Item      │                                │
│ origin_type:    │                                │
│   local_copy    │                                │
│ source_app_id:  │                                │
│   "com.app.A"   │                                │
└────────┬────────┘                                │
         │                                         │
         │ EXPORT                                  │
         │ (only local_copy)                       │
         ▼                                         │
┌─────────────────┐      SYNC CLOUD       ┌─────────────────┐
│ events-NNNN     │ ────────────────────▶ │ events-NNNN     │
│ .jsonl          │                       │ .jsonl          │
│ device_id: A    │                       │ (Device A's log)│
│ source_app_id:  │                       └────────┬────────┘
│   "com.app.A"   │                                │
└─────────────────┘                                │
                                                   │ IMPORT
                                                   ▼
                                          ┌─────────────────┐
                                          │ Synced Item     │
                                          │ origin_type:    │
                                          │   cloud_sync    │
                                          │ origin_device_id│
                                          │   : "A"         │
                                          │ source_app_id:  │
                                          │   "com.app.A"   │
                                          └─────────────────┘
                                                   │
                                                   │ NOT exported
                                                   │ (origin_type != local_copy)
                                                   ▼
                                                   [END]
```

---

## 9. Implementation Notes

### 9.1 Files to Modify

| File | Changes |
|------|---------|
| `core/src/model/clipboard_history_item.h` | Add `origin_type`, `origin_device_id` fields |
| `core/src/infrastructure/sync/cloud_drive_sync_exporter.cpp` | Add origin_type check before export |
| `core/src/infrastructure/sync/cloud_drive_sync_importer.cpp` | Set origin fields on import; add precedence check |
| `core/src/runtime/core_runtime_config.h` | Add `cloudSyncSourceAppId` option |
| `macos/...` (platform layer) | Add color fallback UI logic |

### 9.2 Migration Path

1. Add new columns to SQLite schema (with defaults)
2. Existing items become `local_copy` automatically
3. No data loss; backward compatible

### 9.3 Testing Requirements

1. **Export filtering**: Verify non-local items are skipped
2. **Import attribution**: Verify origin fields are set correctly
3. **Precedence**: Local copy should win in conflict
4. **UI fallback**: Empty/unknown app_id shows consistent color
5. **Config override**: Custom source_app_id is used when configured

---

**End of Design Document**
