//! Business logic services
//!
//! This module provides service interfaces and implementations for clipboard management.

pub mod encryption;

// Re-export common types
pub use encryption::{EncryptionService, EncryptionError};
