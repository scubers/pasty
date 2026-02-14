import AppKit
import Combine
import Foundation

@MainActor
final class MainPanelViewModel: ObservableObject {
    struct State: Equatable {
        var isVisible = false
        var items: [ClipboardItemRow] = []
        var selectedItemID: String? = nil
        var pendingDeleteItemID: String? = nil
        var previousFrontmostApp: FrontmostAppTracker? = nil
        var searchFocusToken = 0
        var tagEditorFocusToken = 0
        var searchQuery = ""
        var isLoading = false
        var errorMessage: String? = nil
        var filterType: ClipboardItemRow.ItemType? = nil
        var totalItemCount = 0
        var isTagEditorPresented = false
        var editingTags: [String] = []
        var allTags: [String] = []
        var tagSuggestions: [String] = []
        var selectedSuggestionIndex = -1

        var selectedItem: ClipboardItemRow? {
            guard let selectedItemID else {
                return nil
            }
            return items.first(where: { $0.id == selectedItemID })
        }

        var pendingDeleteItem: ClipboardItemRow? {
            guard let pendingDeleteItemID else {
                return nil
            }
            return items.first(where: { $0.id == pendingDeleteItemID })
        }
    }

    enum Action {
        case togglePanel
        case showPanel
        case hidePanel
        case panelInteracted
        case searchChanged(String)
        case itemSelected(ClipboardItemRow)
        case moveSelectionUp
        case moveSelectionDown
        case deleteSelectedConfirmed
        case copySelected
        case pasteSelectedAndClose
        case prepareDeleteSelected
        case cancelDelete
        case frontmostApplicationTracked(FrontmostAppTracker?)
        case clipboardContentChanged(inserted: Bool)
        case filterChanged(ClipboardItemRow.ItemType?)
        case copyOCRText(String)
        case openTagEditor
        case closeTagEditor
        case saveTags([String])
        case tagAdded(String)
        case tagRemoved(String)
        case tagInputChanged(String)
        case selectTagSuggestion(Int)
    }

    @Published private(set) var state = State()

    // Internal so App.swift can bind to visibility
    var cancellables = Set<AnyCancellable>()

    private let historyService: ClipboardHistoryService
    private let hotkeyService: HotkeyService
    private let interactionService: MainPanelInteractionService
    private let listStore = MainPanelListStore()
    private let selectionStore = MainPanelSelectionStore()
    private let searchStore = MainPanelSearchStore()

    private var activeSearchRequestID = UUID()
    private var searchRequestCancellable: AnyCancellable?
    private var activeTotalCountRequestID = UUID()
    private var totalCountRequestCancellable: AnyCancellable?
    private var itemDetailCancellable: AnyCancellable?
    private let coordinator: AppCoordinator

    init(
        historyService: ClipboardHistoryService,
        hotkeyService: HotkeyService,
        interactionService: MainPanelInteractionService,
        coordinator: AppCoordinator
    ) {
        self.historyService = historyService
        self.hotkeyService = hotkeyService
        self.interactionService = interactionService
        self.coordinator = coordinator

        setupSearchPipeline()
        setupHotkey()
    }

    func send(_ action: Action) {
        switch action {
        case .togglePanel:
            send(state.isVisible ? .hidePanel : .showPanel)

        case .showPanel:
            prepareForPanelShow()
            state.isVisible = true
            requestSearchFocus()
            loadTotalCountSnapshot()
            refreshListFromDatabase(selectFirst: true)

        case .hidePanel:
            state.isVisible = false
            state.pendingDeleteItemID = nil
            state.selectedItemID = nil
            clearSearchInputForNextShow()

        case .panelInteracted:
            guard state.isVisible else {
                return
            }
            requestSearchFocus()

        case let .searchChanged(query):
            state.searchQuery = query
            requestSearchFocus()

        case let .itemSelected(item):
            selectItem(item)

        case .moveSelectionUp:
            state.selectedItemID = selectionStore.movedSelection(
                currentSelectionID: state.selectedItemID,
                in: state.items,
                delta: -1
            )
            requestSearchFocus()

        case .moveSelectionDown:
            state.selectedItemID = selectionStore.movedSelection(
                currentSelectionID: state.selectedItemID,
                in: state.items,
                delta: 1
            )
            requestSearchFocus()

        case .deleteSelectedConfirmed:
            LoggerService.info("Action: deleteSelectedConfirmed")
            deleteSelectedConfirmed()

        case .copySelected:
            LoggerService.info("Action: copySelected")
            copySelected()

        case .pasteSelectedAndClose:
            LoggerService.info("Action: pasteSelectedAndClose")
            pasteSelectedAndClose()

        case .prepareDeleteSelected:
            state.pendingDeleteItemID = state.selectedItemID
            requestSearchFocus()

        case .cancelDelete:
            state.pendingDeleteItemID = nil
            requestSearchFocus()

        case let .frontmostApplicationTracked(tracker):
            state.previousFrontmostApp = tracker

        case let .clipboardContentChanged(inserted):
            historyService.invalidateSearchCache()
            if inserted {
                incrementTotalCountForClipboardInsert()
            }
            refreshListFromDatabase(selectFirst: state.isVisible)

        case let .filterChanged(newFilter):
            state.filterType = newFilter
            requestSearchFocus()

        case let .copyOCRText(text):
            _ = interactionService.copyToPasteboard(text)
            requestSearchFocus()

        case .openTagEditor:
            guard state.selectedItem != nil else {
                return
            }
            loadTagsForSelectedItem()
            loadAllTags()
            state.isTagEditorPresented = true
            state.tagEditorFocusToken &+= 1

        case .closeTagEditor:
            state.isTagEditorPresented = false
            state.editingTags = []
            requestSearchFocus()

        case let .saveTags(tags):
            saveTagsToSelectedItem(tags)

        case let .tagAdded(tag):
            let normalized = tag.trimmingCharacters(in: .whitespaces)
            guard !normalized.isEmpty, !state.editingTags.contains(normalized) else {
                return
            }
            state.editingTags.append(normalized)

        case let .tagRemoved(tag):
            state.editingTags.removeAll { $0 == tag }
        case let .tagInputChanged(query):
            updateTagSuggestions(query: query)
        case let .selectTagSuggestion(index):
            selectTagSuggestionAt(index: index)
        }
    }

    private func setupSearchPipeline() {
        let queryPublisher = $state
            .map(\.searchQuery)
            .eraseToAnyPublisher()
        let filterPublisher = $state
            .map(\.filterType)
            .eraseToAnyPublisher()

        searchStore.makeDebouncedQueryPublisher(
            searchQueryPublisher: queryPublisher,
            filterTypePublisher: filterPublisher
        )
            .sink { [weak self] query in
                guard let self else {
                    return
                }
                guard state.isVisible else {
                    return
                }
                refreshListFromDatabase(query: query.text, filterType: query.filterType, selectFirst: true)
            }
            .store(in: &cancellables)
    }

    private func prepareForPanelShow() {
        state.pendingDeleteItemID = nil
        state.selectedItemID = nil
        clearSearchInputForNextShow()
    }

    private func clearSearchInputForNextShow() {
        guard !state.searchQuery.isEmpty else {
            return
        }
        state.searchQuery = ""
    }

    private func refreshListFromDatabase(
        query: String? = nil,
        filterType: ClipboardItemRow.ItemType? = nil,
        selectFirst: Bool
    ) {
        let effectiveQuery = query ?? state.searchQuery
        let effectiveFilterType = filterType ?? state.filterType

        state.isLoading = true
        state.errorMessage = nil

        let requestID = UUID()
        activeSearchRequestID = requestID

        searchRequestCancellable?.cancel()
        searchRequestCancellable = historyService.search(query: effectiveQuery, limit: 100, filterType: effectiveFilterType)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    guard let self else {
                        return
                    }
                    guard self.activeSearchRequestID == requestID else {
                        return
                    }
                    self.state.isLoading = false
                    if case let .failure(error) = completion {
                        LoggerService.error("Search failed: \(error.localizedDescription)")
                        self.state.errorMessage = error.localizedDescription
                    }
                },
                receiveValue: { [weak self] items in
                    guard let self else {
                        return
                    }
                    guard self.activeSearchRequestID == requestID else {
                        return
                    }
                    self.state.items = items
                    if selectFirst {
                        self.state.selectedItemID = self.selectionStore.defaultSelectionID(in: items)
                    }
                }
            )
    }

    private func loadTotalCountSnapshot() {
        let requestID = UUID()
        activeTotalCountRequestID = requestID

        totalCountRequestCancellable?.cancel()
        totalCountRequestCancellable = historyService.totalCount()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    guard let self else {
                        return
                    }
                    guard self.activeTotalCountRequestID == requestID else {
                        return
                    }
                    if case let .failure(error) = completion {
                        LoggerService.error("Total count fetch failed: \(error.localizedDescription)")
                    }
                },
                receiveValue: { [weak self] totalCount in
                    guard let self else {
                        return
                    }
                    guard self.activeTotalCountRequestID == requestID else {
                        return
                    }
                    self.state.totalItemCount = totalCount
                }
            )
    }

    private func incrementTotalCountForClipboardInsert() {
        let maxCount = max(coordinator.settings.history.maxCount, 0)
        if maxCount == 0 {
            state.totalItemCount = 0
            return
        }
        state.totalItemCount = min(state.totalItemCount + 1, maxCount)
    }

    private func selectItem(_ item: ClipboardItemRow) {
        state.selectedItemID = item.id
        requestSearchFocus()

        itemDetailCancellable?.cancel()
        itemDetailCancellable = historyService.get(id: item.id)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if let self, case let .failure(error) = completion {
                        LoggerService.error("Failed to load full item: \(error.localizedDescription)")
                        self.state.errorMessage = error.localizedDescription
                    }
                },
                receiveValue: { [weak self] fullItem in
                    guard let self, let fullItem else {
                        return
                    }
                    guard self.state.selectedItemID == fullItem.id,
                          self.state.items.contains(where: { $0.id == fullItem.id }) else {
                        return
                    }

                    self.state.items = self.listStore.replacingItem(fullItem, in: self.state.items)
                }
            )
    }

    private func deleteSelectedConfirmed() {
        guard let pendingDeleteItemID = state.pendingDeleteItemID else {
            return
        }

        let previousItems = state.items

        historyService.delete(id: pendingDeleteItemID)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    guard let self else {
                        return
                    }
                    if case let .failure(error) = completion {
                        self.state.errorMessage = error.localizedDescription
                    }
                },
                receiveValue: { [weak self] in
                    guard let self else {
                        return
                    }

                    self.state.pendingDeleteItemID = nil
                    let updatedItems = self.listStore.removingItem(withID: pendingDeleteItemID, from: self.state.items)
                    self.state.items = updatedItems
                    self.state.totalItemCount = max(self.state.totalItemCount - 1, 0)
                    self.state.selectedItemID = self.selectionStore.selectionAfterDeletion(
                        deletedID: pendingDeleteItemID,
                        previousItems: previousItems,
                        updatedItems: updatedItems,
                        currentSelectionID: self.state.selectedItemID
                    )
                    self.requestSearchFocus()
                }
            )
            .store(in: &cancellables)
    }

    private func copySelected() {
        guard let selectedItem = state.selectedItem else {
            return
        }
        _ = copyToPasteboard(item: selectedItem)
        requestSearchFocus()
    }

    private func pasteSelectedAndClose() {
        guard let selectedItem = state.selectedItem else {
            return
        }

        guard copyToPasteboard(item: selectedItem) else {
            state.errorMessage = "Failed to copy item"
            return
        }

        send(.hidePanel)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in
            self?.interactionService.sendPasteCommand()
        }
    }

    private func copyToPasteboard(item: ClipboardItemRow) -> Bool {
        switch item.type {
        case .text:
            return interactionService.copyToPasteboard(item.content)
        case .image:
            guard let imagePath = item.imagePath else {
                return false
            }
            let absolutePath = coordinator.clipboardData.appendingPathComponent(imagePath).path
            guard let image = NSImage(contentsOfFile: absolutePath) else {
                return false
            }
            return interactionService.copyToPasteboard(image)
        }
    }

    private func requestSearchFocus() {
        guard !state.isTagEditorPresented else {
            return
        }
        state.searchFocusToken &+= 1
    }

    private func setupHotkey() {
        hotkeyService.register(name: .togglePanel)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                self?.send(.togglePanel)
            }
            .store(in: &cancellables)
    }

    private func loadTagsForSelectedItem() {
        guard let selectedItem = state.selectedItem else {
            return
        }
        historyService.getTags(id: selectedItem.id)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if let self, case let .failure(error) = completion {
                        LoggerService.error("Failed to load tags: \(error.localizedDescription)")
                    }
                },
                receiveValue: { [weak self] tags in
                    self?.state.editingTags = tags
                }
            )
            .store(in: &cancellables)
    }

    private func saveTagsToSelectedItem(_ tags: [String]) {
        guard let selectedItem = state.selectedItem else {
            return
        }
        historyService.setTags(id: selectedItem.id, tags: tags)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    guard let self else { return }
                    if case let .failure(error) = completion {
                        LoggerService.error("Failed to save tags: \(error.localizedDescription)")
                        self.state.errorMessage = error.localizedDescription
                    }
                    self.state.isTagEditorPresented = false
                    self.state.editingTags = []
                    self.requestSearchFocus()
                },
                receiveValue: { [weak self] in
                    guard let self else {
                        return
                    }
                    self.historyService.invalidateSearchCache()
                    self.refreshListFromDatabase(selectFirst: false)
                }
            )
            .store(in: &cancellables)
    }

    private func loadAllTags() {
        state.allTags = []
        let allItems = state.items
        var tagSet = Set<String>()
        for item in allItems {
            for tag in MainPanelItemMetadata.tags(from: item.metadata) {
                tagSet.insert(tag)
            }
        }
        state.allTags = Array(tagSet).sorted()
    }

    private func updateTagSuggestions(query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            state.tagSuggestions = []
            state.selectedSuggestionIndex = -1
            return
        }
        let filtered = state.allTags.filter { tag in
            !state.editingTags.contains(tag) &&
            tag.localizedCaseInsensitiveContains(trimmed)
        }
        state.tagSuggestions = Array(filtered.prefix(5))
        state.selectedSuggestionIndex = state.tagSuggestions.isEmpty ? -1 : 0
    }

    private func selectTagSuggestionAt(index: Int) {
        guard index >= 0, index < state.tagSuggestions.count else { return }
        let tag = state.tagSuggestions[index]
        if !state.editingTags.contains(tag) {
            state.editingTags.append(tag)
        }
        state.tagSuggestions = []
        state.selectedSuggestionIndex = -1
    }
}
