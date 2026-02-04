//! Contract tests for clipboard storage FFI
//!
//! T057-T059: Tests for FFI store functions, duplicate detection, and memory management

use std::ffi::CString;
use std::ptr;
use tempfile::TempDir;
use pasty_core::*;

/// T057: Contract test for pasty_clipboard_store_text FFI
#[test]
fn test_clipboard_init_and_store_text() {
    let temp_dir = TempDir::new().unwrap();
    let db_path = temp_dir.path().join("test.db");
    let storage_path = temp_dir.path().join("images");

    let db_cstring = CString::new(db_path.to_str().unwrap()).unwrap();
    let storage_cstring = CString::new(storage_path.to_str().unwrap()).unwrap();

    // Initialize with paths
    let result = pasty_clipboard_init(db_cstring.as_ptr(), storage_cstring.as_ptr());
    assert_eq!(result, FfiErrorCode::Success);

    // Store text
    let text = CString::new("Hello, World!").unwrap();
    let bundle_id = CString::new("com.test.App").unwrap();
    let app_name = CString::new("TestApp").unwrap();

    let entry = pasty_clipboard_store_text(
        text.as_ptr(),
        bundle_id.as_ptr(),
        app_name.as_ptr(),
        1234
    );

    assert!(!entry.is_null(), "Should return non-null entry pointer");

    // Verify entry fields
    unsafe {
        assert!(!(*entry).id.is_null(), "Entry should have ID");
        assert!(!(*entry).content_hash.is_null(), "Entry should have hash");
        assert!(!(*entry).text_content.is_null(), "Entry should have text content");

        let text_content = std::ffi::CStr::from_ptr((*entry).text_content);
        assert_eq!(text_content.to_str().unwrap(), "Hello, World!");

        let bundle_id_str = std::ffi::CStr::from_ptr((*entry).source_bundle_id);
        assert_eq!(bundle_id_str.to_str().unwrap(), "com.test.App");

        let app_name_str = std::ffi::CStr::from_ptr((*entry).source_app_name);
        assert_eq!(app_name_str.to_str().unwrap(), "TestApp");

        assert_eq!((*entry).source_pid, 1234);
    }

    // Free entry
    pasty_clipboard_entry_free(entry);
}

/// T057: Contract test for storing image via FFI
#[test]
fn test_clipboard_store_image() {
    let temp_dir = TempDir::new().unwrap();
    let db_path = temp_dir.path().join("test.db");
    let storage_path = temp_dir.path().join("images");

    let db_cstring = CString::new(db_path.to_str().unwrap()).unwrap();
    let storage_cstring = CString::new(storage_path.to_str().unwrap()).unwrap();

    // Initialize
    let result = pasty_clipboard_init(db_cstring.as_ptr(), storage_cstring.as_ptr());
    assert_eq!(result, FfiErrorCode::Success);

    // Store image
    let image_data = vec![0x89, 0x50, 0x4E, 0x47]; // PNG header
    let format = CString::new("png").unwrap();
    let bundle_id = CString::new("com.test.App").unwrap();
    let app_name = CString::new("TestApp").unwrap();

    let entry = pasty_clipboard_store_image(
        image_data.as_ptr(),
        image_data.len(),
        format.as_ptr(),
        bundle_id.as_ptr(),
        app_name.as_ptr(),
        5678
    );

    assert!(!entry.is_null(), "Should return non-null entry pointer");

    // Verify entry has image path
    unsafe {
        assert!(!(*entry).id.is_null());
        assert!(!(*entry).content_hash.is_null());
        assert!(!(*entry).image_path.is_null());

        let image_path = std::ffi::CStr::from_ptr((*entry).image_path);
        let path_str = image_path.to_str().unwrap();
        assert!(path_str.contains(".png"), "Image path should contain PNG extension");

        assert_eq!((*entry).source_pid, 5678);
    }

    // Free entry
    pasty_clipboard_entry_free(entry);
}

/// T058: Contract test for duplicate detection via FFI
#[test]
fn test_store_text_duplicate_detection() {
    let temp_dir = TempDir::new().unwrap();
    let db_path = temp_dir.path().join("test.db");
    let storage_path = temp_dir.path().join("images");

    let db_cstring = CString::new(db_path.to_str().unwrap()).unwrap();
    let storage_cstring = CString::new(storage_path.to_str().unwrap()).unwrap();

    // Initialize
    let result = pasty_clipboard_init(db_cstring.as_ptr(), storage_cstring.as_ptr());
    assert_eq!(result, FfiErrorCode::Success);

    // Store same text twice
    let text = CString::new("Duplicate text").unwrap();
    let bundle_id = CString::new("com.test.App").unwrap();
    let app_name = CString::new("TestApp").unwrap();

    let entry1 = pasty_clipboard_store_text(
        text.as_ptr(),
        bundle_id.as_ptr(),
        app_name.as_ptr(),
        1234
    );

    let entry2 = pasty_clipboard_store_text(
        text.as_ptr(),
        bundle_id.as_ptr(),
        app_name.as_ptr(),
        1234
    );

    assert!(!entry1.is_null(), "First entry should not be null");
    assert!(!entry2.is_null(), "Second entry should not be null");

    // Both should have same hash (duplicate detection)
    unsafe {
        let hash1 = std::ffi::CStr::from_ptr((*entry1).content_hash);
        let hash2 = std::ffi::CStr::from_ptr((*entry2).content_hash);
        assert_eq!(hash1.to_str().unwrap(), hash2.to_str().unwrap(),
                   "Duplicates should have same content hash");

        // IDs should be the same (same entry)
        let id1 = std::ffi::CStr::from_ptr((*entry1).id);
        let id2 = std::ffi::CStr::from_ptr((*entry2).id);
        assert_eq!(id1.to_str().unwrap(), id2.to_str().unwrap(),
                   "Duplicates should return same entry ID");
    }

    // Free entries
    pasty_clipboard_entry_free(entry1);
    pasty_clipboard_entry_free(entry2);
}

/// T058: Contract test for image duplicate detection
#[test]
fn test_store_image_duplicate_detection() {
    let temp_dir = TempDir::new().unwrap();
    let db_path = temp_dir.path().join("test.db");
    let storage_path = temp_dir.path().join("images");

    let db_cstring = CString::new(db_path.to_str().unwrap()).unwrap();
    let storage_cstring = CString::new(storage_path.to_str().unwrap()).unwrap();

    // Initialize
    let result = pasty_clipboard_init(db_cstring.as_ptr(), storage_cstring.as_ptr());
    assert_eq!(result, FfiErrorCode::Success);

    // Store same image twice
    let image_data = vec![1, 2, 3, 4, 5];
    let format = CString::new("png").unwrap();
    let bundle_id = CString::new("com.test.App").unwrap();
    let app_name = CString::new("TestApp").unwrap();

    let entry1 = pasty_clipboard_store_image(
        image_data.as_ptr(),
        image_data.len(),
        format.as_ptr(),
        bundle_id.as_ptr(),
        app_name.as_ptr(),
        1234
    );

    let entry2 = pasty_clipboard_store_image(
        image_data.as_ptr(),
        image_data.len(),
        format.as_ptr(),
        bundle_id.as_ptr(),
        app_name.as_ptr(),
        1234
    );

    assert!(!entry1.is_null());
    assert!(!entry2.is_null());

    // Both should have same hash
    unsafe {
        let hash1 = std::ffi::CStr::from_ptr((*entry1).content_hash);
        let hash2 = std::ffi::CStr::from_ptr((*entry2).content_hash);
        assert_eq!(hash1.to_str().unwrap(), hash2.to_str().unwrap(),
                   "Duplicate images should have same hash");
    }

    // Free entries
    pasty_clipboard_entry_free(entry1);
    pasty_clipboard_entry_free(entry2);
}

/// T059: Contract test for memory management (entry_free)
#[test]
fn test_entry_free_memory_management() {
    let temp_dir = TempDir::new().unwrap();
    let db_path = temp_dir.path().join("test.db");
    let storage_path = temp_dir.path().join("images");

    let db_cstring = CString::new(db_path.to_str().unwrap()).unwrap();
    let storage_cstring = CString::new(storage_path.to_str().unwrap()).unwrap();

    // Initialize
    let result = pasty_clipboard_init(db_cstring.as_ptr(), storage_cstring.as_ptr());
    assert_eq!(result, FfiErrorCode::Success);

    // Store text
    let text = CString::new("Test memory management").unwrap();
    let bundle_id = CString::new("com.test.App").unwrap();
    let app_name = CString::new("TestApp").unwrap();

    let entry = pasty_clipboard_store_text(
        text.as_ptr(),
        bundle_id.as_ptr(),
        app_name.as_ptr(),
        1234
    );

    assert!(!entry.is_null());

    // Free the entry - should not crash
    pasty_clipboard_entry_free(entry);

    // Double free should not crash (function should handle null pointer)
    pasty_clipboard_entry_free(ptr::null_mut());
}

/// T059: Contract test for null entry free
#[test]
fn test_entry_free_handles_null() {
    // Should not crash when freeing null pointer
    pasty_clipboard_entry_free(ptr::null_mut());
}

/// T057: Contract test for FFI error handling
#[test]
fn test_init_with_null_arguments() {
    // Initialize with null arguments should return error
    let result = pasty_clipboard_init(ptr::null(), ptr::null());
    assert_eq!(result, FfiErrorCode::InvalidArgument);
}

/// T057: Contract test for store text with null arguments
#[test]
fn test_store_text_with_null_arguments() {
    let temp_dir = TempDir::new().unwrap();
    let db_path = temp_dir.path().join("test.db");
    let storage_path = temp_dir.path().join("images");

    let db_cstring = CString::new(db_path.to_str().unwrap()).unwrap();
    let storage_cstring = CString::new(storage_path.to_str().unwrap()).unwrap();

    // Initialize first
    let init_result = pasty_clipboard_init(db_cstring.as_ptr(), storage_cstring.as_ptr());
    assert_eq!(init_result, FfiErrorCode::Success);

    // Try to store with null text
    let entry = pasty_clipboard_store_text(
        ptr::null(),
        ptr::null(),
        ptr::null(),
        1234
    );

    assert!(entry.is_null(), "Should return null for null arguments");
}

/// T057: Contract test for get_last_error
#[test]
fn test_get_last_error() {
    // Trigger an error
    let _ = pasty_clipboard_init(ptr::null(), ptr::null());

    // Get error message
    let error_ptr = pasty_get_last_error();
    assert!(!error_ptr.is_null(), "Should return error message");

    unsafe {
        let error_msg = std::ffi::CStr::from_ptr(error_ptr);
        let msg_str = error_msg.to_str().unwrap();
        assert!(!msg_str.is_empty(), "Error message should not be empty");
    }
}
