//! Data models for clipboard entries and history
//!
//! This module defines the core data structures used throughout Pasty.

pub mod clipboard_entry;
pub mod clipboard_history;

// Re-export common types
pub use clipboard_entry::{ClipboardEntry, ContentType, ClipboardData};
pub use clipboard_history::ClipboardHistory;
