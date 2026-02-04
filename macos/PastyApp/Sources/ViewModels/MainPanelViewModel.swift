import Foundation
import Combine
import AppKit

/// Main panel state coordinator following MVVM pattern
/// - @Published properties for View to observe
/// - Handles user actions and converts to data updates
/// - Uses Combine for reactive data streams
@MainActor
class MainPanelViewModel: ObservableObject {
    // MARK: - Published Properties (View observes these)

    /// All loaded entries from database
    @Published var allEntries: [ClipboardEntryListItem] = []

    /// Filtered entries (after search, content filter, pinned filter)
    @Published var filteredEntries: [ClipboardEntryListItem] = []

    /// Search text
    @Published var searchText: String = ""

    /// Content type filter
    @Published var contentFilter: ContentFilter = .all

    /// Currently selected entry ID
    @Published var selectedEntryId: String? = nil

    /// Show only pinned entries
    @Published var isPinnedFilterActive: Bool = false

    /// Loading state
    @Published var isLoading: Bool = false

    /// Error message
    @Published var errorMessage: String? = nil

    // MARK: - Dependencies

    private let clipboardHistory: ClipboardHistory
    private let searchService: SearchService
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init(
        clipboardHistory: ClipboardHistory = .shared,
        searchService: SearchService? = nil
    ) {
        self.clipboardHistory = clipboardHistory
        self.searchService = searchService ?? SearchService()

        setupBindings()
    }

    // MARK: - Setup

    /// Setup reactive bindings between published properties
    private func setupBindings() {
        // When any filter changes, update filtered entries
        Publishers.CombineLatest4($allEntries, $searchText, $contentFilter, $isPinnedFilterActive)
            .debounce(for: .milliseconds(100), scheduler: DispatchQueue.main)
            .sink { [weak self] allEntries, searchText, contentFilter, isPinnedFilterActive in
                self?.updateFilters()
            }
            .store(in: &cancellables)
    }

    // MARK: - User Actions (View calls these)

    /// Handle user action
    func handle(_ action: UserAction) {
        switch action {
        case .loadEntries:
            loadEntries()
        case .selectEntry(let id):
            selectedEntryId = id
        case .search(let query):
            searchText = query
        case .filter(let filter):
            contentFilter = filter
        case .togglePinnedFilter:
            isPinnedFilterActive.toggle()
        case .togglePin(let id):
            togglePinEntry(id: id)
        case .copyEntry(let id):
            copyEntry(id: id)
        case .pasteEntry(let id):
            pasteEntry(id: id)
        case .deleteEntry(let id):
            deleteEntry(id: id)
        case .deleteEntries(let ids):
            deleteEntries(ids: ids)
        case .loadMoreEntries:
            // Not implemented yet
            break
        }
    }

    // MARK: - Business Logic

    /// Load entries from database
    func loadEntries() {
        isLoading = true
        errorMessage = nil

        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self = self else { return }

            let entries = await self.clipboardHistory.retrieveAllEntries(limit: 100, offset: 0)

            await MainActor.run {
                self.isLoading = false

                // Convert to ClipboardEntryListItem
                self.allEntries = entries.map { entry in
                    ClipboardEntryListItem(from: entry)
                }

                Logger.info("Loaded \(self.allEntries.count) entries")
            }
        }
    }

    /// Update filtered entries based on current filters
    private func updateFilters() {
        filteredEntries = searchService.applyFilters(
            entries: allEntries,
            searchText: searchText,
            contentFilter: contentFilter,
            showPinnedOnly: isPinnedFilterActive
        )

        Logger.debug("Filtered to \(filteredEntries.count) entries (search: '\(searchText)', filter: \(contentFilter.rawValue), pinned: \(isPinnedFilterActive))")
    }

    /// Toggle pin state for an entry
    private func togglePinEntry(id: String) {
        // Find the entry
        guard let index = allEntries.firstIndex(where: { $0.id == id }) else {
            Logger.warning("Entry not found for pin toggle: \(id)")
            return
        }

        var entry = allEntries[index]
        let newPinnedState = !entry.isPinned

        // Update the entry (in-memory only for now - database update will come later)
        let updatedEntry = ClipboardEntryListItem(
            id: entry.id,
            title: entry.title,
            preview: entry.preview,
            timestamp: entry.timestamp,
            sourceApp: entry.sourceApp,
            sourceIcon: entry.sourceIcon,
            contentType: entry.contentType,
            isPinned: newPinnedState,
            isSelected: entry.isSelected,
            isSensitive: entry.isSensitive,
            sortTimestamp: entry.sortTimestamp,
            pinnedTimestamp: newPinnedState ? Date() : nil
        )

        allEntries[index] = updatedEntry

        // Reapply filters to update the display
        updateFilters()

        Logger.info("Entry \(newPinnedState ? "pinned" : "unpinned"): \(entry.title)")
    }

    /// Copy entry to clipboard
    private func copyEntry(id: String) {
        guard let entry = allEntries.first(where: { $0.id == id }) else {
            Logger.warning("Entry not found for copy: \(id)")
            return
        }

        // Copy based on content type
        switch entry.preview {
        case .text(let text):
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(text, forType: .string)
            Logger.info("Copied text entry: \(entry.title)")
        case .image:
            // For images, we'd need to load the actual image data
            // This is a placeholder - image copy would need the ImageFile
            Logger.info("Image copy not yet implemented")
        }
    }

    /// Copy entry and simulate paste
    private func pasteEntry(id: String) {
        // First copy to clipboard
        copyEntry(id: id)

        // Then simulate Cmd+V using CGEvent
        let source = CGEventSource(stateID: .combinedSessionState)
        let cmdVDown = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true)
        let cmdVUp = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false)

        cmdVDown?.flags = .maskCommand
        cmdVUp?.flags = .maskCommand

        cmdVDown?.post(tap: .cghidEventTap)
        cmdVUp?.post(tap: .cghidEventTap)

        Logger.info("Pasted entry: \(id)")
    }

    /// Delete a single entry with confirmation
    private func deleteEntry(id: String) {
        guard let entry = allEntries.first(where: { $0.id == id }) else {
            Logger.warning("Entry not found for deletion: \(id)")
            return
        }

        // Show confirmation dialog
        let alert = NSAlert()
        alert.messageText = "Delete Entry"
        alert.informativeText = "Are you sure you want to delete \"\(entry.title)\"? This action cannot be undone."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")

        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else {
            Logger.info("Delete cancelled for entry: \(entry.title)")
            return
        }

        // Remove from allEntries
        allEntries.removeAll { $0.id == id }

        // Reapply filters
        updateFilters()

        Logger.info("Deleted entry: \(entry.title)")
    }

    /// Delete multiple entries with confirmation
    private func deleteEntries(ids: [String]) {
        guard !ids.isEmpty else { return }

        // Find entries to delete
        let entriesToDelete = allEntries.filter { ids.contains($0.id) }

        // Show confirmation dialog
        let alert = NSAlert()
        alert.messageText = "Delete Entries"
        alert.informativeText = "Are you sure you want to delete \(entriesToDelete.count) entr\(entriesToDelete.count == 1 ? "y" : "ies")? This action cannot be undone."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")

        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else {
            Logger.info("Delete cancelled for \(entriesToDelete.count) entries")
            return
        }

        // Remove from allEntries
        allEntries.removeAll { ids.contains($0.id) }

        // Reapply filters
        updateFilters()

        Logger.info("Deleted \(entriesToDelete.count) entries")
    }
}
