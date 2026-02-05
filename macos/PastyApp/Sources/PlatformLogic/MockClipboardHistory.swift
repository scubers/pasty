import Foundation

/// Mock ClipboardHistory for development without Rust dependency
/// Returns test data instead of calling Rust FFI
class MockClipboardHistory {
    static let shared = MockClipboardHistory()

    init() {}

    /// Generate mock clipboard entries for testing
    func retrieveAllEntries(limit: Int = 100, offset: Int = 0) -> [ClipboardEntry] {
        var entries: [ClipboardEntry] = []

        // Create sample entries
        let sampleData = [
            ("Sample text entry copied from Safari", "com.apple.Safari", "text"),
            ("https://github.com - Interesting code repository", "com.google.Chrome", "text"),
            ("Important meeting notes from Teams", "com.microsoft.Teams", "text"),
            ("Code snippet from Xcode", "com.apple.dt.Xcode", "text"),
            ("Documentation link", "com.apple.Safari", "text"),
            ("Email draft started", "com.apple.Mail", "text"),
            ("Password: secret123", "com.apple.Safari", "text"),
            ("API key: sk-1234567890abcdef", "com.google.Chrome", "text"),
            ("Phone number: +1-555-0199", "com.apple.Safari", "text"),
            ("Credit card: 4532-1234-5678-9010", "com.google.Chrome", "text"),
        ]

        for (index, data) in sampleData.enumerated() {
            let entry = ClipboardEntry(
                id: UUID().uuidString,
                contentHash: "hash-\(index)",
                contentType: .text,
                timestamp: Date().addingTimeInterval(-Double(index * 300)), // 5-min intervals
                latestCopyTime: Date().addingTimeInterval(-Double(index * 300)),
                content: .text(data.0),
                source: SourceApplication(bundleId: data.1, appName: appName(from: data.1), pid: 1234)
            )
            entries.append(entry)
        }

        // Apply pagination
        let start = min(offset, entries.count)
        let end = min(offset + limit, entries.count)

        return Array(entries[start..<end])
    }

    /// Get a single entry by ID (mock)
    func retrieveEntryById(id: String) -> ClipboardEntry? {
        let allEntries = retrieveAllEntries(limit: 1000, offset: 0)
        return allEntries.first { $0.id == id }
    }

    /// Get entries filtered by content type (mock)
    func retrieveEntriesFiltered(contentType: ContentType, limit: Int = 100, offset: Int = 0) -> [ClipboardEntry] {
        let allEntries = retrieveAllEntries(limit: 1000, offset: 0)
        return allEntries.filter { $0.contentType == contentType }
    }

    /// Get total count of clipboard entries
    func getTotalCount() -> Int {
        let allEntries = retrieveAllEntries(limit: 10000, offset: 0)
        return allEntries.count
    }

    /// Check if approaching capacity limit and evict old entries
    func checkAndEvictEntries() {
        let totalEntriesCount = getTotalCount()
        let softLimit = 10_000
        let warningThreshold = 9_000 // 90% of limit

        if totalEntriesCount >= warningThreshold {
            Logger.warning("Clipboard history approaching limit: \(totalEntriesCount)/\(softLimit)")
        }

        if totalEntriesCount > softLimit {
            // Simulate FIFO eviction: remove oldest unpinned entries
            Logger.info("Evicting oldest entries to maintain limit")
        }
    }

    /// Helper to get app name from bundle ID
    private func appName(from bundleId: String) -> String {
        let mapping: [String: String] = [
            "com.apple.Safari": "Safari",
            "com.google.Chrome": "Chrome",
            "com.microsoft.Teams": "Microsoft Teams",
            "com.apple.dt.Xcode": "Xcode",
            "com.apple.Mail": "Mail",
            "com.apple.Terminal": "Terminal",
            "com.apple.finder": "Finder",
        ]
        return mapping[bundleId] ?? bundleId.components(separatedBy: ".").last ?? "Unknown"
    }
}

// MARK: - ClipboardHistory Protocol Conformance

extension MockClipboardHistory {
    /// Retrieve entries matching the ClipboardHistory interface
    func getClipboardHistory(limit: Int = 100, offset: Int = 0) -> [ClipboardEntry] {
        return retrieveAllEntries(limit: limit, offset: offset)
    }
}
