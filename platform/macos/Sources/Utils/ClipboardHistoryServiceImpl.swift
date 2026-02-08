import Combine
import Foundation
import PastyCore

final class ClipboardHistoryServiceImpl: ClipboardHistoryService {
    func search(query: String, limit: Int) -> AnyPublisher<[ClipboardItemRow], Error> {
        return Future { promise in
            var outJson: UnsafeMutablePointer<CChar>? = nil
            let success = pasty_history_search(query, Int32(limit), &outJson)
            
            if !success {
                promise(.failure(NSError(domain: "ClipboardHistoryError", code: -1, userInfo: nil)))
                return
            }
            
            guard let jsonStr = outJson else {
                promise(.success([]))
                return
            }
            
            defer {
                pasty_free_string(jsonStr)
            }
            
            let jsonString = String(cString: jsonStr)
            guard let data = jsonString.data(using: .utf8) else {
                promise(.failure(NSError(domain: "ClipboardHistoryError", code: -2, userInfo: [NSLocalizedDescriptionKey: "Invalid UTF8"])))
                return
            }
            
            do {
                let items = try JSONDecoder().decode([ClipboardItemRow].self, from: data)
                promise(.success(items))
            } catch {
                promise(.failure(error))
            }
        }
        .eraseToAnyPublisher()
    }
}
