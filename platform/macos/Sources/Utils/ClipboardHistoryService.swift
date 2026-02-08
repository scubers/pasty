import Combine

protocol ClipboardHistoryService {
    func search(query: String, limit: Int) -> AnyPublisher<[ClipboardItemRow], Error>
    func get(id: String) -> AnyPublisher<ClipboardItemRow?, Error>
    func delete(id: String) -> AnyPublisher<Void, Error>
    func invalidateSearchCache()
}
