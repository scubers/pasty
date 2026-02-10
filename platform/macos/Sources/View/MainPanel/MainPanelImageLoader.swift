import AppKit
import Combine
import Foundation

@MainActor
final class MainPanelImageLoader: ObservableObject {
    @Published private(set) var image: NSImage?
    @Published private(set) var isLoading = false

    private let queue = DispatchQueue(label: "com.pasty2.main-panel.image-loader", qos: .userInitiated)
    private let cache = NSCache<NSString, NSImage>()
    private var workItem: DispatchWorkItem?
    private var currentPath: String?

    func load(path: String?) {
        guard path != currentPath else {
            return
        }

        cancel()
        currentPath = path
        image = nil

        guard let path else {
            isLoading = false
            return
        }

        if let cached = cache.object(forKey: path as NSString) {
            image = cached
            isLoading = false
            return
        }

        isLoading = true

        var item: DispatchWorkItem!
        item = DispatchWorkItem { [weak self] in
            guard let self else { return }
            guard !item.isCancelled else { return }

            let baseDir = SettingsManager.shared.clipboardData
            let absolutePath = baseDir.appendingPathComponent(path).path
            let loaded = NSImage(contentsOfFile: absolutePath).flatMap { self.makeThumbnailIfNeeded($0) }

            DispatchQueue.main.async {
                guard !item.isCancelled else { return }
                self.isLoading = false
                self.image = loaded
                if let loaded {
                    self.cache.setObject(loaded, forKey: path as NSString)
                }
            }
        }

        workItem = item
        queue.async(execute: item)
    }

    func cancel() {
        workItem?.cancel()
        workItem = nil
        isLoading = false
    }

    private func makeThumbnailIfNeeded(_ source: NSImage) -> NSImage {
        let maxDimension: CGFloat = 1600
        let size = source.size
        let largest = max(size.width, size.height)
        guard largest > maxDimension, largest > 0 else {
            return source
        }

        let scale = maxDimension / largest
        let targetSize = NSSize(width: size.width * scale, height: size.height * scale)
        let thumbnail = NSImage(size: targetSize)
        thumbnail.lockFocus()
        source.draw(in: NSRect(origin: .zero, size: targetSize), from: NSRect(origin: .zero, size: size), operation: .copy, fraction: 1)
        thumbnail.unlockFocus()
        return thumbnail
    }
}
