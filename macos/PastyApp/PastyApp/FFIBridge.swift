//! PastyApp - macOS application
//!
//! Main entry point for the Pasty clipboard manager macOS application.

import Foundation

// MARK: - FFI Function Types

/// Function type for pasty_get_version
typealias PastyGetVersionFunc = @convention(c) () -> UnsafeMutablePointer<CChar>?

/// Function type for pasty_init
typealias PastyInitFunc = @convention(c) () -> Int32

/// Function type for pasty_shutdown
typealias PastyShutdownFunc = @convention(c) () -> Int32

/// Function type for pasty_get_last_error
typealias PastyGetLastErrorFunc = @convention(c) () -> UnsafeMutablePointer<CChar>?

// MARK: - FFI Errors

enum FFIError: Error {
    case coreInitializationFailed
    case coreShutdownFailed
    case functionNotImplemented
    case invalidString
    case rustNotAvailable
    case unknown(Int32)

    static func fromCode(_ code: Int32) -> FFIError {
        return .unknown(code)
    }
}

// MARK: - FFI Bridge

/// Type-safe Swift wrapper for Rust FFI calls
/// Uses dynamic loading to allow mock mode when Rust is not available
class PastyFFIBridge {

    static let shared = PastyFFIBridge()

    private let isRustAvailable: Bool
    private let pastyGetVersion: PastyGetVersionFunc?
    private let pastyInit: PastyInitFunc?
    private let pastyShutdown: PastyShutdownFunc?
    private let pastyGetLastError: PastyGetLastErrorFunc?

    private init() {
        // Try to load and resolve Rust symbols
        let handle = dlopen(nil, RTLD_NOW)

        if let handle = handle {
            self.pastyGetVersion = unsafeBitCast(
                dlsym(handle, "pasty_get_version"),
                to: PastyGetVersionFunc?.self
            )
            self.pastyInit = unsafeBitCast(
                dlsym(handle, "pasty_init"),
                to: PastyInitFunc?.self
            )
            self.pastyShutdown = unsafeBitCast(
                dlsym(handle, "pasty_shutdown"),
                to: PastyShutdownFunc?.self
            )
            self.pastyGetLastError = unsafeBitCast(
                dlsym(handle, "pasty_get_last_error"),
                to: PastyGetLastErrorFunc?.self
            )
            dlclose(handle)

            // Check if at least the basic symbols are available
            self.isRustAvailable = (pastyGetVersion != nil)

            if isRustAvailable {
                NSLog("[FFIBridge] Rust FFI available")
            } else {
                NSLog("[FFIBridge] Using MOCK mode - Rust FFI not available")
            }
        } else {
            self.pastyGetVersion = nil
            self.pastyInit = nil
            self.pastyShutdown = nil
            self.pastyGetLastError = nil
            self.isRustAvailable = false
            NSLog("[FFIBridge] Using MOCK mode - cannot load dynamic library")
        }
    }

    /// Initialize the Rust core (no-op in mock mode)
    func initialize() throws {
        guard isRustAvailable, let pastyInit = pastyInit else {
            NSLog("[FFIBridge] Mock mode: skipping initialization")
            return
        }
        let result = pastyInit()
        if result != 0 {
            throw FFIError.coreInitializationFailed
        }
    }

    /// Shutdown the Rust core (no-op in mock mode)
    func shutdown() throws {
        guard isRustAvailable, let pastyShutdown = pastyShutdown else {
            NSLog("[FFIBridge] Mock mode: skipping shutdown")
            return
        }
        let result = pastyShutdown()
        if result != 0 {
            throw FFIError.coreShutdownFailed
        }
    }

    /// Get the Rust core version (returns mock version in mock mode)
    func getVersion() -> String? {
        guard isRustAvailable, let pastyGetVersion = pastyGetVersion else {
            return "mock-1.0.0"
        }
        guard let cString = pastyGetVersion() else {
            return nil
        }
        // Note: pasty_get_version() returns a static string, so we don't free it
        return String(validatingUTF8: cString)
    }

    /// Get the last error message from Rust (returns nil in mock mode)
    func getLastError() -> String? {
        guard isRustAvailable, let pastyGetLastError = pastyGetLastError else {
            return nil
        }
        guard let cString = pastyGetLastError() else {
            return nil
        }
        return String(validatingUTF8: cString)
    }

    /// Get current clipboard text (not implemented - use ClipboardHistory instead)
    func getClipboardText() throws -> String {
        throw FFIError.functionNotImplemented
    }

    /// Set clipboard text (not implemented - use NSPasteboard instead)
    func setClipboardText(_ text: String) throws {
        throw FFIError.functionNotImplemented
    }
}
