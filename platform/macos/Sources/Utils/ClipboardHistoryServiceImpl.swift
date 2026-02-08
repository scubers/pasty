import Combine
import Foundation
import PastyCore

final class ClipboardHistoryServiceImpl: ClipboardHistoryService {
    private struct CacheKey: Hashable {
        let query: String
        let limit: Int
        let previewLength: Int
    }

    private let cacheLimit = 50
    private let previewLength = 200
    private let workQueue = DispatchQueue(label: "ClipboardHistoryServiceImpl.queue", qos: .userInitiated)
    private var searchCache: [CacheKey: [ClipboardItemRow]] = [:]
    private var cacheOrder: [CacheKey] = []
    private let cacheLock = NSLock()

    func search(query: String, limit: Int) -> AnyPublisher<[ClipboardItemRow], Error> {
        let cacheKey = CacheKey(query: query, limit: limit, previewLength: previewLength)
        if let cached = cachedValue(for: cacheKey) {
            return Just(cached)
                .setFailureType(to: Error.self)
                .eraseToAnyPublisher()
        }

        return Future { promise in
            self.workQueue.async {
                var outJson: UnsafeMutablePointer<CChar>? = nil
                let success = pasty_history_search(query, Int32(limit), Int32(self.previewLength), &outJson)

                if !success {
                    promise(.failure(NSError(domain: "ClipboardHistoryError", code: -1, userInfo: nil)))
                    return
                }

                guard let jsonStr = outJson else {
                    self.setCachedValue([], for: cacheKey)
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
                    self.setCachedValue(items, for: cacheKey)
                    promise(.success(items))
                } catch {
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }

    func get(id: String) -> AnyPublisher<ClipboardItemRow?, Error> {
        return Future { promise in
            self.workQueue.async {
                guard let jsonPtr = pasty_history_get_json(id) else {
                    promise(.success(nil))
                    return
                }

                defer {
                    pasty_free_string(jsonPtr)
                }

                let jsonString = String(cString: jsonPtr)
                guard let data = jsonString.data(using: .utf8) else {
                    promise(.failure(NSError(domain: "ClipboardHistoryError", code: -3, userInfo: [NSLocalizedDescriptionKey: "Invalid UTF8"])))
                    return
                }

                do {
                    let item = try JSONDecoder().decode(ClipboardItemRow.self, from: data)
                    promise(.success(item))
                } catch {
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }

    func invalidateSearchCache() {
        cacheLock.lock()
        searchCache.removeAll(keepingCapacity: false)
        cacheOrder.removeAll(keepingCapacity: false)
        cacheLock.unlock()
    }

    private func cachedValue(for key: CacheKey) -> [ClipboardItemRow]? {
        cacheLock.lock()
        let value = searchCache[key]
        if value != nil {
            touchCacheKey(key)
        }
        cacheLock.unlock()
        return value
    }

    private func setCachedValue(_ value: [ClipboardItemRow], for key: CacheKey) {
        cacheLock.lock()
        searchCache[key] = value
        touchCacheKey(key)
        while cacheOrder.count > cacheLimit {
            let evicted = cacheOrder.removeFirst()
            searchCache.removeValue(forKey: evicted)
        }
        cacheLock.unlock()
    }

    private func touchCacheKey(_ key: CacheKey) {
        if let index = cacheOrder.firstIndex(of: key) {
            cacheOrder.remove(at: index)
        }
        cacheOrder.append(key)
    }
}
