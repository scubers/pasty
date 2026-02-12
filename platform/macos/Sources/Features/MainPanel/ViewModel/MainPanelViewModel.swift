import AppKit
import Combine
import Foundation
import KeyboardShortcuts

@MainActor
final class MainPanelViewModel: ObservableObject {
    struct State: Equatable {
        var isVisible = false
        var items: [ClipboardItemRow] = []
        var selectedItemID: String? = nil
        var pendingDeleteItemID: String? = nil
        var previousFrontmostApp: FrontmostAppTracker? = nil
        var searchFocusToken = 0
        var searchQuery = ""
        var isLoading = false
        var errorMessage: String? = nil
        var filterType: ClipboardItemRow.ItemType? = nil

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
        case clipboardContentChanged
        case filterChanged(ClipboardItemRow.ItemType?)
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

        case .clipboardContentChanged:
            historyService.invalidateSearchCache()
            refreshListFromDatabase(selectFirst: state.isVisible)

        case let .filterChanged(newFilter):
            state.filterType = newFilter
            requestSearchFocus()
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
}
