//! FFI unit tests for Pasty core library

use std::ffi::{CStr, CString};
use std::os::raw::{c_char, c_int};

// Link to the FFI exports
#[link(name = "pasty_core", kind = "static")]
extern "C" {
    fn pasty_get_version() -> *const c_char;
    fn pasty_init() -> c_int;
    fn pasty_shutdown() -> c_int;
    fn pasty_free_string(ptr: *mut c_char);
    fn pasty_get_last_error() -> *const c_char;
}
