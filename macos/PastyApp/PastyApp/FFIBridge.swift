//! PastyApp - macOS application
//!
//! Main entry point for the Pasty clipboard manager macOS application.

import Foundation

// MARK: - FFI Function Declarations

/** Get Rust core version - returns C string (must NOT be freed) */
@_silgen_name("pasty_get_version")
func pasty_get_version() -> UnsafeMutablePointer<CChar>?

/** Initialize Rust core - returns 0 on success */
@_silgen_name("pasty_init")
func pasty_init() -> Int32

/** Shutdown Rust core - returns 0 on success */
@_silgen_name("pasty_shutdown")
func pasty_shutdown() -> Int32

/** Free string allocated by Rust */
@_silgen_name("pasty_free_string")
func pasty_free_string(_ ptr: UnsafeMutablePointer<CChar>)

/** Get last error message - returns C string or null */
@_silgen_name("pasty_get_last_error")
func pasty_get_last_error() -> UnsafeMutablePointer<CChar>?

/** Placeholder: Get clipboard text */
@_silgen_name("pasty_clipboard_get_text")
func pasty_clipboard_get_text() -> UnsafeMutablePointer<CChar>?

/** Placeholder: Set clipboard text */
@_silgen_name("pasty_clipboard_set_text")
func pasty_clipboard_set_text(_ text: UnsafePointer<CChar>) -> Int32

// MARK: - FFI Errors

enum FFIError: Error {
    case coreInitializationFailed
    case coreShutdownFailed
    case functionNotImplemented
    case invalidString
    case unknown(Int32)

    static func fromCode(_ code: Int32) -> FFIError {
        return .unknown(code)
    }
}

// MARK: - FFI Bridge

/// Type-safe Swift wrapper for Rust FFI calls
class PastyFFIBridge {

    static let shared = PastyFFIBridge()

    private init() {}

    /// Initialize the Rust core
    func initialize() throws {
        let result = pasty_init()
        if result != 0 {
            throw FFIError.coreInitializationFailed
        }
    }

    /// Shutdown the Rust core
    func shutdown() throws {
        let result = pasty_shutdown()
        if result != 0 {
            throw FFIError.coreShutdownFailed
        }
    }

    /// Get the Rust core version
    func getVersion() -> String? {
        guard let cString = pasty_get_version() else {
            return nil
        }
        // Note: pasty_get_version() returns a static string, so we don't free it
        return String(validatingUTF8: cString)
    }

    /// Get the last error message from Rust
    func getLastError() -> String? {
        guard let cString = pasty_get_last_error() else {
            return nil
        }
        return String(validatingUTF8: cString)
    }

    /// Get current clipboard text (placeholder - not implemented)
    func getClipboardText() throws -> String {
        guard let cString = pasty_clipboard_get_text() else {
            throw FFIError.functionNotImplemented
        }
        defer { pasty_free_string(cString) }
        guard let text = String(validatingUTF8: cString) else {
            throw FFIError.invalidString
        }
        return text
    }

    /// Set clipboard text (placeholder - not implemented)
    func setClipboardText(_ text: String) throws {
        let result = text.withCString { cString in
            pasty_clipboard_set_text(cString)
        }
        if result != 0 {
            throw FFIError.fromCode(result)
        }
    }
}
