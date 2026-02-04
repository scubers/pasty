//! Unit tests for deduplication service
//!
//! T046-T047: Tests for hash calculation and text normalization

use pasty_core::services::deduplication::DeduplicationService;

#[test]
fn test_hash_text_produces_consistent_results() {
    // Same input should produce same hash
    let text = "Hello, World!";
    let hash1 = DeduplicationService::hash_text(text);
    let hash2 = DeduplicationService::hash_text(text);

    assert_eq!(hash1, hash2, "Same text should produce same hash");
    assert_eq!(hash1.len(), 64, "SHA-256 should produce 64 hex characters");
}

#[test]
fn test_hash_text_different_for_different_content() {
    let hash1 = DeduplicationService::hash_text("First text");
    let hash2 = DeduplicationService::hash_text("Second text");

    assert_ne!(hash1, hash2, "Different text should produce different hashes");
}

#[test]
fn test_hash_text_normalizes_whitespace() {
    // Whitespace should be trimmed before hashing
    let hash1 = DeduplicationService::hash_text("  Hello, World!  ");
    let hash2 = DeduplicationService::hash_text("Hello, World!");

    assert_eq!(hash1, hash2, "Whitespace should be normalized before hashing");
}

#[test]
fn test_hash_image_produces_consistent_results() {
    let data = vec![1, 2, 3, 4, 5];
    let hash1 = DeduplicationService::hash_image(&data);
    let hash2 = DeduplicationService::hash_image(&data);

    assert_eq!(hash1, hash2, "Same image data should produce same hash");
}

#[test]
fn test_hash_image_different_for_different_content() {
    let data1 = vec![1, 2, 3, 4, 5];
    let data2 = vec![5, 4, 3, 2, 1];

    let hash1 = DeduplicationService::hash_image(&data1);
    let hash2 = DeduplicationService::hash_image(&data2);

    assert_ne!(hash1, hash2, "Different image data should produce different hashes");
}

#[test]
fn test_normalize_text_trims_leading_whitespace() {
    assert_eq!(
        DeduplicationService::normalize_text("   hello"),
        "hello",
        "Should trim leading whitespace"
    );
}

#[test]
fn test_normalize_text_trims_trailing_whitespace() {
    assert_eq!(
        DeduplicationService::normalize_text("hello   "),
        "hello",
        "Should trim trailing whitespace"
    );
}

#[test]
fn test_normalize_text_trims_both_ends() {
    assert_eq!(
        DeduplicationService::normalize_text("   hello   "),
        "hello",
        "Should trim both leading and trailing whitespace"
    );
}

#[test]
fn test_normalize_text_handles_tabs_and_newlines() {
    assert_eq!(
        DeduplicationService::normalize_text("\n\t  test  \t\n"),
        "test",
        "Should trim tabs and newlines"
    );
}

#[test]
fn test_normalize_text_preserves_internal_whitespace() {
    assert_eq!(
        DeduplicationService::normalize_text("hello world"),
        "hello world",
        "Should preserve internal spaces"
    );
}

#[test]
fn test_normalize_text_handles_empty_string() {
    assert_eq!(
        DeduplicationService::normalize_text(""),
        "",
        "Should handle empty string"
    );
}

#[test]
fn test_normalize_text_handles_whitespace_only() {
    assert_eq!(
        DeduplicationService::normalize_text("   \t\n   "),
        "",
        "Should return empty string for whitespace-only input"
    );
}
