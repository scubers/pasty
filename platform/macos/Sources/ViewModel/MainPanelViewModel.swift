import Combine
import Foundation
import KeyboardShortcuts

@MainActor
final class MainPanelViewModel: ObservableObject {
    struct State: Equatable {
        var isVisible = false
        var items: [ClipboardItemRow] = []
        var selectedItem: ClipboardItemRow? = nil
        var searchQuery = ""
        var isLoading = false
        var errorMessage: String? = nil
    }

    enum Action {
        case togglePanel
        case showPanel
        case hidePanel
        case searchChanged(String)
        case itemSelected(ClipboardItemRow)
    }

    @Published private(set) var state = State()
    
    // Internal so App.swift can bind to visibility
    var cancellables = Set<AnyCancellable>()
    
    private let historyService: ClipboardHistoryService
    private let hotkeyService: HotkeyService

    init(historyService: ClipboardHistoryService, hotkeyService: HotkeyService) {
        self.historyService = historyService
        self.hotkeyService = hotkeyService
        
        setupSearchPipeline()
        setupHotkey()
    }

    func send(_ action: Action) {
        switch action {
        case .togglePanel:
            state.isVisible.toggle()
        case .showPanel:
            state.isVisible = true
        case .hidePanel:
            state.isVisible = false
        case let .searchChanged(query):
            search(query: query)
        case let .itemSelected(item):
            state.selectedItem = item
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
                }
            )
            .store(in: &cancellables)
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
