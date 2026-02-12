import Combine

protocol ClipboardHistoryService {
    func search(query: String, limit: Int, filterType: ClipboardItemRow.ItemType?) -> AnyPublisher<[ClipboardItemRow], Error>
    func totalCount() -> AnyPublisher<Int, Error>
    func get(id: String) -> AnyPublisher<ClipboardItemRow?, Error>
    func delete(id: String) -> AnyPublisher<Void, Error>
    func clearAll() -> AnyPublisher<Void, Error>
    func invalidateSearchCache()
}
