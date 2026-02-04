# Rust FFI Contract

**Feature**: 002-clipboard-history
**Date**: 2026-02-04
**Version**: 1.0

## Overview

This document defines the Foreign Function Interface (FFI) contract between Swift (macOS platform layer) and Rust (cross-platform core layer). The FFI enables Swift to invoke Rust functions for clipboard storage, retrieval, and deduplication operations.

## Calling Convention

- **ABI**: C (extern "C")
- **Naming**: `pasty_*` prefix for all public functions
- **Memory Management**: Rust owns returned structs, Swift must call cleanup functions
- **Error Handling**: Integer error codes (0 = success, non-zero = error)

## Type Definitions

### C Types (Shared)

```c
#include <stdint.h>
#include <stdbool.h>

// Content type enumeration
typedef enum {
    PASTY_CONTENT_TYPE_TEXT = 0,
    PASTY_CONTENT_TYPE_IMAGE = 1,
} PastyContentType;

// Error codes
typedef enum {
    PASTY_ERROR_SUCCESS = 0,
    PASTY_ERROR_INVALID_INPUT = 1,
    PASTY_ERROR_DATABASE = 2,
    PASTY_ERROR_IO = 3,
    PASTY_ERROR_HASH = 4,
    PASTY_ERROR_UNKNOWN = -1,
} PastyErrorCode;

// Opaque pointer types (forward declarations)
typedef struct PastyClipboardEntry PastyClipboardEntry;
typedef struct PastyClipboardEntryList PastyClipboardEntryList;
```

### Rust Type Mapping

| Rust Type | C Type | Swift Type |
|-----------|--------|------------|
| `i32` | `int32_t` | `Int32` |
| `u32` | `uint32_t` | `UInt32` |
| `i64` | `int64_t` | `Int64` |
| `u64` | `uint64_t` | `UInt64` |
| `bool` | `bool` | `Bool` |
| `*const u8` | `const uint8_t*` | `UnsafePointer<UInt8>` |
| `*const char` | `const char*` | `UnsafePointer<Int8>` (C string) |
| `*mut T` | `T*` | `UnsafeMutablePointer<T>` |
| `enum` | `enum` | `enum` |
| `struct` | `struct` | `struct` |

## API Functions

### 1. Store Clipboard Entry

Stores a clipboard entry in the database with automatic deduplication.

```c
PastyClipboardEntry* pasty_store_clipboard_entry(
    PastyContentType content_type,
    const uint8_t* content_ptr,
    uint64_t content_len,
    const char* source_bundle_id,
    const char* source_app_name,
    int32_t source_pid,
    int64_t timestamp_ms,
    PastyErrorCode* out_error
);
```

**Parameters**:
- `content_type`: Type of clipboard content (TEXT or IMAGE)
- `content_ptr`: Pointer to content data (UTF-8 string for text, binary for image)
- `content_len`: Length of content data in bytes
- `source_bundle_id`: Bundle identifier of source app (e.g., "com.apple.Safari")
- `source_app_name`: Display name of source app (e.g., "Safari")
- `source_pid`: Process ID of source app
- `timestamp_ms`: Unix timestamp in milliseconds
- `out_error`: Output parameter for error code (can be NULL)

**Returns**:
- Pointer to `PastyClipboardEntry` (owned by Rust, must be freed with `pasty_entry_free`)
- NULL on error (check `out_error` for details)

**Behavior**:
- Calculates SHA-256 hash of content
- Checks for existing entry with same hash
- If duplicate: Updates timestamp and returns existing entry
- If new: Creates new entry with UUID v4, saves to database
- For images: Saves image to file system with hash-based filename

**Swift Usage**:
```swift
let contentType = PastyContentType.text
let textBytes = text.data(using: .utf8)!
let bundleId = "com.apple.Safari"
let appName = "Safari"
let pid = 12345
let timestamp = Int64(Date().timeIntervalSince1970 * 1000)
var error: PastyErrorCode = 0

textBytes.withUnsafeBytes { bytes in
    let entry = pasty_store_clipboard_entry(
        contentType,
        bytes.baseAddress,
        textBytes.count,
        bundleId,
        appName,
        pid,
        timestamp,
        &error
    )

    if error == PASTY_ERROR_SUCCESS {
        // Use entry
        defer { pasty_entry_free(entry) }
    } else {
        // Handle error
    }
}
```

---

### 2. Retrieve Clipboard History

Retrieves clipboard entries from the database.

```c
PastyClipboardEntryList* pasty_get_clipboard_history(
    int64_t limit,
    int64_t offset,
    PastyContentType filter_type,
    bool filter_type_enabled,
    PastyErrorCode* out_error
);
```

**Parameters**:
- `limit`: Maximum number of entries to return (0 = no limit)
- `offset`: Number of entries to skip (for pagination)
- `filter_type`: Content type filter (TEXT or IMAGE)
- `filter_type_enabled`: If true, filter by `filter_type`; if false, return all types
- `out_error`: Output parameter for error code

**Returns**:
- Pointer to `PastyClipboardEntryList` (owned by Rust, must be freed with `pasty_list_free`)
- NULL on error

**Behavior**:
- Queries database ordered by timestamp DESC (most recent first)
- Applies LIMIT and OFFSET for pagination
- Applies content type filter if enabled
- Returns list of entries (possibly empty)

**Swift Usage**:
```swift
var error: PastyErrorCode = 0
let list = pasty_get_clipboard_history(
    50,    // limit
    0,     // offset
    PASTY_CONTENT_TYPE_TEXT,
    true,  // filter by type
    &error
)

if error == PASTY_ERROR_SUCCESS {
    defer { pasty_list_free(list) }

    let count = pasty_list_get_count(list)
    for i in 0..<count {
        let entry = pasty_list_get_entry(list, i)
        // Use entry
    }
}
```

---

### 3. Get Entry by ID

Retrieves a specific clipboard entry by its UUID.

```c
PastyClipboardEntry* pasty_get_entry_by_id(
    const char* entry_id,
    PastyErrorCode* out_error
);
```

**Parameters**:
- `entry_id`: UUID as string (36 characters with hyphens)
- `out_error`: Output parameter for error code

**Returns**:
- Pointer to `PastyClipboardEntry` (owned by Rust)
- NULL if not found or on error

---

### 4. Delete Entry

Deletes a clipboard entry from the database.

```c
bool pasty_delete_entry(
    const char* entry_id,
    PastyErrorCode* out_error
);
```

**Parameters**:
- `entry_id`: UUID as string
- `out_error`: Output parameter for error code

**Returns**:
- `true` if entry was deleted
- `false` if entry not found or error occurred

---

### 5. Clear All History

Deletes all clipboard entries from the database.

```c
bool pasty_clear_all_history(
    PastyErrorCode* out_error
);
```

**Parameters**:
- `out_error`: Output parameter for error code

**Returns**:
- `true` if all entries were deleted
- `false` on error

---

### 6. Get Entry Count

Returns the total number of clipboard entries.

```c
int64_t pasty_get_entry_count(
    PastyErrorCode* out_error
);
```

**Returns**:
- Number of entries in database
- -1 on error

---

## Accessor Functions

### ClipboardEntry Accessors

```c
// Get entry ID (UUID as string, caller does not own)
const char* pasty_entry_get_id(const PastyClipboardEntry* entry);

// Get content hash (SHA-256 hex string, caller does not own)
const char* pasty_entry_get_content_hash(const PastyClipboardEntry* entry);

// Get content type
PastyContentType pasty_entry_get_content_type(const PastyClipboardEntry* entry);

// Get timestamp (milliseconds since Unix epoch)
int64_t pasty_entry_get_timestamp(const PastyClipboardEntry* entry);

// Get text content (UTF-8 string, caller does not own, NULL for image type)
const char* pasty_entry_get_text_content(const PastyClipboardEntry* entry);

// Get image path (relative path, caller does not own, NULL for text type)
const char* pasty_entry_get_image_path(const PastyClipboardEntry* entry);

// Get source bundle ID (caller does not own)
const char* pasty_entry_get_source_bundle_id(const PastyClipboardEntry* entry);

// Get source app name (caller does not own)
const char* pasty_entry_get_source_app_name(const PastyClipboardEntry* entry);

// Get source PID
int32_t pasty_entry_get_source_pid(const PastyClipboardEntry* entry);
```

### ClipboardEntryList Accessors

```c
// Get number of entries in list
int64_t pasty_list_get_count(const PastyClipboardEntryList* list);

// Get entry at index (caller does not own, valid until list is freed)
const PastyClipboardEntry* pasty_list_get_entry(
    const PastyClipboardEntryList* list,
    int64_t index
);
```

---

## Memory Management Functions

```c
// Free a ClipboardEntry (returned by store/get functions)
void pasty_entry_free(PastyClipboardEntry* entry);

// Free a ClipboardEntryList (returned by get_history function)
void pasty_list_free(PastyClipboardEntryList* list);
```

**Important**: All structs returned by FFI functions are owned by Rust and must be freed using the appropriate free function to prevent memory leaks.

---

## Error Handling

### Error Codes

| Code | Name | Description |
|------|------|-------------|
| 0 | SUCCESS | Operation completed successfully |
| 1 | INVALID_INPUT | Invalid parameter (null pointer, invalid UUID, etc.) |
| 2 | DATABASE | Database error (locked, corrupted, etc.) |
| 3 | IO | File system I/O error (disk full, permissions, etc.) |
| 4 | HASH | Hash calculation error |
| -1 | UNKNOWN | Unknown error |

### Error Message (Optional)

```c
// Get error message for error code (caller does not own)
const char* pasty_error_message(PastyErrorCode error);
```

---

## Swift Bindings

### Type Definitions

```swift
typealias PastyContentType = PastyContentType_C
typealias PastyErrorCode = PastyErrorCode_C

enum PastyContentType_C: UInt32 {
    case text = 0
    case image = 1
}

enum PastyErrorCode_C: Int32 {
    case success = 0
    case invalidInput = 1
    case database = 2
    case io = 3
    case hash = 4
    case unknown = -1
}
```

### Wrapper Structs

```swift
struct ClipboardEntry {
    let id: String
    let contentHash: String
    let contentType: ContentType
    let timestamp: Date
    let content: Content
    let source: SourceApplication

    init(from ptr: UnsafeMutablePointer<PastyClipboardEntry>) {
        id = String(cString: pasty_entry_get_id(ptr))
        contentHash = String(cString: pasty_entry_get_content_hash(ptr))
        contentType = ContentType(rawValue: pasty_entry_get_content_type(ptr).rawValue)!

        let ms = pasty_entry_get_timestamp(ptr)
        timestamp = Date(timeIntervalSince1970: TimeInterval(ms) / 1000.0)

        let textPtr = pasty_entry_get_text_content(ptr)
        let imagePathPtr = pasty_entry_get_image_path(ptr)

        if textPtr != nil {
            content = .text(String(cString: textPtr!))
        } else if imagePathPtr != nil {
            content = .image(ImageFile(path: String(cString: imagePathPtr!)))
        }

        source = SourceApplication(
            bundleId: String(cString: pasty_entry_get_source_bundle_id(ptr)),
            appName: String(cString: pasty_entry_get_source_app_name(ptr)),
            pid: pasty_entry_get_source_pid(ptr)
        )
    }
}
```

---

## Testing

### Contract Tests

Contract tests verify that the FFI boundary behaves correctly:

```rust
#[cfg(test)]
mod ffi_tests {
    use super::*;

    #[test]
    fn test_store_and_retrieve_text_entry() {
        let text = "Hello, World!";
        let result = store_clipboard_entry(
            ContentType::Text,
            text.as_bytes(),
            "com.test.app",
            "Test App",
            1234,
            SystemTime::now(),
        );
        assert!(result.is_ok());

        let entry = result.unwrap();
        assert_eq!(entry.content_type, ContentType::Text);
        assert!(!entry.id.is_nil());
    }

    #[test]
    fn test_deduplication() {
        let text = "Duplicate content";
        let entry1 = store_clipboard_entry(
            ContentType::Text,
            text.as_bytes(),
            "com.test.app",
            "Test App",
            1234,
            SystemTime::now(),
        ).unwrap();

        let entry2 = store_clipboard_entry(
            ContentType::Text,
            text.as_bytes(),
            "com.test.app",
            "Test App",
            1234,
            SystemTime::now(),
        ).unwrap();

        assert_eq!(entry1.id, entry2.id);
        assert!(entry2.timestamp > entry1.timestamp);
    }
}
```

---

## Thread Safety

- All FFI functions are thread-safe
- Internal Rust code uses `Mutex` or `RwLock` for database access
- Swift can call FFI functions from any thread (background queue recommended for I/O operations)

---

## Versioning

The FFI contract is versioned to maintain compatibility:

- **Major version**: Breaking changes (removed functions, changed signatures)
- **Minor version**: New functions added (backward compatible)
- **Patch version**: Bug fixes (no API changes)

Current version: **1.0.0**

Future versions will maintain backward compatibility when possible. Deprecated functions will be marked but not removed for at least one major version.

---

## Summary

This FFI contract provides:

- ✅ Clear interface between Swift and Rust
- ✅ Type-safe function signatures
- ✅ Defined memory ownership and cleanup
- ✅ Comprehensive error handling
- ✅ Thread-safe operations
- ✅ Testable contract definitions
- ✅ Versioning for future evolution
