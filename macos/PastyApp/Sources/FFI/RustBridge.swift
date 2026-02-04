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

// MARK: - FFI Declarations

/// Clipboard FFI error codes
enum ClipboardFfiErrorCode: Int32 {
    case success = 0
    case invalidArgument = 1
    case databaseError = 2
    case storageError = 3
    case unknown = 99
}

/// Clipboard FFI entry structure
struct ClipboardFfiEntry {
    var id: UnsafeMutablePointer<CChar>
    var content_hash: UnsafeMutablePointer<CChar>
    var content_type: ClipboardFfiContentType
    var timestamp_ms: Int64
    var text_content: UnsafeMutablePointer<CChar>
    var image_path: UnsafeMutablePointer<CChar>
    var source_bundle_id: UnsafeMutablePointer<CChar>
    var source_app_name: UnsafeMutablePointer<CChar>
    var source_pid: UInt32
}

/// Clipboard FFI content type
enum ClipboardFfiContentType: Int32 {
    case text = 0
    case image = 1
}

// MARK: - External C Functions

@_silgen_name("pasty_clipboard_init")
func pasty_clipboard_init(_ dbPath: UnsafePointer<CChar>, _ storagePath: UnsafePointer<CChar>) -> Int32

@_silgen_name("pasty_clipboard_store_text")
func pasty_clipboard_store_text(
    _ text: UnsafePointer<CChar>,
    _ sourceBundleId: UnsafePointer<CChar>,
    _ sourceAppName: UnsafePointer<CChar>,
    _ sourcePid: Int32
) -> UnsafeMutablePointer<ClipboardFfiEntry>?

@_silgen_name("pasty_clipboard_store_image")
func pasty_clipboard_store_image(
    _ imageData: UnsafePointer<UInt8>,
    _ imageLen: Int,
    _ format: UnsafePointer<CChar>,
    _ sourceBundleId: UnsafePointer<CChar>,
    _ sourceAppName: UnsafePointer<CChar>,
    _ sourcePid: Int32
) -> UnsafeMutablePointer<ClipboardFfiEntry>?

@_silgen_name("pasty_clipboard_entry_free")
func pasty_clipboard_entry_free(_ entry: UnsafeMutablePointer<ClipboardFfiEntry>)

@_silgen_name("pasty_get_clipboard_history")
func pasty_get_clipboard_history(_ limit: Int, _ offset: Int) -> UnsafeMutablePointer<ClipboardFfiEntryList>?

@_silgen_name("pasty_get_entry_by_id")
func pasty_get_entry_by_id(_ id: UnsafePointer<CChar>) -> UnsafeMutablePointer<ClipboardFfiEntry>?

@_silgen_name("pasty_list_free")
func pasty_list_free(_ list: UnsafeMutablePointer<ClipboardFfiEntryList>)

/// FFI entry list structure
struct ClipboardFfiEntryList {
    var count: Int
    var entries: UnsafeMutablePointer<UnsafeMutablePointer<ClipboardFfiEntry>?>
}

// Note: pasty_get_last_error is declared in PastyApp/FFIBridge.swift
