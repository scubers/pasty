//! FFI exports for Pasty core library
//!
//! This module provides C-compatible functions using the C ABI.
//! All functions are prefixed with `pasty_` and follow standard conventions:
//! - Integer returns: 0 = success, negative = error code
//! - Pointer returns: valid pointer on success, NULL on error
//! - Strings returned by Rust must be freed with `pasty_free_string()`

use std::ffi::{CStr, CString};
use std::os::raw::{c_char, c_int};
use std::ptr;

/// Thread-local storage for last error message
use std::cell::RefCell;
use std::thread_local;

thread_local! {
    static LAST_ERROR: RefCell<Option<CString>> = RefCell::new(None);
}

/// Set the last error message (internal helper)
fn set_last_error(message: &str) {
    LAST_ERROR.with(|error| {
        *error.borrow_mut() = CString::new(message).ok();
    });
}

/// Get the Rust core library version string
///
/// # Returns
/// Pointer to null-terminated static version string. Never returns NULL.
///
/// # Memory Management
/// This is a static string - caller MUST NOT free it.
#[no_mangle]
pub extern "C" fn pasty_get_version() -> *const c_char {
    static VERSION: &[u8] = concat!(env!("CARGO_PKG_VERSION"), "\0").as_bytes();
    VERSION.as_ptr() as *const c_char
}

/// Initialize the Rust core library
///
/// Must be called before any other FFI functions (except `pasty_get_version()`)
///
/// # Returns
/// - 0: Success
/// - -1: Initialization failed (check `pasty_get_last_error()`)
///
/// # Side Effects
/// - Allocates internal resources
/// - Initializes logging
/// - Sets up thread-local storage
///
/// # Thread Safety
/// Safe to call multiple times (idempotent)
#[no_mangle]
pub extern "C" fn pasty_init() -> c_int {
    // TODO: Initialize logging, allocate resources
    0  // Success
}

/// Shutdown the Rust core library
///
/// Frees all allocated resources and cleans up
///
/// # Returns
/// - 0: Success
/// - -1: Shutdown failed (check `pasty_get_last_error()`)
///
/// # Side Effects
/// - Frees all allocated resources
/// - Closes log files
/// - Invalidates previously returned pointers
///
/// # Thread Safety
/// Safe to call multiple times (idempotent)
#[no_mangle]
pub extern "C" fn pasty_shutdown() -> c_int {
    // TODO: Free resources, close log files
    0  // Success
}

/// Free a string allocated by Rust
///
/// # Safety
/// Caller must ensure pointer was allocated by Rust and not already freed
///
/// # Arguments
/// * `ptr` - Pointer to string allocated by Rust (can be NULL)
///
/// # Behavior
/// - Safe to pass NULL (no-op)
/// - Undefined behavior if pointer not allocated by Rust
/// - Undefined behavior if pointer already freed
/// - Undefined behavior if pointer points to stack/static data
#[no_mangle]
pub extern "C" fn pasty_free_string(ptr: *mut c_char) {
    if !ptr.is_null() {
        unsafe {
            // Reclaim CString memory
            let _ = CString::from_raw(ptr);
        }
    }
}

/// Get the last error message from the current thread
///
/// # Returns
/// Pointer to error message string, or NULL if no error
///
/// # Memory Management
/// Rust owns the string (thread-local storage)
/// Caller MUST NOT free this string
/// Valid until next FFI call on same thread
///
/// # Thread Safety
/// Thread-local (different threads have different error messages)
#[no_mangle]
pub extern "C" fn pasty_get_last_error() -> *const c_char {
    LAST_ERROR.with(|error| {
        if let Some(msg) = error.borrow().as_ref() {
            msg.as_ptr()
        } else {
            ptr::null()
        }
    })
}

// ========== PLACEHOLDER FUNCTIONS (for future clipboard features) ==========

/// Placeholder: Get current clipboard text
///
/// # Returns
/// NULL if not text content or error occurs
/// Caller must free with `pasty_free_string()` if not NULL
#[no_mangle]
pub extern "C" fn pasty_clipboard_get_text() -> *mut c_char {
    set_last_error("Not implemented yet - use future clipboard feature");
    ptr::null_mut()
}

/// Placeholder: Set clipboard text
///
/// # Arguments
/// * `text` - Null-terminated UTF-8 string to copy to clipboard
///
/// # Returns
/// - 0: Success
/// - -1: Error (check `pasty_get_last_error()`)
#[no_mangle]
pub extern "C" fn pasty_clipboard_set_text(_text: *const c_char) -> c_int {
    set_last_error("Not implemented yet - use future clipboard feature");
    -1
}

/// Placeholder: Add entry to clipboard history
///
/// # Returns
/// - 0: Success
/// - -1: Error (check `pasty_get_last_error()`)
#[no_mangle]
pub extern "C" fn pasty_history_add(
    _timestamp: i64,
    _content_type: u32,
    _data: *const u8,
    _data_len: usize
) -> c_int {
    set_last_error("Not implemented yet - use future clipboard feature");
    -1
}
