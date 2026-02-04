//! Unit tests for storage service
//!
//! T049: Tests for image file storage with sharding

use pasty_core::services::storage::StorageService;
use tempfile::TempDir;

#[test]
fn test_storage_service_creates_base_directory() {
    let temp_dir = TempDir::new().unwrap();
    let storage = StorageService::new(temp_dir.path()).unwrap();

    assert!(
        temp_dir.path().exists(),
        "Base directory should be created"
    );
}

#[test]
fn test_save_image_creates_file() {
    let temp_dir = TempDir::new().unwrap();
    let storage = StorageService::new(temp_dir.path()).unwrap();

    let hash = "abc123def4567890";
    let data = b"fake image data";

    let path = storage.save_image(hash, data, "png").unwrap();

    assert!(
        path.exists(),
        "Image file should be created on disk"
    );

    // Verify file content
    let saved_data = std::fs::read(&path).unwrap();
    assert_eq!(
        saved_data, data,
        "Saved data should match original data"
    );
}

#[test]
fn test_sharded_directory_structure_two_levels() {
    let temp_dir = TempDir::new().unwrap();
    let storage = StorageService::new(temp_dir.path()).unwrap();

    let hash = "abcd1234567890";
    let data = b"test data";

    let path = storage.save_image(hash, data, "png").unwrap();

    // Should be in base_dir/abcd/abcd1234567890.png
    let expected_parent = temp_dir.path().join("abcd");
    assert_eq!(
        path.parent(),
        Some(expected_parent.as_path()),
        "File should be in sharded directory (first 4 chars)"
    );

    assert!(
        expected_parent.exists(),
        "Sharded directory should be created"
    );
}

#[test]
fn test_save_same_hash_overwrites() {
    let temp_dir = TempDir::new().unwrap();
    let storage = StorageService::new(temp_dir.path()).unwrap();

    let hash = "samehash1234";
    let data1 = b"first version";
    let data2 = b"second version";

    storage.save_image(hash, data1, "png").unwrap();
    storage.save_image(hash, data2, "png").unwrap();

    // Should have second version
    let path = temp_dir.path().join("same/samehash1234.png");
    let saved_data = std::fs::read(&path).unwrap();
    assert_eq!(
        saved_data, data2,
        "Second save should overwrite first"
    );
}

#[test]
fn test_image_exists_returns_true_for_existing() {
    let temp_dir = TempDir::new().unwrap();
    let storage = StorageService::new(temp_dir.path()).unwrap();

    let hash = "existing123";
    let data = b"test";

    storage.save_image(hash, data, "png").unwrap();

    assert!(
        storage.image_exists(hash, "png"),
        "image_exists should return true for existing image"
    );
}

#[test]
fn test_image_exists_returns_false_for_nonexistent() {
    let temp_dir = TempDir::new().unwrap();
    let storage = StorageService::new(temp_dir.path()).unwrap();

    assert!(
        !storage.image_exists("nonexistent", "png"),
        "image_exists should return false for nonexistent image"
    );
}

#[test]
fn test_delete_image_removes_file() {
    let temp_dir = TempDir::new().unwrap();
    let storage = StorageService::new(temp_dir.path()).unwrap();

    let hash = "todelete123";
    let data = b"test";

    storage.save_image(hash, data, "png").unwrap();
    assert!(storage.image_exists(hash, "png"));

    storage.delete_image(hash, "png").unwrap();

    assert!(
        !storage.image_exists(hash, "png"),
        "Image should be deleted"
    );
}

#[test]
fn test_delete_image_handles_nonexistent() {
    let temp_dir = TempDir::new().unwrap();
    let storage = StorageService::new(temp_dir.path()).unwrap();

    // Should not error on nonexistent file
    storage.delete_image("nonexistent", "png").unwrap();
}

#[test]
fn test_get_relative_path() {
    let temp_dir = TempDir::new().unwrap();
    let storage = StorageService::new(temp_dir.path()).unwrap();

    let path = storage.get_relative_path("abcdef123456", "png");
    assert_eq!(
        path, "abcd/abcdef123456.png",
        "Relative path should use first 4 chars as shard"
    );
}

#[test]
fn test_get_relative_path_short_hash() {
    let temp_dir = TempDir::new().unwrap();
    let storage = StorageService::new(temp_dir.path()).unwrap();

    let path = storage.get_relative_path("abc", "png");
    assert_eq!(
        path, "misc/abc.png",
        "Short hash should use 'misc' shard"
    );
}

#[test]
fn test_save_image_with_different_formats() {
    let temp_dir = TempDir::new().unwrap();
    let storage = StorageService::new(temp_dir.path()).unwrap();

    let hash = "formatstest";
    let data = b"test data";

    storage.save_image(hash, data, "png").unwrap();
    storage.save_image(hash, data, "jpg").unwrap();

    assert!(storage.image_exists(hash, "png"));
    assert!(storage.image_exists(hash, "jpg"));
}
