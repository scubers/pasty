import Foundation

/// FFI bridge to Rust core clipboard storage
class RustBridge {
    private var initialized = false

    init() {
        initialize()
    }

    /// Initialize the Rust clipboard store
    private func initialize() {
        let storageManager = StorageManager.shared
        let dbPath = storageManager.getDatabasePath().path
        let storagePath = storageManager.getImagesDirectory().path

        dbPath.withCString { dbPtr in
            storagePath.withCString { storagePtr in
                let result = pasty_clipboard_init(dbPtr, storagePtr)

                if result == 0 {
                    initialized = true
                    NSLog("[RustBridge] Initialized successfully")
                } else {
                    let error = getLastError()
                    NSLog("[RustBridge] Initialization failed: \(error)")
                }
            }
        }
    }

    /// Store text content via FFI
    func storeText(text: String, sourceBundleId: String, sourceAppName: String, sourcePid: Int32) {
        guard initialized else {
            NSLog("[RustBridge] Not initialized, skipping text storage")
            return
        }

        text.withCString { textPtr in
            sourceBundleId.withCString { bundleIdPtr in
                sourceAppName.withCString { appNamePtr in
                    let entry = pasty_clipboard_store_text(textPtr, bundleIdPtr, appNamePtr, sourcePid)

                    if let entryPtr = entry {
                        NSLog("[RustBridge] Stored text entry successfully")
                        pasty_clipboard_entry_free(entryPtr)
                    } else {
                        let error = getLastError()
                        NSLog("[RustBridge] Failed to store text: \(error)")
                    }
                }
            }
        }
    }

    /// Store image content via FFI
    func storeImage(imageData: Data, format: String, sourceBundleId: String, sourceAppName: String, sourcePid: Int32) {
        guard initialized else {
            NSLog("[RustBridge] Not initialized, skipping image storage")
            return
        }

        imageData.withUnsafeBytes { bytes in
            format.withCString { formatPtr in
                sourceBundleId.withCString { bundleIdPtr in
                    sourceAppName.withCString { appNamePtr in
                        let entry = pasty_clipboard_store_image(
                            bytes.baseAddress!.assumingMemoryBound(to: UInt8.self),
                            imageData.count,
                            formatPtr,
                            bundleIdPtr,
                            appNamePtr,
                            sourcePid
                        )

                        if let entryPtr = entry {
                            NSLog("[RustBridge] Stored image entry successfully")
                            pasty_clipboard_entry_free(entryPtr)
                        } else {
                            let error = getLastError()
                            NSLog("[RustBridge] Failed to store image: \(error)")
                        }
                    }
                }
            }
        }
    }

    /// Get last error message from Rust
    private func getLastError() -> String {
        guard let errorPtr = pasty_get_last_error() else {
            return "Unknown error"
        }

        let errorString = String(cString: errorPtr)
        return errorString
    }
}
