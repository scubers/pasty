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

        // T081-T083: Error handling with graceful degradation
        do {
            // Call FFI to store in database
            ffiBridge.storeText(
                text: normalized,
                sourceBundleId: source.bundleId,
                sourceAppName: source.appName,
                sourcePid: source.pid
            )
        } catch {
            // T082-T083: Graceful degradation - log error but don't crash
            NSLog("[ClipboardCoordinator] Error storing text content: \(error.localizedDescription)")
            NSLog("[ClipboardCoordinator] Continuing monitoring despite error")
        }
    }

    /// Store image content via FFI
    func storeImageContent(_ imageData: Data, format: String, source: SourceApplication) {
        // T081-T083: Error handling with graceful degradation
        do {
            // Call FFI to store in database and file system
            ffiBridge.storeImage(
                imageData: imageData,
                format: format,
                sourceBundleId: source.bundleId,
                sourceAppName: source.appName,
                sourcePid: source.pid
            )
        } catch {
            // T082-T083: Graceful degradation - log error but don't crash
            NSLog("[ClipboardCoordinator] Error storing image content: \(error.localizedDescription)")
            NSLog("[ClipboardCoordinator] Continuing monitoring despite error")
        }
    }
}
