import Foundation

/// Service for retrieving clipboard history from the Rust core
class ClipboardHistory {

    static let shared = ClipboardHistory()

    private init() {}

    /// Retrieve all clipboard entries with pagination
    /// - Parameters:
    ///   - limit: Maximum number of entries to return
    ///   - offset: Number of entries to skip
    /// - Returns: Array of ClipboardEntry items
    func retrieveAllEntries(limit: Int = 100, offset: Int = 0) -> [ClipboardEntry] {
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
        // Note: Current implementation retrieves all entries and filters in Swift
        // Future optimization: Add dedicated FFI function for type-filtered retrieval
        let allEntries = retrieveAllEntries(limit: limit, offset: offset)
        return allEntries.filter { $0.contentType == contentType }
    }

    /// Retrieve a single clipboard entry by ID
    /// - Parameter id: UUID string of the entry to retrieve
    /// - Returns: ClipboardEntry if found, nil otherwise
    func retrieveEntryById(id: String) -> ClipboardEntry? {
        id.withCString { idPtr in
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
            latestCopyTime: timestamp, // Using same timestamp for now
            content: content,
            source: source
        )
    }
}
