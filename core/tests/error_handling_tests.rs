//! Error handling tests for FFI functions

use std::ffi::CStr;

// Link to the FFI exports
#[link(name = "pasty_core", kind = "static")]
extern "C" {
    fn pasty_init() -> i32;
    fn pasty_shutdown() -> i32;
    fn pasty_get_last_error() -> *const i8;
    fn pasty_clipboard_get_text() -> *mut i8;
    fn pasty_clipboard_set_text(text: *const i8) -> i32;
}
