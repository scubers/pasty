import Foundation

/// Service for retrieving clipboard history from the Rust core
/// Supports mock mode for development without Rust dependency
class ClipboardHistory {

    static let shared = ClipboardHistory()

    private let useMockData: Bool
    private let mockHistory = MockClipboardHistory()

    private init() {
        // Use mock data if Rust functions are not available
        // Check by trying to resolve a Rust symbol
        useMockData = !Self.isRustAvailable()
        if useMockData {
            NSLog("[ClipboardHistory] Using MOCK data mode")
        }
    }

    /// Check if Rust FFI is available
    private static func isRustAvailable() -> Bool {
        // Try to resolve a Rust function symbol
        let symbolName = "pasty_get_clipboard_history"
        if let symbol = dlopen(nil, RTLD_NOW) {
            let ptr: UnsafeMutableRawPointer? = dlsym(symbol, symbolName)
            dlclose(symbol)
            return ptr != nil
        }
        return false
    }

    /// Retrieve all clipboard entries with pagination
    /// - Parameters:
    ///   - limit: Maximum number of entries to return
    ///   - offset: Number of entries to skip
    /// - Returns: Array of ClipboardEntry items
    func retrieveAllEntries(limit: Int = 100, offset: Int = 0) -> [ClipboardEntry] {
        if useMockData {
            return mockHistory.retrieveAllEntries(limit: limit, offset: offset)
        }

        var entries: [ClipboardEntry] = []

        let listPtr = pasty_get_clipboard_history(limit, offset)

        guard let list = listPtr else {
            NSLog("[ClipboardHistory] Failed to retrieve history")
            return entries
        }

        defer {
            pasty_list_free(list)
        }

        let count = list.pointee.count
        NSLog("[ClipboardHistory] Retrieved \(count) entries")

        guard count > 0 else {
            return entries
        }

        let entriesArray = list.pointee.entries
        for i in 0..<count {
            let entryPtrOptional = entriesArray.advanced(by: i).pointee
            guard let entryPtr = entryPtrOptional else {
                continue
            }
            if let entry = convertFFIEntry(entryPtr) {
                entries.append(entry)
            }
        }

        return entries
    }

    /// Retrieve clipboard entries filtered by content type
    /// - Parameters:
    ///   - contentType: The type of content to filter by
    ///   - limit: Maximum number of entries to return
    ///   - offset: Number of entries to skip
    /// - Returns: Array of ClipboardEntry items matching the content type
    func retrieveEntriesFiltered(contentType: ContentType, limit: Int = 100, offset: Int = 0) -> [ClipboardEntry] {
        if useMockData {
            return mockHistory.retrieveEntriesFiltered(contentType: contentType, limit: limit, offset: offset)
        }

        // Note: Current implementation retrieves all entries and filters in Swift
        // Future optimization: Add dedicated FFI function for type-filtered retrieval
        let allEntries = retrieveAllEntries(limit: limit, offset: offset)
        return allEntries.filter { $0.contentType == contentType }
    }

    /// Check if clipboard history is approaching the 10,000 entry limit
    /// - Returns: True if total count is >= 90% of limit (9,000 entries)
    func isNearCapacityLimit() -> Bool {
        let totalEntriesCount = getTotalCount()
        let softLimit = 10_000
        let warningThreshold = Int(Double(softLimit) * 0.9) // 90% of limit

        return totalEntriesCount >= warningThreshold
    }

    /// Get total count of clipboard entries
    /// - Returns: Total number of entries in history
    private func getTotalCount() -> Int {
        if useMockData {
            return mockHistory.getTotalCount()
        }

        // Note: In production, this would be optimized via FFI
        // For now, retrieve all entries (unbounded) to get count
        let allEntries = retrieveAllEntries(limit: Int.max, offset: 0)
        return allEntries.count
    }

    /// Retrieve a single clipboard entry by ID
    /// - Parameter id: UUID string of the entry to retrieve
    /// - Returns: ClipboardEntry if found, nil otherwise
    func retrieveEntryById(id: String) -> ClipboardEntry? {
        if useMockData {
            return mockHistory.retrieveEntryById(id: id)
        }

        return id.withCString { idPtr -> ClipboardEntry? in
            guard let entryPtr = pasty_get_entry_by_id(idPtr) else {
                NSLog("[ClipboardHistory] Entry not found: \(id)")
                return nil
            }

            defer {
                pasty_clipboard_entry_free(entryPtr)
            }

            return convertFFIEntry(entryPtr)
        }
    }

    /// Update latest copy time for entry by ID
    func updateLatestCopyTime(id: String) -> Bool {
        if useMockData {
            return true
        }

        let result: Int32 = id.withCString { idPtr in
            pasty_clipboard_update_latest_copy_time_by_id(idPtr)
        }

        if result != 0 {
            NSLog("[ClipboardHistory] Failed to update latest copy time: \(lastErrorMessage())")
        }

        return result == 0
    }

    /// Delete a single entry by ID
    func deleteEntry(id: String) -> Bool {
        if useMockData {
            return true
        }

        let result: Int32 = id.withCString { idPtr in
            pasty_clipboard_delete_entry_by_id(idPtr)
        }

        if result != 0 {
            NSLog("[ClipboardHistory] Failed to delete entry: \(lastErrorMessage())")
        }

        return result == 0
    }

    /// Delete multiple entries by IDs
    func deleteEntries(ids: [String]) -> Bool {
        if ids.isEmpty {
            return true
        }
        if useMockData {
            return true
        }

        let mutablePointers = ids.map { strdup($0) }
        defer {
            for ptr in mutablePointers {
                free(ptr)
            }
        }

        if mutablePointers.contains(where: { $0 == nil }) {
            NSLog("[ClipboardHistory] Failed to allocate C strings for delete")
            return false
        }

        let constPointers: [UnsafePointer<CChar>?] = mutablePointers.map { ptr in
            guard let ptr else { return nil }
            return UnsafePointer(ptr)
        }

        let result: Int32 = constPointers.withUnsafeBufferPointer { buffer in
            guard let baseAddress = buffer.baseAddress else {
                return 0
            }
            return pasty_clipboard_delete_entries_by_ids(baseAddress, buffer.count)
        }

        if result != 0 {
            NSLog("[ClipboardHistory] Failed to delete entries: \(lastErrorMessage())")
        }

        return result == 0
    }

    // MARK: - Private Helpers

    /// Convert FFI entry to Swift ClipboardEntry
    private func convertFFIEntry(_ entryPtr: UnsafeMutablePointer<ClipboardFfiEntry>) -> ClipboardEntry? {
        let ffiEntry = entryPtr.pointee

        // Extract ID
        let id = String(cString: ffiEntry.id)

        // Extract content hash
        let contentHash = String(cString: ffiEntry.content_hash)

        // Extract timestamp
        let timestamp = Date(timeIntervalSince1970: TimeInterval(ffiEntry.timestamp_ms) / 1000.0)

        // Extract latest copy time
        let latestCopyTime = Date(timeIntervalSince1970: TimeInterval(ffiEntry.latest_copy_time_ms) / 1000.0)

        // Extract content type
        let contentType: ContentType
        switch ffiEntry.content_type {
        case .text:
            contentType = .text
        case .image:
            contentType = .image
        }

        // Extract content
        let content: Content
        switch contentType {
        case .text:
            let text = String(cString: ffiEntry.text_content)
            content = .text(text)

        case .image:
            let imagePath = String(cString: ffiEntry.image_path)
            content = .image(ImageFile(path: imagePath, size: 0, dimensions: nil, format: .unknown))
        }

        // Extract source app info
        let sourceBundleId = String(cString: ffiEntry.source_bundle_id)
        let sourceAppName = String(cString: ffiEntry.source_app_name)
        let sourcePid = Int32(bitPattern: ffiEntry.source_pid)

        let source = SourceApplication(
            bundleId: sourceBundleId,
            appName: sourceAppName,
            pid: sourcePid
        )

        return ClipboardEntry(
            id: id,
            contentHash: contentHash,
            contentType: contentType,
            timestamp: timestamp,
            latestCopyTime: latestCopyTime,
            content: content,
            source: source
        )
    }

    private func lastErrorMessage() -> String {
        guard let ptr = pasty_get_last_error() else {
            return "Unknown error"
        }
        return String(cString: ptr)
    }
}
