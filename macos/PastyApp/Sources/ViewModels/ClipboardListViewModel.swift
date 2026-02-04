import Foundation
import Combine

/// List-specific view model for clipboard entries display
/// Manages list state and selection
@MainActor
class ClipboardListViewModel: ObservableObject {
    // MARK: - Published Properties

    /// Entries to display
    @Published var entries: [ClipboardEntryListItem] = []

    /// Loading state
    @Published var isLoading: Bool = false

    /// Currently selected row index
    @Published var selectedRow: Int? = nil

    /// Scroll position
    @Published var scrollPosition: CGFloat = 0

    /// Error message
    @Published var errorMessage: String? = nil

    // MARK: - Dependencies

    private var mainPanelViewModel: MainPanelViewModel?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init() {
        setupBindings()
    }

    // MARK: - Setup

    /// Bind to main panel view model
    func bindToMainPanelViewModel(_ viewModel: MainPanelViewModel) {
        self.mainPanelViewModel = viewModel

        // Observe filtered entries
        viewModel.$filteredEntries
            .receive(on: DispatchQueue.main)
            .assign(to: &$entries)

        // Observe loading state
        viewModel.$isLoading
            .receive(on: DispatchQueue.main)
            .assign(to: &$isLoading)

        // Observe errors
        viewModel.$errorMessage
            .receive(on: DispatchQueue.main)
            .assign(to: &$errorMessage)
    }

    private func setupBindings() {
        // Additional bindings if needed
    }

    // MARK: - User Actions

    /// Handle entry selection
    func onSelectEntry(id: String) {
        guard let index = entries.firstIndex(where: { $0.id == id }) else {
            Logger.warning("Entry not found: \(id)")
            return
        }

        selectedRow = index

        // Notify main panel view model
        mainPanelViewModel?.handle(.selectEntry(id: id))

        Logger.debug("Selected entry at row \(index): \(id)")
    }

    /// Handle entry selection by row index
    func onSelectRow(_ row: Int) {
        guard row >= 0 && row < entries.count else {
            Logger.warning("Invalid row index: \(row)")
            return
        }

        let entry = entries[row]
        selectedRow = row

        // Notify main panel view model
        mainPanelViewModel?.handle(.selectEntry(id: entry.id))

        Logger.debug("Selected entry at row \(row): \(entry.id)")
    }

    /// Clear selection
    func clearSelection() {
        selectedRow = nil
        mainPanelViewModel?.selectedEntryId = nil
    }
}
