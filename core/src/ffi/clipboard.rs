use std::ffi::{CStr, CString};
use std::os::raw::c_char;
use std::ptr;
use std::sync::Mutex;
use std::boxed::Box;

use crate::models::{ClipboardEntry, Content, SourceApplication};
use crate::services::ClipboardStore;
use crate::ffi::types::{FfiContentType, FfiErrorCode};

// Thread-local error storage
thread_local! {
    static LAST_ERROR: Mutex<Option<CString>> = Mutex::new(None);
}

/// FFI representation of a clipboard entry
#[repr(C)]
pub struct FfiClipboardEntry {
    pub id: *const c_char,
    pub content_hash: *const c_char,
    pub content_type: FfiContentType,
    pub timestamp_ms: i64,
    pub text_content: *const c_char,
    pub image_path: *const c_char,
    pub source_bundle_id: *const c_char,
    pub source_app_name: *const c_char,
    pub source_pid: u32,
}

/// Global clipboard store (initialized once)
static CLIPBOARD_STORE: Mutex<Option<ClipboardStore>> = Mutex::new(None);

/// Initialize the clipboard store
///
/// # Arguments
/// * `db_path` - Path to SQLite database file
/// * `storage_path` - Path to image storage directory
///
/// # Returns
/// Error code (0 = success)
#[no_mangle]
pub extern "C" fn pasty_clipboard_init(
    db_path: *const c_char,
    storage_path: *const c_char,
) -> FfiErrorCode {
    if db_path.is_null() || storage_path.is_null() {
        set_error("Null path argument provided");
        return FfiErrorCode::InvalidArgument;
    }

    let db_path = unsafe { CStr::from_ptr(db_path) }.to_str().unwrap_or("");
    let storage_path = unsafe { CStr::from_ptr(storage_path) }.to_str().unwrap_or("");

    match ClipboardStore::new(db_path, storage_path) {
        Ok(store) => {
            *CLIPBOARD_STORE.lock().unwrap() = Some(store);
            FfiErrorCode::Success
        }
        Err(e) => {
            set_error(&e.to_string());
            FfiErrorCode::DatabaseError
        }
    }
}

/// Store a text clipboard entry
///
/// # Arguments
/// * `text` - Text content (UTF-8 string)
/// * `source_bundle_id` - Source app bundle identifier
/// * `source_app_name` - Source app display name
/// * `source_pid` - Source app process ID
///
/// # Returns
/// Pointer to FfiClipboardEntry (must be freed with pasty_clipboard_entry_free), or null on error
#[no_mangle]
pub extern "C" fn pasty_clipboard_store_text(
    text: *const c_char,
    source_bundle_id: *const c_char,
    source_app_name: *const c_char,
    source_pid: u32,
) -> *mut FfiClipboardEntry {
    if text.is_null() || source_bundle_id.is_null() || source_app_name.is_null() {
        set_error("Null pointer argument");
        return ptr::null_mut();
    }

    let text = unsafe { CStr::from_ptr(text) }.to_str().unwrap_or("");
    let bundle_id = unsafe { CStr::from_ptr(source_bundle_id) }.to_str().unwrap_or("");
    let app_name = unsafe { CStr::from_ptr(source_app_name) }.to_str().unwrap_or("");

    let source = SourceApplication::new(
        bundle_id.to_string(),
        app_name.to_string(),
        source_pid,
    );

    let store_guard = CLIPBOARD_STORE.lock().unwrap();
    let store = match store_guard.as_ref() {
        Some(s) => s,
        None => {
            set_error("Clipboard store not initialized. Call pasty_init first.");
            return ptr::null_mut();
        }
    };

    match store.store_text(text, source) {
        Ok(entry) => Box::into_raw(Box::new(entry_to_ffi(entry))),
        Err(e) => {
            set_error(&e.to_string());
            ptr::null_mut()
        }
    }
}

/// Store an image clipboard entry
///
/// # Arguments
/// * `image_data` - Pointer to image bytes
/// * `image_len` - Length of image data
/// * `format` - Image format (e.g., "png", "jpg")
/// * `source_bundle_id` - Source app bundle identifier
/// * `source_app_name` - Source app display name
/// * `source_pid` - Source app process ID
///
/// # Returns
/// Pointer to FfiClipboardEntry (must be freed with pasty_clipboard_entry_free), or null on error
#[no_mangle]
pub extern "C" fn pasty_clipboard_store_image(
    image_data: *const u8,
    image_len: usize,
    format: *const c_char,
    source_bundle_id: *const c_char,
    source_app_name: *const c_char,
    source_pid: u32,
) -> *mut FfiClipboardEntry {
    if image_data.is_null() || format.is_null() || source_bundle_id.is_null() || source_app_name.is_null() {
        set_error("Null pointer argument");
        return ptr::null_mut();
    }

    let format = unsafe { CStr::from_ptr(format) }.to_str().unwrap_or("");
    let bundle_id = unsafe { CStr::from_ptr(source_bundle_id) }.to_str().unwrap_or("");
    let app_name = unsafe { CStr::from_ptr(source_app_name) }.to_str().unwrap_or("");

    let data = unsafe { std::slice::from_raw_parts(image_data, image_len) };

    let source = SourceApplication::new(
        bundle_id.to_string(),
        app_name.to_string(),
        source_pid,
    );

    let store_guard = CLIPBOARD_STORE.lock().unwrap();
    let store = match store_guard.as_ref() {
        Some(s) => s,
        None => {
            set_error("Clipboard store not initialized. Call pasty_init first.");
            return ptr::null_mut();
        }
    };

    match store.store_image(data, format, source) {
        Ok(entry) => Box::into_raw(Box::new(entry_to_ffi(entry))),
        Err(e) => {
            set_error(&e.to_string());
            ptr::null_mut()
        }
    }
}

/// Free a clipboard entry
///
/// # Arguments
/// * `entry` - Pointer to FfiClipboardEntry to free
#[no_mangle]
pub extern "C" fn pasty_clipboard_entry_free(entry: *mut FfiClipboardEntry) {
    if entry.is_null() {
        return;
    }

    unsafe {
        let entry_ref = &*entry;

        // Free all C strings
        if !entry_ref.id.is_null() {
            let _ = CString::from_raw(entry_ref.id as *mut c_char);
        }
        if !entry_ref.content_hash.is_null() {
            let _ = CString::from_raw(entry_ref.content_hash as *mut c_char);
        }
        if !entry_ref.text_content.is_null() {
            let _ = CString::from_raw(entry_ref.text_content as *mut c_char);
        }
        if !entry_ref.image_path.is_null() {
            let _ = CString::from_raw(entry_ref.image_path as *mut c_char);
        }
        if !entry_ref.source_bundle_id.is_null() {
            let _ = CString::from_raw(entry_ref.source_bundle_id as *mut c_char);
        }
        if !entry_ref.source_app_name.is_null() {
            let _ = CString::from_raw(entry_ref.source_app_name as *mut c_char);
        }

        // Free the struct itself
        let _ = Box::from_raw(entry);
    }
}

/// Get the last error message
///
/// # Returns
/// Pointer to error string (valid until next error), or null if no error
#[no_mangle]
pub extern "C" fn pasty_get_last_error() -> *const c_char {
    LAST_ERROR.with(|error| {
        let error_guard = error.lock().unwrap();
        match error_guard.as_ref() {
            Some(msg) => msg.as_ptr(),
            None => ptr::null(),
        }
    })
}

/// Set thread-local error message
fn set_error(message: &str) {
    LAST_ERROR.with(|error| {
        *error.lock().unwrap() = Some(CString::new(message).unwrap_or_default());
    });
}

/// Convert ClipboardEntry to FFI representation
fn entry_to_ffi(entry: ClipboardEntry) -> FfiClipboardEntry {
    FfiClipboardEntry {
        id: CString::new(entry.id.to_string()).unwrap().into_raw(),
        content_hash: CString::new(entry.content_hash).unwrap().into_raw(),
        content_type: entry.content_type.into(),
        timestamp_ms: entry.timestamp.timestamp_millis(),
        text_content: match &entry.content {
            Content::Text(text) => CString::new(text.clone()).unwrap().into_raw(),
            Content::Image(_) => ptr::null(),
        },
        image_path: match &entry.content {
            Content::Text(_) => ptr::null(),
            Content::Image(img) => CString::new(img.path.clone()).unwrap().into_raw(),
        },
        source_bundle_id: CString::new(entry.source.bundle_id).unwrap().into_raw(),
        source_app_name: CString::new(entry.source.app_name).unwrap().into_raw(),
        source_pid: entry.source.pid,
    }
}

// MARK: Backward Compatibility Functions (Feature 001)

/// Get the library version string
#[no_mangle]
pub extern "C" fn pasty_get_version() -> *mut c_char {
    let version = CString::new("0.2.0-clipboard-history").unwrap();
    version.into_raw()
}

/// Initialize with default paths (for backward compatibility with Feature 001)
#[no_mangle]
pub extern "C" fn pasty_init() -> i32 {
    // Use default paths in ~/Library/Application Support/Pasty
    let mut path = std::path::PathBuf::new();
    if let Some(home) = std::env::var("HOME").ok() {
        path.push(home);
        path.push("Library");
        path.push("Application Support");
        path.push("Pasty");
    }

    let db_path = path.join("clipboard.db");
    let storage_path = path.join("images");

    let db_cstr = CString::new(db_path.to_str().unwrap_or_default()).unwrap();
    let storage_cstr = CString::new(storage_path.to_str().unwrap_or_default()).unwrap();

    let result = pasty_clipboard_init(db_cstr.as_ptr(), storage_cstr.as_ptr());

    match result {
        FfiErrorCode::Success => 0,
        _ => -1,
    }
}

/// Shutdown the clipboard store
#[no_mangle]
pub extern "C" fn pasty_shutdown() -> FfiErrorCode {
    // Clear the global store
    let mut store_guard = CLIPBOARD_STORE.lock().unwrap();
    *store_guard = None;
    FfiErrorCode::Success
}
