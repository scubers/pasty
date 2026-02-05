# Clipboard Operations Contract (Local)

**Scope**: Local clipboard operations for macOS UI + Rust core. No network API.

## Boundaries

### Swift UI → ViewModel

- `MainPanelViewModel.handle(_:)`
  - `.copyEntry(id: String)` → copy selected entry to system clipboard
  - `.pasteEntry(id: String)` → copy then paste (Cmd+V) into previous app
  - `.deleteEntry(id: String)` → delete single entry (confirmation required)
  - `.deleteEntries(ids: [String])` → delete multiple entries (confirmation required)

- `PreviewPanelViewModel.handleCopyAction()`
  - Copies current preview content to system clipboard

- `PreviewPanelViewModel.handlePasteAction()`
  - Copies current preview content and simulates Cmd+V

### ViewModel → Platform Services

- `ClipboardHistory.retrieveAllEntries(limit:offset:)` → `[ClipboardEntry]`
- `ClipboardHistory.retrieveEntryById(id:)` → `ClipboardEntry?`
- `ClipboardHistory.retrieveEntriesFiltered(contentType:limit:offset:)` → `[ClipboardEntry]`

### Swift → Rust FFI

- `pasty_get_clipboard_history(limit, offset)` → `ClipboardFfiEntryList*`
- `pasty_get_entry_by_id(id)` → `ClipboardFfiEntry*`
- `pasty_clipboard_store_text(text, bundle_id, app_name, pid)` → `ClipboardFfiEntry*`
- `pasty_clipboard_store_image(bytes, len, format, bundle_id, app_name, pid)` → `ClipboardFfiEntry*`
- `pasty_clipboard_entry_free(entry)` → void
- `pasty_list_free(list)` → void

## Data Structures

- `ClipboardEntry` (Swift)
  - `id`, `contentHash`, `contentType`, `timestamp`, `latestCopyTime`, `content`, `source`
- `ClipboardFfiEntry` (FFI)
  - `id`, `content_hash`, `content_type`, `timestamp_ms`, `text_content`, `image_path`, `source_bundle_id`, `source_app_name`, `source_pid`

## Error Handling

- FFI returns null pointer on failure; Swift logs error and continues.
- Copy/paste failures should not crash; log and keep panel responsive.
- Delete requires confirmation; cancel leaves state unchanged.

## Side Effects

- Copy: `NSPasteboard.general` write.
- Paste: simulated `Cmd+V` via `CGEvent`.
- Delete: removes entry from local list and storage via Rust core (future FFI delete).
