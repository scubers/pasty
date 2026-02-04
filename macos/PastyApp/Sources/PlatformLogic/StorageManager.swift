import Foundation

/// Platform-level storage operations
class StorageManager {
    static let shared = StorageManager()

    private init() {}

    /// Get application support directory
    func getAppSupportDirectory() -> URL {
        let fileManager = FileManager.default

        // Get ~/Library/Application Support
        if let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            let pastyDir = appSupport.appendingPathComponent("Pasty", isDirectory: true)

            // Create directory if it doesn't exist
            if !fileManager.fileExists(atPath: pastyDir.path) {
                try? fileManager.createDirectory(at: pastyDir, withIntermediateDirectories: true)
            }

            return pastyDir
        }

        // Fallback to temp directory
        return URL(fileURLWithPath: NSTemporaryDirectory())
    }

    /// Get database path
    func getDatabasePath() -> URL {
        return getAppSupportDirectory().appendingPathComponent("clipboard.db")
    }

    /// Get images storage path
    func getImagesDirectory() -> URL {
        let imagesDir = getAppSupportDirectory().appendingPathComponent("images", isDirectory: true)

        // Create directory if it doesn't exist
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: imagesDir.path) {
            try? fileManager.createDirectory(at: imagesDir, withIntermediateDirectories: true)
        }

        return imagesDir
    }
}
