//! Contract tests for clipboard storage FFI

use std::ffi::CString;
use std::path::PathBuf;
use tempfile::TempDir;

// Link to pasty core library
#[path = "../../core/src/ffi/clipboard.rs"]
mod clipboard;

use clipboard::*;

#[test]
fn test_init_and_store_text() {
    let temp_dir = TempDir::new().unwrap();
    let db_path = temp_dir.path().join("test.db");
    let storage_path = temp_dir.path().join("images");

    let db_cstring = CString::new(db_path.to_str().unwrap()).unwrap();
    let storage_cstring = CString::new(storage_path.to_str().unwrap()).unwrap();

    // Initialize
    let result = pasty_init(db_cstring.as_ptr(), storage_cstring.as_ptr());
    assert_eq!(result, FfiErrorCode::Success);

    // Store text
    let text = CString::new("Hello, World!").unwrap();
    let bundle_id = CString::new("com.test.App").unwrap();
    let app_name = CString::new("TestApp").unwrap();

    let entry = pasty_store_text(
        text.as_ptr(),
        bundle_id.as_ptr(),
        app_name.as_ptr(),
        1234
    );

    assert!(!entry.is_null());

    // Free entry
    pasty_entry_free(entry);
}

#[test]
fn test_store_text_deduplication() {
    let temp_dir = TempDir::new().unwrap();
    let db_path = temp_dir.path().join("test.db");
    let storage_path = temp_dir.path().join("images");

    let db_cstring = CString::new(db_path.to_str().unwrap()).unwrap();
    let storage_cstring = CString::new(storage_path.to_str().unwrap()).unwrap();

    // Initialize
    let result = pasty_init(db_cstring.as_ptr(), storage_cstring.as_ptr());
    assert_eq!(result, FfiErrorCode::Success);

    // Store same text twice
    let text = CString::new("Duplicate text").unwrap();
    let bundle_id = CString::new("com.test.App").unwrap();
    let app_name = CString::new("TestApp").unwrap();

    let entry1 = pasty_store_text(
        text.as_ptr(),
        bundle_id.as_ptr(),
        app_name.as_ptr(),
        1234
    );

    let entry2 = pasty_store_text(
        text.as_ptr(),
        bundle_id.as_ptr(),
        app_name.as_ptr(),
        1234
    );

    assert!(!entry1.is_null());
    assert!(!entry2.is_null());

    // Both should have same hash (content hash field)
    unsafe {
        let hash1 = std::ffi::CStr::from_ptr((*entry1).content_hash);
        let hash2 = std::ffi::CStr::from_ptr((*entry2).content_hash);
        assert_eq!(hash1.to_str().unwrap(), hash2.to_str().unwrap());
    }

    // Free entries
    pasty_entry_free(entry1);
    pasty_entry_free(entry2);
}
