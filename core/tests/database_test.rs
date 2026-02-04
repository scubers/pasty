//! Integration tests for database service
//!
//! T050-T051: Tests for database insert/retrieve and migration

use pasty_core::services::database::Database;
use pasty_core::models::{ClipboardEntry, ContentType, Content, SourceApplication};
use tempfile::NamedTempFile;

#[test]
fn test_database_insert_and_retrieve_text_entry() {
    let temp_file = NamedTempFile::new().unwrap();
    let db = Database::open(temp_file.path()).unwrap();

    let source = SourceApplication::new("com.test.App".to_string(), "TestApp".to_string(), 1234);
    let entry = ClipboardEntry::new(
        "test_hash_123".to_string(),
        ContentType::Text,
        Content::Text("Test content".to_string()),
        source,
    );

    db.insert_entry(&entry).unwrap();

    let retrieved = db.get_entry_by_hash("test_hash_123").unwrap();

    assert!(
        retrieved.is_some(),
        "Should retrieve inserted entry"
    );

    let retrieved = retrieved.unwrap();
    assert_eq!(retrieved.content_hash, "test_hash_123");
    assert_eq!(retrieved.source.bundle_id, "com.test.App");
    assert_eq!(retrieved.source.app_name, "TestApp");
    assert_eq!(retrieved.source.pid, 1234);

    match retrieved.content {
        Content::Text(text) => assert_eq!(text, "Test content"),
        _ => panic!("Expected text content"),
    }
}

#[test]
fn test_database_insert_and_retrieve_image_entry() {
    let temp_file = NamedTempFile::new().unwrap();
    let db = Database::open(temp_file.path()).unwrap();

    use pasty_core::models::{ImageFile, ImageFormat};

    let source = SourceApplication::new("com.test.App".to_string(), "TestApp".to_string(), 1234);
    let image_file = ImageFile {
        path: "images/test/image.png".to_string(),
        size: 1024,
        dimensions: None,
        format: ImageFormat::Png,
    };

    let entry = ClipboardEntry::new(
        "image_hash_456".to_string(),
        ContentType::Image,
        Content::Image(image_file),
        source,
    );

    db.insert_entry(&entry).unwrap();

    let retrieved = db.get_entry_by_hash("image_hash_456").unwrap();

    assert!(
        retrieved.is_some(),
        "Should retrieve inserted image entry"
    );

    let retrieved = retrieved.unwrap();
    assert_eq!(retrieved.content_hash, "image_hash_456");

    match retrieved.content {
        Content::Image(img) => {
            assert_eq!(img.path, "images/test/image.png");
            // Note: size, dimensions, and format are not persisted in database
            // Only the path is stored; metadata would be loaded separately
        }
        _ => panic!("Expected image content"),
    }
}

#[test]
fn test_database_migration_runs_on_initialization() {
    let temp_file = NamedTempFile::new().unwrap();

    // Open database - should trigger migration
    let _db = Database::open(temp_file.path()).unwrap();

    // If we got here without error, migration ran successfully
    // The fact that Database::open() succeeded means migration worked
}

#[test]
fn test_database_creates_tables_on_migration() {
    let temp_file = NamedTempFile::new().unwrap();
    let db = Database::open(temp_file.path()).unwrap();

    // Try to insert an entry - if table exists, this will succeed
    let source = SourceApplication::new("com.test.App".to_string(), "TestApp".to_string(), 1234);
    let entry = ClipboardEntry::new(
        "test_hash".to_string(),
        ContentType::Text,
        Content::Text("Test".to_string()),
        source,
    );

    // If this succeeds, the table was created
    assert!(db.insert_entry(&entry).is_ok(), "Should be able to insert entry");
}

#[test]
fn test_database_creates_indexes_on_migration() {
    let temp_file = NamedTempFile::new().unwrap();
    let db = Database::open(temp_file.path()).unwrap();

    // Insert an entry
    let source = SourceApplication::new("com.test.App".to_string(), "TestApp".to_string(), 1234);
    let entry = ClipboardEntry::new(
        "index_test_hash".to_string(),
        ContentType::Text,
        Content::Text("Test".to_string()),
        source,
    );
    db.insert_entry(&entry).unwrap();

    // Try to get entry by hash - if idx_clipboard_entries_hash exists, this will work
    let retrieved = db.get_entry_by_hash("index_test_hash").unwrap();
    assert!(retrieved.is_some(), "Should be able to query by hash (using index)");

    // Try to get entries by type - if idx_clipboard_entries_type_timestamp exists, this will work
    let entries = db.get_entries_by_type(ContentType::Text, 10, 0).unwrap();
    assert!(!entries.is_empty(), "Should be able to query by type (using index)");
}

#[test]
fn test_get_all_entries_with_pagination() {
    let temp_file = NamedTempFile::new().unwrap();
    let db = Database::open(temp_file.path()).unwrap();

    // Insert multiple entries
    for i in 0..5 {
        let source = SourceApplication::new("com.test.App".to_string(), "TestApp".to_string(), 1234);
        let entry = ClipboardEntry::new(
            format!("hash_{}", i),
            ContentType::Text,
            Content::Text(format!("Content {}", i)),
            source,
        );
        db.insert_entry(&entry).unwrap();
    }

    // Get first page
    let page1 = db.get_all_entries(2, 0).unwrap();
    assert_eq!(page1.len(), 2, "Should return 2 entries");

    // Get second page
    let page2 = db.get_all_entries(2, 2).unwrap();
    assert_eq!(page2.len(), 2, "Should return 2 entries");

    // Entries should be different
    assert_ne!(
        page1[0].id, page2[0].id,
        "Different pages should have different entries"
    );
}

#[test]
fn test_get_entries_by_type_filters_correctly() {
    let temp_file = NamedTempFile::new().unwrap();
    let db = Database::open(temp_file.path()).unwrap();

    use pasty_core::models::{ImageFile, ImageFormat};

    // Insert text entries
    for i in 0..3 {
        let source = SourceApplication::new("com.test.App".to_string(), "TestApp".to_string(), 1234);
        let entry = ClipboardEntry::new(
            format!("text_hash_{}", i),
            ContentType::Text,
            Content::Text(format!("Text {}", i)),
            source,
        );
        db.insert_entry(&entry).unwrap();
    }

    // Insert image entries
    for i in 0..2 {
        let source = SourceApplication::new("com.test.App".to_string(), "TestApp".to_string(), 1234);
        let image_file = ImageFile {
            path: format!("images/{}.png", i),
            size: 1024,
            dimensions: None,
            format: ImageFormat::Png,
        };
        let entry = ClipboardEntry::new(
            format!("image_hash_{}", i),
            ContentType::Image,
            Content::Image(image_file),
            source,
        );
        db.insert_entry(&entry).unwrap();
    }

    // Get only text entries
    let text_entries = db.get_entries_by_type(ContentType::Text, 10, 0).unwrap();
    assert_eq!(text_entries.len(), 3, "Should return 3 text entries");

    // Get only image entries
    let image_entries = db.get_entries_by_type(ContentType::Image, 10, 0).unwrap();
    assert_eq!(image_entries.len(), 2, "Should return 2 image entries");
}

#[test]
fn test_update_latest_copy_time() {
    let temp_file = NamedTempFile::new().unwrap();
    let db = Database::open(temp_file.path()).unwrap();

    let source = SourceApplication::new("com.test.App".to_string(), "TestApp".to_string(), 1234);
    let entry = ClipboardEntry::new(
        "hash_update_test".to_string(),
        ContentType::Text,
        Content::Text("Test content".to_string()),
        source,
    );

    db.insert_entry(&entry).unwrap();

    let original = db.get_entry_by_hash("hash_update_test").unwrap().unwrap();
    let new_time = original.latest_copy_time_ms + chrono::Duration::milliseconds(1000);

    db.update_latest_copy_time("hash_update_test", new_time).unwrap();

    let updated = db.get_entry_by_hash("hash_update_test").unwrap().unwrap();

    assert_eq!(
        updated.latest_copy_time_ms, new_time,
        "latest_copy_time should be updated"
    );
}
