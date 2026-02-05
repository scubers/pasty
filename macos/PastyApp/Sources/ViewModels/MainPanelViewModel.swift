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

    /// Currently selected entry IDs (data-driven selection)
    @Published var selectedEntryIds: [String] = []

    /// Show only pinned entries
    @Published var isPinnedFilterActive: Bool = false

    /// Loading state
    @Published var isLoading: Bool = false

    /// Error message
    @Published var errorMessage: String? = nil

    /// Previously active application bundle identifier (before panel show)
    var previousActiveAppBundleId: String? = nil

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
            setSelectedEntryIds([id])
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

        syncSelectionWithFilteredEntries()

        Logger.debug("Filtered to \(filteredEntries.count) entries (search: '\(searchText)', filter: \(contentFilter.rawValue), pinned: \(isPinnedFilterActive))")
    }

    private func syncSelectionWithFilteredEntries() {
        guard !filteredEntries.isEmpty else {
            setSelectedEntryIds([])
            return
        }

        if let selectedId = selectedEntryId,
           filteredEntries.contains(where: { $0.id == selectedId }) {
            return
        }

        setSelectedEntryIds([filteredEntries[0].id])
    }

    /// Toggle pin state for an entry
    private func togglePinEntry(id: String) {
        // Find the entry
        guard let index = allEntries.firstIndex(where: { $0.id == id }) else {
            Logger.warning("Entry not found for pin toggle: \(id)")
            return
        }

        let entry = allEntries[index]
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
    private func copyEntry(id: String, completion: ((Bool) -> Void)? = nil) {
        guard let entry = allEntries.first(where: { $0.id == id }) else {
            Logger.warning("Entry not found for copy: \(id)")
            errorMessage = "Entry not found"
            completion?(false)
            return
        }

        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self = self else { return }

            guard let fullEntry = await self.clipboardHistory.retrieveEntryById(id: id) else {
                await MainActor.run {
                    Logger.warning("Entry not found for copy: \(id)")
                    self.errorMessage = "Entry not found"
                    completion?(false)
                }
                return
            }

            await MainActor.run {
                var copySucceeded = true
                switch fullEntry.content {
                case .text(let text):
                    self.copyTextToClipboard(text)
                    Logger.info("Copied text entry: \(entry.title)")

                case .image(let imageFile):
                    let imagesDir = StorageManager.shared.getImagesDirectory()
                    let fullPath = imagesDir.appendingPathComponent(imageFile.path).path
                    if let image = NSImage(contentsOfFile: fullPath) {
                        self.copyImageToClipboard(image)
                        Logger.info("Copied image entry: \(entry.title)")
                    } else {
                        Logger.warning("Failed to load image for copy: \(entry.title)")
                        self.errorMessage = "Failed to load image"
                        copySucceeded = false
                    }
                }

                if copySucceeded, !self.clipboardHistory.updateLatestCopyTime(id: id) {
                    self.errorMessage = "Failed to update copy time"
                    copySucceeded = false
                }
                self.loadEntries()
                completion?(copySucceeded)
            }
        }
    }

    /// Copy entry and simulate paste
    private func pasteEntry(id: String) {
        copyEntry(id: id) { [weak self] success in
            guard let self = self, success else { return }

            guard let previousBundleId = self.previousActiveAppBundleId else {
                Logger.info("No previous app focused; skipping paste")
                self.errorMessage = "No active application to paste into"
                return
            }

            if previousBundleId == Bundle.main.bundleIdentifier {
                Logger.info("Previous app is this app; skipping paste")
                return
            }

            let apps = NSRunningApplication.runningApplications(withBundleIdentifier: previousBundleId)
            if let app = apps.first {
                app.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
            } else {
                Logger.warning("Previous app not found by bundle id: \(previousBundleId)")
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                self.sendPasteEvent()
                Logger.info("Pasted entry: \(id)")
            }
        }
    }

    private func sendPasteEvent() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let cmdVDown = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true)
        let cmdVUp = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false)

        cmdVDown?.flags = .maskCommand
        cmdVUp?.flags = .maskCommand

        cmdVDown?.post(tap: .cghidEventTap)
        cmdVUp?.post(tap: .cghidEventTap)
    }

    /// Delete a single entry with confirmation
    private func deleteEntry(id: String) {
        guard let entry = allEntries.first(where: { $0.id == id }) else {
            Logger.warning("Entry not found for deletion: \(id)")
            return
        }

        confirmDeletion(
            title: "Delete Entry",
            message: "Are you sure you want to delete \"\(entry.title)\"? This action cannot be undone."
        ) { [weak self] confirmed in
            guard let self = self else { return }
            guard confirmed else {
                Logger.info("Delete cancelled for entry: \(entry.title)")
                return
            }

            if !self.clipboardHistory.deleteEntry(id: id) {
                self.errorMessage = "Failed to delete entry"
                Logger.warning("Failed to delete entry: \(entry.title)")
                return
            }

            let removedIndex = self.filteredEntries.firstIndex { $0.id == id }
            self.allEntries.removeAll { $0.id == id }
            self.updateFilters()
            self.updateSelectionAfterDeletion(removedIndex: removedIndex)

            Logger.info("Deleted entry: \(entry.title)")
        }
    }

    /// Delete multiple entries with confirmation
    private func deleteEntries(ids: [String]) {
        guard !ids.isEmpty else { return }

        // Find entries to delete
        let entriesToDelete = allEntries.filter { ids.contains($0.id) }

        confirmDeletion(
            title: "Delete Entries",
            message: "Are you sure you want to delete \(entriesToDelete.count) entr\(entriesToDelete.count == 1 ? "y" : "ies")? This action cannot be undone."
        ) { [weak self] confirmed in
            guard let self = self else { return }
            guard confirmed else {
                Logger.info("Delete cancelled for \(entriesToDelete.count) entries")
                return
            }

            if !self.clipboardHistory.deleteEntries(ids: ids) {
                self.errorMessage = "Failed to delete entries"
                Logger.warning("Failed to delete \(entriesToDelete.count) entries")
                return
            }

            let removedIndex = self.filteredEntries.firstIndex { ids.contains($0.id) }
            self.allEntries.removeAll { ids.contains($0.id) }
            self.updateFilters()
            self.updateSelectionAfterDeletion(removedIndex: removedIndex)

            Logger.info("Deleted \(entriesToDelete.count) entries")
        }
    }

    private func copyTextToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    private func copyImageToClipboard(_ image: NSImage) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([image])
    }

    private func confirmDeletion(title: String, message: String, onConfirm: @escaping (Bool) -> Void) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")

        if let window = NSApp.keyWindow {
            alert.beginSheetModal(for: window) { response in
                onConfirm(response == .alertFirstButtonReturn)
            }
        } else {
            let response = alert.runModal()
            onConfirm(response == .alertFirstButtonReturn)
        }
    }

    private func updateSelectionAfterDeletion(removedIndex: Int?) {
        guard let removedIndex = removedIndex else {
            setSelectedEntryIds([])
            return
        }

        if removedIndex < filteredEntries.count {
            setSelectedEntryIds([filteredEntries[removedIndex].id])
        } else if removedIndex - 1 >= 0, removedIndex - 1 < filteredEntries.count {
            setSelectedEntryIds([filteredEntries[removedIndex - 1].id])
        } else {
            setSelectedEntryIds([])
        }
    }

    func setSelectedEntryIds(_ ids: [String]) {
        selectedEntryIds = ids
        selectedEntryId = ids.first
    }
}
