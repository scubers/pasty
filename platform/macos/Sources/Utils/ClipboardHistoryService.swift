import Combine

protocol ClipboardHistoryService {
    func search(query: String, limit: Int) -> AnyPublisher<[ClipboardItemRow], Error>
}
