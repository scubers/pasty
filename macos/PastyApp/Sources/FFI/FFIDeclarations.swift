import Foundation

// MARK: - Clipboard FFI Types

/// Clipboard FFI content type
enum ClipboardFfiContentType: Int32 {
    case text = 0
    case image = 1
}

/// Clipboard FFI entry structure
struct ClipboardFfiEntry {
    var id: UnsafeMutablePointer<CChar>
    var content_hash: UnsafeMutablePointer<CChar>
    var content_type: ClipboardFfiContentType
    var timestamp_ms: Int64
    var latest_copy_time_ms: Int64
    var text_content: UnsafeMutablePointer<CChar>
    var image_path: UnsafeMutablePointer<CChar>
    var source_bundle_id: UnsafeMutablePointer<CChar>
    var source_app_name: UnsafeMutablePointer<CChar>
    var source_pid: UInt32
}

/// FFI entry list structure
struct ClipboardFfiEntryList {
    var count: Int
    var entries: UnsafeMutablePointer<UnsafeMutablePointer<ClipboardFfiEntry>?>
}

// MARK: - FFI Function Declarations

@_silgen_name("pasty_get_version")
func pasty_get_version() -> UnsafeMutablePointer<CChar>?

@_silgen_name("pasty_init")
func pasty_init() -> Int32

@_silgen_name("pasty_shutdown")
func pasty_shutdown() -> Int32

@_silgen_name("pasty_get_last_error")
func pasty_get_last_error() -> UnsafeMutablePointer<CChar>?

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

@_silgen_name("pasty_clipboard_update_latest_copy_time_by_id")
func pasty_clipboard_update_latest_copy_time_by_id(
    _ id: UnsafePointer<CChar>
) -> Int32

@_silgen_name("pasty_clipboard_delete_entry_by_id")
func pasty_clipboard_delete_entry_by_id(
    _ id: UnsafePointer<CChar>
) -> Int32

@_silgen_name("pasty_clipboard_delete_entries_by_ids")
func pasty_clipboard_delete_entries_by_ids(
    _ ids: UnsafePointer<UnsafePointer<CChar>?>,
    _ count: Int
) -> Int32

@_silgen_name("pasty_clipboard_entry_free")
func pasty_clipboard_entry_free(_ entry: UnsafeMutablePointer<ClipboardFfiEntry>)

@_silgen_name("pasty_get_clipboard_history")
func pasty_get_clipboard_history(_ limit: Int, _ offset: Int) -> UnsafeMutablePointer<ClipboardFfiEntryList>?

@_silgen_name("pasty_get_entry_by_id")
func pasty_get_entry_by_id(_ id: UnsafePointer<CChar>) -> UnsafeMutablePointer<ClipboardFfiEntry>?

@_silgen_name("pasty_list_free")
func pasty_list_free(_ list: UnsafeMutablePointer<ClipboardFfiEntryList>)
