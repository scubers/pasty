import Combine
import Foundation

struct MainPanelSearchStore {
    struct Query: Equatable {
        let text: String
        let filterType: ClipboardItemRow.ItemType?
    }

    func makeDebouncedQueryPublisher(
        searchQueryPublisher: AnyPublisher<String, Never>,
        filterTypePublisher: AnyPublisher<ClipboardItemRow.ItemType?, Never>,
        scheduler: DispatchQueue = .main
    ) -> AnyPublisher<Query, Never> {
        let debouncedSearch = searchQueryPublisher
            .removeDuplicates()
            .debounce(for: .milliseconds(200), scheduler: scheduler)

        let filterChanges = filterTypePublisher
            .removeDuplicates()

        return debouncedSearch
            .combineLatest(filterChanges)
            .map { Query(text: $0.0, filterType: $0.1) }
            .eraseToAnyPublisher()
    }
}
