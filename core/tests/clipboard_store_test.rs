//! Unit tests for clipboard store service
//!
//! T048: Tests for duplicate detection
//! T084-T087: Tests for clipboard history retrieval

use pasty_core::services::clipboard_store::ClipboardStore;
use pasty_core::models::ContentType;
use pasty_core::models::SourceApplication;
use tempfile::TempDir;

#[test]
fn test_store_text_detects_duplicates() {
    let temp_dir = TempDir::new().unwrap();
    let db_path = temp_dir.path().join("test.db");
    let storage_dir = temp_dir.path().join("images");

    let store = ClipboardStore::new(&db_path, &storage_dir).unwrap();
    let source = SourceApplication::new("com.test.App".to_string(), "TestApp".to_string(), 1234);

    // Store same text twice
    let entry1 = store.store_text("Duplicate text", source.clone()).unwrap();
    let entry2 = store.store_text("Duplicate text", source).unwrap();

    // Should have same hash
    assert_eq!(
        entry1.content_hash, entry2.content_hash,
        "Duplicate text should produce same hash"
    );

    // Should be the same entry ID
    assert_eq!(
        entry1.id, entry2.id,
        "Should return same entry for duplicates"
    );
}

#[test]
fn test_store_image_detects_duplicates() {
    let temp_dir = TempDir::new().unwrap();
    let db_path = temp_dir.path().join("test.db");
    let storage_dir = temp_dir.path().join("images");

    let store = ClipboardStore::new(&db_path, &storage_dir).unwrap();
    let source = SourceApplication::new("com.test.App".to_string(), "TestApp".to_string(), 1234);

    let image_data = vec![1, 2, 3, 4, 5];

    // Store same image twice
    let entry1 = store.store_image(&image_data, "png", source.clone()).unwrap();
    let entry2 = store.store_image(&image_data, "png", source).unwrap();

    // Should have same hash
    assert_eq!(
        entry1.content_hash, entry2.content_hash,
        "Duplicate image should produce same hash"
    );

    // Should be the same entry ID
    assert_eq!(
        entry1.id, entry2.id,
        "Should return same entry for duplicates"
    );
}

#[test]
fn test_different_text_produces_different_entries() {
    let temp_dir = TempDir::new().unwrap();
    let db_path = temp_dir.path().join("test.db");
    let storage_dir = temp_dir.path().join("images");

    let store = ClipboardStore::new(&db_path, &storage_dir).unwrap();
    let source = SourceApplication::new("com.test.App".to_string(), "TestApp".to_string(), 1234);

    let entry1 = store.store_text("First text", source.clone()).unwrap();
    let entry2 = store.store_text("Second text", source).unwrap();

    assert_ne!(
        entry1.content_hash, entry2.content_hash,
        "Different text should produce different hashes"
    );

    assert_ne!(
        entry1.id, entry2.id,
        "Different text should create different entries"
    );
}

#[test]
fn test_text_with_whitespace_is_duplicate() {
    let temp_dir = TempDir::new().unwrap();
    let db_path = temp_dir.path().join("test.db");
    let storage_dir = temp_dir.path().join("images");

    let store = ClipboardStore::new(&db_path, &storage_dir).unwrap();
    let source = SourceApplication::new("com.test.App".to_string(), "TestApp".to_string(), 1234);

    // Store text with different whitespace - should be detected as duplicate
    let entry1 = store.store_text("  Test text  ", source.clone()).unwrap();
    let entry2 = store.store_text("Test text", source).unwrap();

    assert_eq!(
        entry1.content_hash, entry2.content_hash,
        "Text with different whitespace should be detected as duplicate"
    );
}

#[test]
fn test_entry_exists_returns_true_for_stored_entry() {
    let temp_dir = TempDir::new().unwrap();
    let db_path = temp_dir.path().join("test.db");
    let storage_dir = temp_dir.path().join("images");

    let store = ClipboardStore::new(&db_path, &storage_dir).unwrap();
    let source = SourceApplication::new("com.test.App".to_string(), "TestApp".to_string(), 1234);

    let entry = store.store_text("Test", source).unwrap();

    assert!(
        store.entry_exists(&entry.content_hash).unwrap(),
        "entry_exists should return true for stored entry"
    );
}

#[test]
fn test_entry_exists_returns_false_for_nonexistent() {
    let temp_dir = TempDir::new().unwrap();
    let db_path = temp_dir.path().join("test.db");
    let storage_dir = temp_dir.path().join("images");

    let store = ClipboardStore::new(&db_path, &storage_dir).unwrap();

    assert!(
        !store.entry_exists("nonexistent_hash").unwrap(),
        "entry_exists should return false for nonexistent entry"
    );
}

#[test]
fn test_get_entry_by_hash_returns_stored_entry() {
    let temp_dir = TempDir::new().unwrap();
    let db_path = temp_dir.path().join("test.db");
    let storage_dir = temp_dir.path().join("images");

    let store = ClipboardStore::new(&db_path, &storage_dir).unwrap();
    let source = SourceApplication::new("com.test.App".to_string(), "TestApp".to_string(), 1234);

    let stored = store.store_text("Test content", source).unwrap();
    let retrieved = store.get_entry_by_hash(&stored.content_hash).unwrap();

    assert!(
        retrieved.is_some(),
        "Should retrieve stored entry"
    );

    let retrieved = retrieved.unwrap();
    assert_eq!(
        retrieved.id, stored.id,
        "Retrieved entry should match stored entry"
    );
}

#[test]
fn test_duplicate_updates_latest_copy_time() {
    let temp_dir = TempDir::new().unwrap();
    let db_path = temp_dir.path().join("test.db");
    let storage_dir = temp_dir.path().join("images");

    let store = ClipboardStore::new(&db_path, &storage_dir).unwrap();
    let source = SourceApplication::new("com.test.App".to_string(), "TestApp".to_string(), 1234);

    let entry1 = store.store_text("Test", source.clone()).unwrap();

    // Wait a bit to ensure timestamp difference
    std::thread::sleep(std::time::Duration::from_millis(10));

    let entry2 = store.store_text("Test", source).unwrap();

    assert_eq!(
        entry1.id, entry2.id,
        "Should be same entry"
    );

    // entry2 should have later latest_copy_time
    assert!(
        entry2.latest_copy_time_ms > entry1.latest_copy_time_ms,
        "Duplicate should update latest_copy_time"
    );
}

// T084: Unit test for retrieve all entries query
#[test]
fn test_retrieve_all_entries_returns_all_stored_entries() {
    let temp_dir = TempDir::new().unwrap();
    let db_path = temp_dir.path().join("test.db");
    let storage_dir = temp_dir.path().join("images");

    let store = ClipboardStore::new(&db_path, &storage_dir).unwrap();
    let source = SourceApplication::new("com.test.App".to_string(), "TestApp".to_string(), 1234);

    // Store multiple entries
    let _entry1 = store.store_text("First text", source.clone()).unwrap();
    let _entry2 = store.store_text("Second text", source.clone()).unwrap();
    let _entry3 = store.store_text("Third text", source.clone()).unwrap();

    // Retrieve all entries
    let history = store.get_history(10, 0).unwrap();

    assert_eq!(history.len(), 3, "Should retrieve all 3 entries");
}

// T085: Unit test for retrieve by content type filter
#[test]
fn test_retrieve_by_content_type_filter() {
    let temp_dir = TempDir::new().unwrap();
    let db_path = temp_dir.path().join("test.db");
    let storage_dir = temp_dir.path().join("images");

    let store = ClipboardStore::new(&db_path, &storage_dir).unwrap();
    let source = SourceApplication::new("com.test.App".to_string(), "TestApp".to_string(), 1234);

    // Store text entries
    let _entry1 = store.store_text("Text entry 1", source.clone()).unwrap();
    let _entry2 = store.store_text("Text entry 2", source.clone()).unwrap();

    // Store image entry
    let image_data = vec![1, 2, 3, 4, 5];
    let _entry3 = store.store_image(&image_data, "png", source.clone()).unwrap();

    // Retrieve only text entries
    let text_entries = store.get_history_filtered(ContentType::Text, 10, 0).unwrap();
    assert_eq!(text_entries.len(), 2, "Should retrieve 2 text entries");

    // Retrieve only image entries
    let image_entries = store.get_history_filtered(ContentType::Image, 10, 0).unwrap();
    assert_eq!(image_entries.len(), 1, "Should retrieve 1 image entry");
}

// T086: Unit test for retrieve by ID query
#[test]
fn test_retrieve_entry_by_id() {
    let temp_dir = TempDir::new().unwrap();
    let db_path = temp_dir.path().join("test.db");
    let storage_dir = temp_dir.path().join("images");

    let store = ClipboardStore::new(&db_path, &storage_dir).unwrap();
    let source = SourceApplication::new("com.test.App".to_string(), "TestApp".to_string(), 1234);

    // Store an entry
    let stored = store.store_text("Test content", source).unwrap();

    // Retrieve by ID
    let retrieved = store.get_entry_by_id(stored.id).unwrap();

    assert!(retrieved.is_some(), "Should retrieve stored entry by ID");
    let retrieved = retrieved.unwrap();
    assert_eq!(retrieved.id, stored.id, "Retrieved entry should have same ID");
    assert_eq!(retrieved.content_hash, stored.content_hash, "Content should match");
}

// T086: Unit test for retrieve by non-existent ID returns None
#[test]
fn test_retrieve_entry_by_nonexistent_id_returns_none() {
    let temp_dir = TempDir::new().unwrap();
    let db_path = temp_dir.path().join("test.db");
    let storage_dir = temp_dir.path().join("images");

    let store = ClipboardStore::new(&db_path, &storage_dir).unwrap();

    // Try to retrieve with fake ID
    let fake_id = uuid::Uuid::new_v4();
    let retrieved = store.get_entry_by_id(fake_id).unwrap();

    assert!(retrieved.is_none(), "Should return None for non-existent ID");
}

// T087: Unit test for pagination LIMIT
#[test]
fn test_pagination_limits_results() {
    let temp_dir = TempDir::new().unwrap();
    let db_path = temp_dir.path().join("test.db");
    let storage_dir = temp_dir.path().join("images");

    let store = ClipboardStore::new(&db_path, &storage_dir).unwrap();
    let source = SourceApplication::new("com.test.App".to_string(), "TestApp".to_string(), 1234);

    // Store 5 entries
    for i in 0..5 {
        let _entry = store.store_text(&format!("Text {}", i), source.clone()).unwrap();
    }

    // Request with limit=2
    let page1 = store.get_history(2, 0).unwrap();
    assert_eq!(page1.len(), 2, "Should return only 2 entries with limit=2");
}

// T087: Unit test for pagination OFFSET
#[test]
fn test_pagination_offset_skips_entries() {
    let temp_dir = TempDir::new().unwrap();
    let db_path = temp_dir.path().join("test.db");
    let storage_dir = temp_dir.path().join("images");

    let store = ClipboardStore::new(&db_path, &storage_dir).unwrap();
    let source = SourceApplication::new("com.test.App".to_string(), "TestApp".to_string(), 1234);

    // Store entries in order with small delays to ensure different timestamps
    let entry1 = store.store_text("First", source.clone()).unwrap();
    std::thread::sleep(std::time::Duration::from_millis(10));
    let entry2 = store.store_text("Second", source.clone()).unwrap();
    std::thread::sleep(std::time::Duration::from_millis(10));
    let entry3 = store.store_text("Third", source.clone()).unwrap();

    // First page (offset=0, limit=2)
    let page1 = store.get_history(2, 0).unwrap();
    assert_eq!(page1.len(), 2);

    // Second page (offset=2, limit=2)
    let page2 = store.get_history(2, 2).unwrap();
    assert_eq!(page2.len(), 1, "Should return 1 entry on second page");

    // Verify ordering (most recent first)
    assert_eq!(page1[0].id, entry3.id, "Most recent entry should be first");
    assert_eq!(page1[1].id, entry2.id, "Second most recent should be second");
    assert_eq!(page2[0].id, entry1.id, "Oldest entry should be on second page");
}
