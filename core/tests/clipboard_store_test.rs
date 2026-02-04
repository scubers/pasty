//! Unit tests for clipboard store service
//!
//! T048: Tests for duplicate detection

use pasty_core::services::clipboard_store::ClipboardStore;
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
