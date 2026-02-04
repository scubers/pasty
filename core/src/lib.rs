//! Pasty Core - Cross-platform clipboard library
//!
//! This library provides platform-agnostic business logic for clipboard management,
//! including data models, services, and FFI exports.

pub mod models;
pub mod services;
pub mod ffi;

// Re-export public FFI functions
pub use ffi::exports::*;

// Note: Tests are in the tests/ directory, not inline

