# Data Model: Cross-Platform Framework Infrastructure

**Feature**: 001-rust-swift-framework
**Date**: 2026-02-04
**Phase**: Phase 1 - Design

This document defines the data entities and interfaces for the Rust core library and Swift macOS platform layer.

---

## Overview

The framework consists of three architectural layers:

1. **Rust Core** (platform-agnostic): Business logic, data models, service interfaces
2. **FFI Boundary** (C ABI): Bridge between Rust and Swift using C-compatible types
3. **Swift macOS Layer** (platform-specific): UI, system integration, permissions

This is **framework infrastructure only** - no actual clipboard features are implemented yet. We're defining the foundational structure that future clipboard features will build upon.

---

## Rust Core Entities

### 1. ClipboardEntry

**Purpose**: Represents a single clipboard content item (text, image, etc.)

**Location**: `core/src/models/clipboard_entry.rs`

```rust
/// Represents a single clipboard entry with content and metadata
pub struct ClipboardEntry {
    /// Unique identifier for this entry
    pub id: String,

    /// Timestamp when entry was created (Unix timestamp)
    pub timestamp: i64,

    /// Content type (text, image, file, etc.)
    pub content_type: ContentType,

    /// Actual clipboard data
    pub data: ClipboardData,

    /// Source application that copied content (optional)
    pub source_app: Option<String>,

    /// Whether this entry is pinned/favorite
    pub is_pinned: bool,
}

/// Supported clipboard content types
#[derive(Debug, Clone, PartialEq)]
pub enum ContentType {
    Text,
    Image,
    File,
    HTML,
    Custom(String),
}

/// Clipboard data variants
pub enum ClipboardData {
    Text(String),
    Image(Vec<u8>),  // Raw image bytes
    File(String),    // File path
    HTML(String),
}
```

**Validation Rules**:
- `id` must be unique (use UUID v4)
- `timestamp` must be positive Unix timestamp
- `data` must match `content_type` (e.g., `ContentType::Text` requires `ClipboardData::Text`)

**State Transitions**:
```
Created → Pinned (if user pins)
Created → Deleted (if user deletes or expires)
```

---

### 2. ClipboardHistory

**Purpose**: Manages the collection of clipboard entries with retention policies

**Location**: `core/src/models/clipboard_history.rs`

```rust
/// Manages clipboard history with retention policies
pub struct ClipboardHistory {
    /// Ordered list of clipboard entries (newest first)
    pub entries: Vec<ClipboardEntry>,

    /// Maximum number of entries to retain
    pub max_entries: usize,

    /// Retention duration in seconds (0 = unlimited)
    pub retention_seconds: i64,
}

impl ClipboardHistory {
    /// Add a new entry to history
    pub fn add_entry(&mut self, entry: ClipboardEntry) -> Result<(), Error>;

    /// Remove an entry by ID
    pub fn remove_entry(&mut self, id: &str) -> Result<(), Error>;

    /// Get entry by ID
    pub fn get_entry(&self, id: &str) -> Option<&ClipboardEntry>;

    /// Get all entries (newest first)
    pub fn get_all_entries(&self) -> Vec<&ClipboardEntry>;

    /// Clear all entries
    pub fn clear(&mut self);

    /// Remove expired entries based on retention policy
    pub fn remove_expired(&mut self);
}
```

**Validation Rules**:
- `max_entries` must be > 0
- `retention_seconds` must be ≥ 0
- When adding entry, enforce `max_entries` limit (remove oldest if needed)
- When adding entry, remove expired entries first

---

### 3. EncryptionService (Interface)

**Purpose**: Provides encryption/decryption for sensitive clipboard data

**Location**: `core/src/services/encryption.rs`

```rust
/// Service for encrypting and decrypting clipboard data
pub trait EncryptionService: Send + Sync {
    /// Encrypt clipboard data
    fn encrypt(&self, data: &[u8]) -> Result<Vec<u8>, EncryptionError>;

    /// Decrypt clipboard data
    fn decrypt(&self, encrypted_data: &[u8]) -> Result<Vec<u8>, EncryptionError>;
}

/// Encryption errors
#[derive(Debug)]
pub enum EncryptionError {
    KeychainAccessFailed,
    InvalidData,
    EncryptionFailed,
    DecryptionFailed,
}

/// Platform-specific encryption implementation (to be implemented per-platform)
pub struct PlatformEncryptionService {
    // Platform-specific fields (Keychain on macOS, DPAPI on Windows, etc.)
}

impl EncryptionService for PlatformEncryptionService {
    // Implementation provided by platform layer
}
```

**Validation Rules**:
- Empty data should encrypt successfully (produces non-empty ciphertext)
- Decrypted data must match original data
- Keychain/DPAPI access failures return clear errors

**Implementation Notes**:
- This is a **trait definition only** in this feature
- Actual implementation will be platform-specific (macOS Keychain, Windows DPAPI, Linux libsecret)
- FFI exports will use a concrete implementation for macOS

---

## FFI Boundary (C ABI)

### FFI Exports

**Purpose**: Public C API for Swift to call Rust functions

**Location**: `core/src/ffi/exports.rs`

**Note**: Only **scaffolding functions** are implemented in this feature. Real clipboard operations will be added in future features.

```rust
use std::ffi::{CStr, CString};
use std::os::raw::{c_char, c_int};

/// Version information for the Rust core
#[no_mangle]
pub extern "C" fn pasty_get_version() -> *const c_char {
    let version = env!("CARGO_PKG_VERSION");
    CString::new(version).unwrap().into_raw()
}

/// Initialize the Rust core (allocate any necessary resources)
#[no_mangle]
pub extern "C" fn pasty_init() -> c_int {
    // TODO: Initialize logging, allocate resources
    0  // Success
}

/// Shutdown the Rust core (free allocated resources)
#[no_mangle]
pub extern "C" fn pasty_shutdown() -> c_int {
    // TODO: Free resources, close log files
    0  // Success
}

/// Free a string allocated by Rust
/// # Safety
/// Caller must ensure pointer was allocated by Rust and not already freed
#[no_mangle]
pub extern "C" fn pasty_free_string(ptr: *mut c_char) {
    if !ptr.is_null() {
        unsafe {
            let _ = CString::from_raw(ptr);
        }
    }
}

/// Get last error message (thread-local)
/// Returns null if no error
#[no_mangle]
pub extern "C" fn pasty_get_last_error() -> *const c_char {
    use std::cell::RefCell;
    use std::thread_local;

    thread_local! {
        static LAST_ERROR: RefCell<Option<CString>> = RefCell::new(None);
    }

    LAST_ERROR.with(|error| {
        if let Some(msg) = error.borrow().as_ref() {
            msg.as_ptr()
        } else {
            std::ptr::null()
        }
    })
}

/// Set last error message (internal helper)
fn set_last_error(message: &str) {
    use std::cell::RefCell;
    use std::thread_local;

    thread_local! {
        static LAST_ERROR: RefCell<Option<CString>> = RefCell::new(None);
    }

    LAST_ERROR.with(|error| {
        *error.borrow_mut() = CString::new(message).ok();
    });
}

// ========== PLACEHOLDER FUNCTIONS (for future clipboard features) ==========

/// Placeholder: Get current clipboard text
/// Returns null if not text content or error occurs
#[no_mangle]
pub extern "C" fn pasty_clipboard_get_text() -> *mut c_char {
    set_last_error("Not implemented yet - use future clipboard feature");
    std::ptr::null_mut()
}

/// Placeholder: Set clipboard text
/// Returns 0 on success, negative on error
#[no_mangle]
pub extern "C" fn pasty_clipboard_set_text(_text: *const c_char) -> c_int {
    set_last_error("Not implemented yet - use future clipboard feature");
    -1
}

/// Placeholder: Add entry to clipboard history
/// Returns 0 on success, negative on error
#[no_mangle]
pub extern "C" fn pasty_history_add(_timestamp: i64, _content_type: u32, _data: *const u8, _data_len: usize) -> c_int {
    set_last_error("Not implemented yet - use future clipboard feature");
    -1
}
```

**FFI Conventions**:
- All functions prefixed with `pasty_`
- Return 0 for success, negative for errors (except functions returning pointers)
- String pointers returned by Rust must be freed with `pasty_free_string()`
- Errors set thread-local message retrievable via `pasty_get_last_error()`
- All `extern "C"` functions use C ABI (no name mangling)

**Memory Management**:
- Rust owns strings allocated with `CString::into_raw()`
- Swift caller must call `pasty_free_string()` to reclaim memory
- Check for null pointers before dereferencing

---

## Swift macOS Layer

### FFIBridge

**Purpose**: Swift wrapper for Rust FFI calls, providing type-safe Swift API

**Location**: `macos/PastyApp/FFIBridge.swift`

```swift
import Foundation

/// Type-safe Swift wrapper for Rust FFI calls
class PastyFFIBridge {

    // MARK: - Initialization

    /// Initialize the Rust core
    func initialize() throws {
        let result = pasty_init()
        if result != 0 {
            throw FFIError.coreInitializationFailed
        }
    }

    /// Shutdown the Rust core
    func shutdown() throws {
        let result = pasty_shutdown()
        if result != 0 {
            throw FFIError.coreShutdownFailed
        }
    }

    // MARK: - Version

    /// Get the Rust core version
    func getVersion() -> String? {
        guard let cString = pasty_get_version() else {
            return nil
        }
        defer { pasty_free_string(UnsafeMutablePointer(mutating: cString)) }
        return String(validatingUTF8: cString)
    }

    // MARK: - Error Handling

    /// Get the last error message from Rust
    func getLastError() -> String? {
        guard let cString = pasty_get_last_error() else {
            return nil
        }
        return String(validatingUTF8: cString)
    }

    // MARK: - Placeholder Functions (Future Features)

    /// Get current clipboard text
    func getClipboardText() throws -> String {
        guard let cString = pasty_clipboard_get_text() else {
            throw FFIError.functionNotImplemented
        }
        defer { pasty_free_string(cString) }
        guard let text = String(validatingUTF8: cString) else {
            throw FFIError.invalidString
        }
        return text
    }

    /// Set clipboard text
    func setClipboardText(_ text: String) throws {
        let result = text.withCString { cString in
            pasty_clipboard_set_text(cString)
        }
        if result != 0 {
            throw FFIError.fromCode(result)
        }
    }
}

// MARK: - FFI Function Declarations

// These will be auto-generated from cbindgen output
// For now, manual declarations:

/** Get Rust core version - returns C string (must be freed) */
@_silgen_name("pasty_get_version")
func pasty_get_version() -> UnsafeMutablePointer<CChar>?

/** Initialize Rust core - returns 0 on success */
@_silgen_name("pasty_init")
func pasty_init() -> Int32

/** Shutdown Rust core - returns 0 on success */
@_silgen_name("pasty_shutdown")
func pasty_shutdown() -> Int32

/** Free string allocated by Rust */
@_silgen_name("pasty_free_string")
func pasty_free_string(_ ptr: UnsafeMutablePointer<CChar>)

/** Get last error message - returns C string or null */
@_silgen_name("pasty_get_last_error")
func pasty_get_last_error() -> UnsafeMutablePointer<CChar>?

/** Placeholder: Get clipboard text */
@_silgen_name("pasty_clipboard_get_text")
func pasty_clipboard_get_text() -> UnsafeMutablePointer<CChar>?

/** Placeholder: Set clipboard text */
@_silgen_name("pasty_clipboard_set_text")
func pasty_clipboard_set_text(_ text: UnsafePointer<CChar>) -> Int32

// MARK: - Errors

enum FFIError: Error {
    case coreInitializationFailed
    case coreShutdownFailed
    case functionNotImplemented
    case invalidString
    case unknown(Int32)

    static func fromCode(_ code: Int32) -> FFIError {
        return .unknown(code)
    }
}
```

---

## Build Artifacts

### Generated C Header (cbindgen output)

**File**: `build/core/include/pasty.h`

```c
/* Auto-generated by cbindgen - DO NOT MODIFY */

#ifndef PASTY_H
#define PASTY_H

#include <stdarg.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>

/* Get Rust core version */
const char *pasty_get_version(void);

/* Initialize Rust core (0 = success) */
int pasty_init(void);

/* Shutdown Rust core (0 = success) */
int pasty_shutdown(void);

/* Free string allocated by Rust */
void pasty_free_string(char *ptr);

/* Get last error message (null if no error) */
const char *pasty_get_last_error(void);

/* Placeholder: Get clipboard text */
char *pasty_clipboard_get_text(void);

/* Placeholder: Set clipboard text */
int pasty_clipboard_set_text(const char *text);

#endif /* PASTY_H */
```

---

## Relationships

```
┌─────────────────────────────────────────────────────────────┐
│                     Swift macOS Layer                       │
│  ┌──────────────┐         ┌──────────────────────────┐     │
│  | MenuBarApp   │────────>| FFIBridge (Swift)        │     │
│  └──────────────┘         └──────────────────────────┘     │
│                                      │                      │
│                                      ▼                      │
└─────────────────────────────────────────────────────────────┘
                    │
                    │ FFI Boundary (C ABI)
                    │ pasty_*() functions
                    ▼
┌─────────────────────────────────────────────────────────────┐
│                       Rust Core                             │
│  ┌──────────────────────────────────────────────────────┐  │
│  │ FFI Exports (core/src/ffi/exports.rs)                │  │
│  │ - pasty_init(), pasty_shutdown()                      │  │
│  │ - pasty_get_version()                                 │  │
│  │ - pasty_free_string()                                 │  │
│  │ - (placeholder clipboard functions)                    │  │
│  └──────────────────────────────────────────────────────┘  │
│                                      │                      │
│                                      ▼                      │
│  ┌──────────────────────────────────────────────────────┐  │
│  │ Models & Services (future implementation)             │  │
│  │ - ClipboardEntry, ClipboardHistory                    │  │
│  │ - EncryptionService (trait)                           │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

---

## Implementation Scope (This Feature)

**Included**:
- ✅ Rust project structure (Cargo.toml, src/ layout)
- ✅ Basic FFI export functions (init, shutdown, version)
- ✅ FFIBridge Swift scaffold
- ✅ Data model definitions (structs, traits - no implementation)
- ✅ Generated C header (via cbindgen)

**Excluded** (future features):
- ❌ Actual clipboard reading/writing
- ❌ ClipboardHistory implementation
- ❌ EncryptionService implementation
- ❌ Menu bar UI implementation
- ❌ Persistence layer

---

## Validation Rules Summary

| Entity | Key Validation | Error Handling |
|--------|----------------|----------------|
| `ClipboardEntry` | Unique ID, valid timestamp, data matches type | Return `Error::InvalidEntry` |
| `ClipboardHistory` | max_entries > 0, enforce retention limits | Return `Error::CapacityExceeded` |
| `EncryptionService` | Empty data encrypts, decrypted data matches original | Return `EncryptionError` variants |
| FFI Functions | Null pointer checks, string ownership clear | Set `pasty_get_last_error()`, return error codes |
| FFIBridge | Wrap all FFI calls, convert errors to Swift `throws` | Throw `FFIError` variants |

---

## Next Steps

1. Implement Rust FFI exports in `core/src/ffi/exports.rs`
2. Generate C header with cbindgen
3. Create Swift FFIBridge wrapper
4. Write unit tests for FFI functions
5. Integrate with build scripts (build-core.sh, build-macos.sh)
