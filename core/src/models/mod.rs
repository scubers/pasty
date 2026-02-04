//! Data models for clipboard entries and history
//!
//! This module defines the core data structures used throughout Pasty.

pub mod clipboard_entry;

// Re-export common types from clipboard_entry
pub use clipboard_entry::{
    ClipboardEntry, ContentType, Content,
    ImageFile, ImageDimensions, ImageFormat,
    SourceApplication
};
