//! Pasty Core - Cross-platform clipboard library
//!
//! This library provides platform-agnostic business logic for clipboard management,
//! including data models, services, and FFI exports.

pub mod models;
pub mod services;
pub mod ffi;

// Re-export public FFI functions for clipboard history
pub use ffi::clipboard::{
    pasty_clipboard_init,
    pasty_clipboard_store_text,
    pasty_clipboard_store_image,
    pasty_clipboard_entry_free,
    pasty_get_last_error,
    pasty_get_clipboard_history,
    pasty_get_entry_by_id,
    pasty_list_free,
    // Backward compatibility (Feature 001)
    pasty_init,
    pasty_get_version,
    pasty_shutdown,
};

// Re-export FFI types
pub use ffi::types::{
    FfiContentType,
    FfiErrorCode,
};
pub use ffi::clipboard::{FfiClipboardEntry, FfiClipboardEntryList};

// Note: Tests are in the tests/ directory, not inline

