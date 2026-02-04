# FFI API Contract: Rust Core to Swift

**Feature**: 001-rust-swift-framework
**Version**: 1.0.0
**Date**: 2026-02-04

This document specifies the FFI (Foreign Function Interface) contract between the Rust core library and Swift macOS layer. All functions use C ABI and follow the conventions specified here.

---

## API Conventions

### Function Naming
- **Prefix**: All functions prefixed with `pasty_`
- **Snake_case**: Use snake_case for function names
- **Noun-verb pattern**: `pasty_<entity>_<action>` (e.g., `pasty_clipboard_get_text`)

### Return Values
- **Integer return**: 0 = success, negative = error code
- **Pointer return**: Valid pointer on success, `NULL` on error
- **Boolean**: 0 = false, 1 = true

### Memory Management
- **Owned strings**: Rust allocates with `CString::into_raw()`, Swift frees with `pasty_free_string()`
- **Borrowed strings**: Swift passes `const char*`, Rust borrows for duration of call
- **Arrays**: Pass pointer + length, caller owns memory

### Error Handling
- **Thread-local error**: Each thread has a last-error message
- **Error retrieval**: Call `pasty_get_last_error()` after failed operation
- **Error lifetime**: Error string valid until next FFI call on same thread

---

## Core API

### `pasty_get_version`

Get the Rust core library version string.

**Signature**:
```c
const char *pasty_get_version(void);
```

**Parameters**: None

**Return Value**:
- Success: Pointer to null-terminated version string (e.g., "0.1.0")
- Failure: Never fails (returns valid string)

**Memory Management**:
- Rust owns the string
- Swift **must not** free this string (static string)
- Swift should copy if needed: `String(validatingUTF8: pasty_get_version())`

**Thread Safety**: Safe (returns static string)

---

### `pasty_init`

Initialize the Rust core library. Must be called before any other FFI functions.

**Signature**:
```c
int pasty_init(void);
```

**Parameters**: None

**Return Value**:
- `0`: Success
- `-1`: Initialization failed (check `pasty_get_last_error()`)

**Side Effects**:
- Allocates internal resources
- Initializes logging
- Sets up thread-local storage

**Thread Safety**: Safe to call multiple times (idempotent)

**Usage**:
```swift
let result = pasty_init()
if result != 0 {
    // Handle error
    if let error = pasty_get_last_error() {
        print("Init failed: \(String(validatingUTF8: error) ?? "Unknown")")
    }
}
```

---

### `pasty_shutdown`

Shutdown the Rust core library and free allocated resources.

**Signature**:
```c
int pasty_shutdown(void);
```

**Parameters**: None

**Return Value**:
- `0`: Success
- `-1`: Shutdown failed (check `pasty_get_last_error()`)

**Side Effects**:
- Frees all allocated resources
- Closes log files
- Invalidates previously returned pointers

**Thread Safety**: Safe to call multiple times (idempotent)

**Usage**:
```swift
let result = pasty_shutdown()
if result != 0 {
    // Log error but continue (app is shutting down anyway)
}
```

---

### `pasty_free_string`

Free a string allocated by Rust and returned to Swift.

**Signature**:
```c
void pasty_free_string(char *ptr);
```

**Parameters**:
- `ptr`: Pointer to string allocated by Rust (can be `NULL`)

**Return Value**: None

**Safety**:
- Safe to pass `NULL` (no-op)
- **Undefined behavior** if pointer not allocated by Rust
- **Undefined behavior** if pointer already freed
- **Undefined behavior** if pointer points to stack/static data

**Usage**:
```swift
let cString = pasty_clipboard_get_text()
defer { pasty_free_string(cString) }
guard let text = String(validatingUTF8: cString) else {
    // Handle invalid UTF-8
}
```

---

### `pasty_get_last_error`

Get the error message from the last failed FFI call on the current thread.

**Signature**:
```c
const char *pasty_get_last_error(void);
```

**Parameters**: None

**Return Value**:
- Success: Pointer to error message string
- No error: `NULL`

**Memory Management**:
- Rust owns the string (thread-local storage)
- Swift **must not** free this string
- Valid until next FFI call on same thread

**Thread Safety**: Thread-local (different threads have different error messages)

**Usage**:
```swift
if pasty_init() != 0 {
    if let errorPtr = pasty_get_last_error(),
       let error = String(validatingUTF8: errorPtr) {
        print("Error: \(error)")
    }
}
```

---

## Placeholder API (Future Features)

The following functions are **placeholders** in this feature. They will be implemented in future clipboard features.

### `pasty_clipboard_get_text`

Get the current text content from the system clipboard.

**Signature**:
```c
char *pasty_clipboard_get_text(void);
```

**Return Value** (future implementation):
- Success: Pointer to clipboard text (must be freed with `pasty_free_string()`)
- No text: `NULL`
- Error: `NULL` (check `pasty_get_last_error()`)

**Current Implementation**: Always returns `NULL` and sets "Not implemented yet" error

---

### `pasty_clipboard_set_text`

Set the system clipboard text content.

**Signature**:
```c
int pasty_clipboard_set_text(const char *text);
```

**Parameters**:
- `text`: Null-terminated UTF-8 string to copy to clipboard

**Return Value** (future implementation):
- `0`: Success
- `-1`: Error (check `pasty_get_last_error()`)

**Current Implementation**: Always returns `-1` and sets "Not implemented yet" error

---

### `pasty_history_add`

Add an entry to clipboard history.

**Signature**:
```c
int pasty_history_add(
    int64_t timestamp,
    uint32_t content_type,
    const uint8_t *data,
    size_t data_len
);
```

**Parameters**:
- `timestamp`: Unix timestamp when entry was created
- `content_type`: Enum value (0=Text, 1=Image, 2=File, 3=HTML)
- `data`: Pointer to data bytes
- `data_len`: Length of data in bytes

**Return Value** (future implementation):
- `0`: Success
- `-1`: Error (check `pasty_get_last_error()`)

**Current Implementation**: Always returns `-1` and sets "Not implemented yet" error

---

## Data Types

### ContentType Enum

```c
typedef enum {
    PASTY_CONTENT_TYPE_TEXT = 0,
    PASTY_CONTENT_TYPE_IMAGE = 1,
    PASTY_CONTENT_TYPE_FILE = 2,
    PASTY_CONTENT_TYPE_HTML = 3,
} pasty_content_type_t;
```

---

## Swift Bridging

### Module Map

Create `core/module.modulemap`:

```modulemap
module PastyCore {
    header "pasty.h"
    link "core"
    export *
}
```

### Swift Usage

```swift
import Foundation

// Load function symbols from embedded static library
// (In Xcode, link against libcore.a and use module map)

class PastyFFIBridge {
    private init() {}

    static let shared = PastyFFIBridge()

    func initialize() throws {
        if pasty_init() != 0 {
            throw FFIError.coreError(getLastError())
        }
    }

    private func getLastError() -> String? {
        guard let errorPtr = pasty_get_last_error() else {
            return nil
        }
        return String(validatingUTF8: errorPtr)
    }

    func getVersion() -> String {
        guard let versionPtr = pasty_get_version(),
              let version = String(validatingUTF8: versionPtr) else {
            return "Unknown"
        }
        return version
    }
}

enum FFIError: Error {
    case coreError(String?)
    case notImplemented
}
```

---

## Error Codes

| Code | Meaning |
|------|---------|
| `0` | Success |
| `-1` | Generic error (check `pasty_get_last_error()`) |
| `-2` | Invalid argument |
| `-3` | Out of memory |
| `-4` | Not implemented |

---

## Versioning

This API is versioned as part of the Rust core library:
- Major version bump: Breaking changes to FFI API
- Minor version bump: New functions added
- Patch version bump: Bug fixes, no API changes

Check version with `pasty_get_version()` before using new features.

---

## Testing Contract

Unit tests must verify:

1. **Init/Shutdown Cycle**: `pasty_init()` → `pasty_shutdown()` → `pasty_init()` again
2. **Version Retrieval**: `pasty_get_version()` returns valid semver string
3. **Error Handling**: All functions set errors correctly on failure
4. **Memory Safety**: All allocated strings are freed without leaks
5. **Thread Safety**: Multiple threads can call FFI functions concurrently

---

## Future Extensions

Planned additions (not in current feature):

- Clipboard read/write functions
- History management (add, remove, query)
- Encryption/decryption functions
- Configuration management
- Event callbacks (clipboard changed, history updated)

All future additions will follow the conventions specified in this document.
