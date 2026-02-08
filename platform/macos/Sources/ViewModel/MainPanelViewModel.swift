import Combine
import AppKit
import Foundation
import KeyboardShortcuts

@MainActor
final class MainPanelViewModel: ObservableObject {
    struct State: Equatable {
        var isVisible = false
        var items: [ClipboardItemRow] = []
        var selectedItem: ClipboardItemRow? = nil
        var selectionIndex: Int? = nil
        var pendingDeleteItem: ClipboardItemRow? = nil
        var previousFrontmostApp: FrontmostAppTracker? = nil
        var shouldFocusSearch = false
        var searchQuery = ""
        var isLoading = false
        var errorMessage: String? = nil
    }

    enum Action {
        case togglePanel
        case showPanel
        case hidePanel
        case panelShown
        case panelHidden
        case searchChanged(String)
        case itemSelected(ClipboardItemRow)
        case moveSelectionUp
        case moveSelectionDown
        case selectFirstIfNeeded
        case deleteSelectedConfirmed
        case copySelected
        case pasteSelectedAndClose
        case prepareDeleteSelected
        case cancelDelete
        case frontmostApplicationTracked(FrontmostAppTracker?)
        case clipboardContentChanged
    }

    @Published private(set) var state = State()
    
    // Internal so App.swift can bind to visibility
    var cancellables = Set<AnyCancellable>()
    
    private let historyService: ClipboardHistoryService
    private let hotkeyService: HotkeyService
    private let interactionService: MainPanelInteractionService
    private var pendingSelectionIndexAfterRefresh: Int?

    init(
        historyService: ClipboardHistoryService,
        hotkeyService: HotkeyService,
        interactionService: MainPanelInteractionService
    ) {
        self.historyService = historyService
        self.hotkeyService = hotkeyService
        self.interactionService = interactionService
        
        setupSearchPipeline()
        setupHotkey()
    }

    func send(_ action: Action) {
        switch action {
        case .togglePanel:
            send(state.isVisible ? .hidePanel : .showPanel)
        case .showPanel:
            state.isVisible = true
            send(.panelShown)
        case .hidePanel:
            state.isVisible = false
            send(.panelHidden)
        case .panelShown:
            requestSearchFocus()
            refreshList(selectFirst: true)
        case .panelHidden:
            state.searchQuery = ""
            state.pendingDeleteItem = nil
            state.selectionIndex = nil
            state.selectedItem = nil
            requestSearchFocus()
            refreshList(selectFirst: true)
        case let .searchChanged(query):
            search(query: query)
        case let .itemSelected(item):
            selectItem(item)
        case .moveSelectionUp:
            moveSelection(delta: -1)
        case .moveSelectionDown:
            moveSelection(delta: 1)
        case .selectFirstIfNeeded:
            selectFirstIfNeeded()
        case .deleteSelectedConfirmed:
            deleteSelectedConfirmed()
        case .copySelected:
            copySelected()
        case .pasteSelectedAndClose:
            pasteSelectedAndClose()
        case .prepareDeleteSelected:
            state.pendingDeleteItem = state.selectedItem
            requestSearchFocus()
        case .cancelDelete:
            state.pendingDeleteItem = nil
            requestSearchFocus()
        case let .frontmostApplicationTracked(tracker):
            state.previousFrontmostApp = tracker
        case .clipboardContentChanged:
            refreshList(selectFirst: true)
        }
    }

    private func search(query: String) {
        state.searchQuery = query
    }
    
    private func setupSearchPipeline() {
        $state
            .map(\.searchQuery)
            .removeDuplicates()
            .debounce(for: .milliseconds(200), scheduler: DispatchQueue.main)
            .sink { [weak self] query in
                self?.performSearch(query: query)
            }
            .store(in: &cancellables)
    }
    
    private func performSearch(query: String) {
        state.isLoading = true
        historyService.search(query: query, limit: 100)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.state.isLoading = false
                    if case let .failure(error) = completion {
                        self?.state.errorMessage = error.localizedDescription
                    }
                },
                receiveValue: { [weak self] items in
                    self?.state.items = items
                    if let self, let preferredIndex = self.pendingSelectionIndexAfterRefresh {
                        self.pendingSelectionIndexAfterRefresh = nil
                        self.selectAfterDeletion(preferredIndex: preferredIndex)
                    } else {
                        self?.send(.selectFirstIfNeeded)
                    }
                }
            )
            .store(in: &cancellables)
    }

    private func refreshList(selectFirst: Bool) {
        historyService.invalidateSearchCache()
        performSearch(query: state.searchQuery)
        if selectFirst {
            send(.selectFirstIfNeeded)
        }
    }

    private func selectItem(_ item: ClipboardItemRow) {
        state.selectedItem = item
        state.selectionIndex = state.items.firstIndex(where: { $0.id == item.id })
        requestSearchFocus()
        historyService.get(id: item.id)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case let .failure(error) = completion {
                        self?.state.errorMessage = error.localizedDescription
                    }
                },
                receiveValue: { [weak self] fullItem in
                    guard let self, let fullItem else {
                        return
                    }
                    if self.state.selectedItem?.id == fullItem.id {
                        self.state.selectedItem = fullItem
                        self.state.selectionIndex = self.state.items.firstIndex(where: { $0.id == fullItem.id })
                    }
                }
            )
            .store(in: &cancellables)
    }

    private func moveSelection(delta: Int) {
        guard !state.items.isEmpty else {
            state.selectionIndex = nil
            state.selectedItem = nil
            requestSearchFocus()
            return
        }

        let currentIndex = state.selectionIndex
            ?? state.items.firstIndex(where: { $0.id == state.selectedItem?.id })
            ?? 0
        let count = state.items.count
        let nextIndex = (currentIndex + delta + count) % count
        state.selectionIndex = nextIndex
        state.selectedItem = state.items[nextIndex]
        requestSearchFocus()
    }

    private func selectFirstIfNeeded() {
        guard !state.items.isEmpty else {
            state.selectedItem = nil
            state.selectionIndex = nil
            return
        }

        if let selectedItem = state.selectedItem,
           let existingIndex = state.items.firstIndex(where: { $0.id == selectedItem.id }) {
            state.selectionIndex = existingIndex
            state.selectedItem = state.items[existingIndex]
            return
        }

        state.selectionIndex = 0
        state.selectedItem = state.items[0]
    }

    private func deleteSelectedConfirmed() {
        guard let pendingDeleteItem = state.pendingDeleteItem else {
            return
        }

        let previousIndex = state.selectionIndex ?? 0
        historyService.delete(id: pendingDeleteItem.id)
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
                    self.state.pendingDeleteItem = nil
                    self.pendingSelectionIndexAfterRefresh = previousIndex
                    self.refreshList(selectFirst: false)
                    self.requestSearchFocus()
                }
            )
            .store(in: &cancellables)
    }

    private func selectAfterDeletion(preferredIndex: Int) {
        guard !state.items.isEmpty else {
            state.selectedItem = nil
            state.selectionIndex = nil
            return
        }

        let adjustedIndex = min(preferredIndex, state.items.count - 1)
        state.selectionIndex = adjustedIndex
        state.selectedItem = state.items[adjustedIndex]
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
            let absolutePath = AppPaths.appDataDirectory().appendingPathComponent(imagePath).path
            guard let image = NSImage(contentsOfFile: absolutePath) else {
                return false
            }
            return interactionService.copyToPasteboard(image)
        }
    }

    private func requestSearchFocus() {
        state.shouldFocusSearch.toggle()
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
