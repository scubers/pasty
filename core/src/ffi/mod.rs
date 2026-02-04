//! FFI (Foreign Function Interface) module
//!
//! This module provides C-compatible exports for interoperability with Swift and other languages.

pub mod exports;

// Re-export all FFI functions for convenience
pub use exports::*;
