import Foundation

/// Platform-specific business logic layer that coordinates handlers and FFI
class ClipboardCoordinator {
    private let ffiBridge: RustBridge

    init(ffiBridge: RustBridge = RustBridge()) {
        self.ffiBridge = ffiBridge
    }

    /// Store text content via FFI
    func storeTextContent(_ text: String, source: SourceApplication) {
        // Normalize text before storing
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Skip empty strings
        guard !normalized.isEmpty else {
            NSLog("[ClipboardCoordinator] Skipping empty text content")
            return
        }

        // Call FFI to store in database
        ffiBridge.storeText(
            text: normalized,
            sourceBundleId: source.bundleId,
            sourceAppName: source.appName,
            sourcePid: source.pid
        )
    }

    /// Store image content via FFI
    func storeImageContent(_ imageData: Data, format: String, source: SourceApplication) {
        // Call FFI to store in database and file system
        ffiBridge.storeImage(
            imageData: imageData,
            format: format,
            sourceBundleId: source.bundleId,
            sourceAppName: source.appName,
            sourcePid: source.pid
        )
    }
}
