//! Contract tests for clipboard retrieval FFI
//!
//! T088-T090: Tests for FFI retrieve functions and list memory management

use std::ffi::CString;
use std::ptr;
use tempfile::TempDir;
use pasty_core::*;

/// T088: Contract test for pasty_get_clipboard_history FFI
#[test]
fn test_get_clipboard_history_returns_all_entries() {
    // Shutdown any existing store
    let _ = pasty_shutdown();

    let temp_dir = TempDir::new().unwrap();
    let db_path = temp_dir.path().join("test_all_entries.db");
    let storage_path = temp_dir.path().join("images_all_entries");

    let db_cstring = CString::new(db_path.to_str().unwrap()).unwrap();
    let storage_cstring = CString::new(storage_path.to_str().unwrap()).unwrap();

    // Initialize
    let result = pasty_clipboard_init(db_cstring.as_ptr(), storage_cstring.as_ptr());
    assert_eq!(result, FfiErrorCode::Success);

    // Store multiple text entries
    let text1 = CString::new("First entry").unwrap();
    let text2 = CString::new("Second entry").unwrap();
    let text3 = CString::new("Third entry").unwrap();
    let bundle_id = CString::new("com.test.App").unwrap();
    let app_name = CString::new("TestApp").unwrap();

    let _entry1 = pasty_clipboard_store_text(
        text1.as_ptr(),
        bundle_id.as_ptr(),
        app_name.as_ptr(),
        1234
    );

    std::thread::sleep(std::time::Duration::from_millis(10));

    let _entry2 = pasty_clipboard_store_text(
        text2.as_ptr(),
        bundle_id.as_ptr(),
        app_name.as_ptr(),
        1234
    );

    std::thread::sleep(std::time::Duration::from_millis(10));

    let _entry3 = pasty_clipboard_store_text(
        text3.as_ptr(),
        bundle_id.as_ptr(),
        app_name.as_ptr(),
        1234
    );

    // Get history with limit=10, offset=0
    let list_ptr = pasty_get_clipboard_history(10, 0);

    assert!(!list_ptr.is_null(), "Should return non-null list pointer");

    unsafe {
        // Verify list fields
        let count = (*list_ptr).count;
        assert_eq!(count, 3, "Should return 3 entries");

        // Verify entries are valid
        let entries = (*list_ptr).entries;
        assert!(!entries.is_null(), "Entries pointer should not be null");

        // Verify first entry content
        let first_entry = *entries;
        assert!(!(*first_entry).text_content.is_null());
        let text_content = std::ffi::CStr::from_ptr((*first_entry).text_content);
        assert_eq!(text_content.to_str().unwrap(), "Third entry", "Most recent entry should be first");
    }

    // Free list
    pasty_list_free(list_ptr);
}

/// T088: Contract test for pasty_get_clipboard_history with pagination
#[test]
fn test_get_clipboard_history_with_pagination() {
    // Shutdown any existing store
    let _ = pasty_shutdown();

    let temp_dir = TempDir::new().unwrap();
    let db_path = temp_dir.path().join("test_pagination.db");
    let storage_path = temp_dir.path().join("images_pagination");

    let db_cstring = CString::new(db_path.to_str().unwrap()).unwrap();
    let storage_cstring = CString::new(storage_path.to_str().unwrap()).unwrap();

    // Initialize
    let result = pasty_clipboard_init(db_cstring.as_ptr(), storage_cstring.as_ptr());
    assert_eq!(result, FfiErrorCode::Success);

    // Store 5 entries
    let bundle_id = CString::new("com.test.App").unwrap();
    let app_name = CString::new("TestApp").unwrap();

    for i in 0..5 {
        let text = CString::new(format!("Entry {}", i)).unwrap();
        let _entry = pasty_clipboard_store_text(
            text.as_ptr(),
            bundle_id.as_ptr(),
            app_name.as_ptr(),
            1234
        );
        std::thread::sleep(std::time::Duration::from_millis(5));
    }

    // Get first page (limit=2, offset=0)
    let page1 = pasty_get_clipboard_history(2, 0);
    assert!(!page1.is_null());

    unsafe {
        assert_eq!((*page1).count, 2, "First page should have 2 entries");
    }

    pasty_list_free(page1);

    // Get second page (limit=2, offset=2)
    let page2 = pasty_get_clipboard_history(2, 2);
    assert!(!page2.is_null());

    unsafe {
        assert_eq!((*page2).count, 2, "Second page should have 2 entries");
    }

    pasty_list_free(page2);

    // Get third page (limit=2, offset=4) - should have 1 entry
    let page3 = pasty_get_clipboard_history(2, 4);
    assert!(!page3.is_null());

    unsafe {
        assert_eq!((*page3).count, 1, "Third page should have 1 entry");
    }

    pasty_list_free(page3);
}

/// T089: Contract test for pasty_get_entry_by_id FFI
#[test]
fn test_get_entry_by_id() {
    // Shutdown any existing store
    let _ = pasty_shutdown();

    let temp_dir = TempDir::new().unwrap();
    let db_path = temp_dir.path().join("test_by_id.db");
    let storage_path = temp_dir.path().join("images_by_id");

    let db_cstring = CString::new(db_path.to_str().unwrap()).unwrap();
    let storage_cstring = CString::new(storage_path.to_str().unwrap()).unwrap();

    // Initialize
    let result = pasty_clipboard_init(db_cstring.as_ptr(), storage_cstring.as_ptr());
    assert_eq!(result, FfiErrorCode::Success);

    // Store an entry
    let text = CString::new("Test content for ID retrieval").unwrap();
    let bundle_id = CString::new("com.test.App").unwrap();
    let app_name = CString::new("TestApp").unwrap();

    let stored_entry = pasty_clipboard_store_text(
        text.as_ptr(),
        bundle_id.as_ptr(),
        app_name.as_ptr(),
        1234
    );

    assert!(!stored_entry.is_null());

    // Get the ID from stored entry
    let entry_id: CString;
    unsafe {
        let id_ptr = (*stored_entry).id;
        // Copy the string without taking ownership
        let id_str = std::ffi::CStr::from_ptr(id_ptr);
        entry_id = CString::new(id_str.to_bytes()).unwrap();
    }

    // Retrieve entry by ID
    let retrieved_entry = pasty_get_entry_by_id(entry_id.as_ptr());

    assert!(!retrieved_entry.is_null(), "Should retrieve entry by ID");

    unsafe {
        let text_content = std::ffi::CStr::from_ptr((*retrieved_entry).text_content);
        assert_eq!(
            text_content.to_str().unwrap(),
            "Test content for ID retrieval",
            "Retrieved content should match stored content"
        );
    }

    // Free entries
    pasty_clipboard_entry_free(stored_entry);
    pasty_clipboard_entry_free(retrieved_entry);
}

/// T089: Contract test for pasty_get_entry_by_id with non-existent ID
#[test]
fn test_get_entry_by_nonexistent_id_returns_null() {
    // Shutdown any existing store
    let _ = pasty_shutdown();

    let temp_dir = TempDir::new().unwrap();
    let db_path = temp_dir.path().join("test_nonexistent_id.db");
    let storage_path = temp_dir.path().join("images_nonexistent_id");

    let db_cstring = CString::new(db_path.to_str().unwrap()).unwrap();
    let storage_cstring = CString::new(storage_path.to_str().unwrap()).unwrap();

    // Initialize
    let result = pasty_clipboard_init(db_cstring.as_ptr(), storage_cstring.as_ptr());
    assert_eq!(result, FfiErrorCode::Success);

    // Try to retrieve with fake UUID
    let fake_id = CString::new("00000000-0000-0000-0000-000000000000").unwrap();
    let entry = pasty_get_entry_by_id(fake_id.as_ptr());

    assert!(entry.is_null(), "Should return null for non-existent ID");
}

/// T090: Contract test for list accessors and memory management
#[test]
fn test_list_free_memory_management() {
    // Shutdown any existing store
    let _ = pasty_shutdown();

    let temp_dir = TempDir::new().unwrap();
    let db_path = temp_dir.path().join("test_list_free.db");
    let storage_path = temp_dir.path().join("images_list_free");

    let db_cstring = CString::new(db_path.to_str().unwrap()).unwrap();
    let storage_cstring = CString::new(storage_path.to_str().unwrap()).unwrap();

    // Initialize
    let result = pasty_clipboard_init(db_cstring.as_ptr(), storage_cstring.as_ptr());
    assert_eq!(result, FfiErrorCode::Success);

    // Store an entry
    let text = CString::new("Test list free").unwrap();
    let bundle_id = CString::new("com.test.App").unwrap();
    let app_name = CString::new("TestApp").unwrap();

    let _entry = pasty_clipboard_store_text(
        text.as_ptr(),
        bundle_id.as_ptr(),
        app_name.as_ptr(),
        1234
    );

    // Get history
    let list = pasty_get_clipboard_history(10, 0);
    assert!(!list.is_null());

    // Free list - should not crash
    pasty_list_free(list);

    // Double free should not crash (function should handle null pointer)
    pasty_list_free(ptr::null_mut());
}

/// T090: Contract test for list_free handles null
#[test]
fn test_list_free_handles_null() {
    // Should not crash when freeing null pointer
    pasty_list_free(ptr::null_mut());
}
