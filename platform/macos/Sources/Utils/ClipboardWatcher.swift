// Pasty2 - Copyright (c) 2026. MIT License.

import Cocoa
import PastyCore

extension Notification.Name {
    static let clipboardImageCaptured = Notification.Name("clipboardImageCaptured")
}

final class ClipboardWatcher {
    private static let maxPayloadBytes = 10 * 1024 * 1024

    typealias TextIngest = (_ text: String, _ sourceAppID: String) -> Bool
    typealias ImageIngest = (_ bytes: Data, _ width: Int, _ height: Int, _ formatHint: String, _ sourceAppID: String) -> Bool

    private var timer: Timer?
    private var lastChangeCount: Int
    private let pasteboard: NSPasteboard
    private let ingestText: TextIngest
    private let ingestImage: ImageIngest
    private var onChange: (() -> Void)?

    init(
        pasteboard: NSPasteboard = .general,
        ingestText: @escaping TextIngest = ClipboardWatcher.defaultIngestText,
        ingestImage: @escaping ImageIngest = ClipboardWatcher.defaultIngestImage
    ) {
        self.pasteboard = pasteboard
        self.ingestText = ingestText
        self.ingestImage = ingestImage
        self.lastChangeCount = pasteboard.changeCount
    }

    /// Starts polling clipboard changes.
    /// - Parameters:
    ///   - interval: Poll interval in seconds.
    ///   - onChange: Optional callback triggered after a clipboard change is successfully persisted.
    func start(interval: TimeInterval = 0.4, onChange: (() -> Void)? = nil) {
        stop()
        self.onChange = onChange
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.pollForChanges()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        onChange = nil
    }

    func pollForChanges() {
        let current = pasteboard.changeCount
        if current != lastChangeCount {
            lastChangeCount = current
            if captureCurrentClipboard() {
                onChange?()
            }
        }
    }

    private func captureCurrentClipboard() -> Bool {
        if hasFileURLPayload() {
            log("ignore_file_or_folder_reference")
            return false
        }

        if hasTransientOrConcealedMarkers() {
            log("skip_transient_or_concealed")
            return false
        }

        let sourceAppID = ClipboardSourceAttribution.detectSourceAppID(from: pasteboard)

        if let text = readTextPayload() {
            let utf8Count = text.utf8.count
            if utf8Count > Self.maxPayloadBytes {
                log("skip_large_text bytes=\(utf8Count)")
                return false
            }

            let stored = ingestText(text, sourceAppID)
            log(stored ? "capture_text_success" : "capture_text_failed")
            return stored
        }

        if let image = readImagePayload(),
           let tiffData = image.tiffRepresentation,
           let bitmap = NSBitmapImageRep(data: tiffData),
           let pngData = bitmap.representation(using: .png, properties: [:]) {
            if pngData.count > Self.maxPayloadBytes {
                log("skip_large_image bytes=\(pngData.count)")
                return false
            }

            let width = Int(bitmap.pixelsWide)
            let height = Int(bitmap.pixelsHigh)
            let stored = ingestImage(pngData, width, height, "png", sourceAppID)
            log(stored ? "capture_image_success" : "capture_image_failed")
            if stored {
                NotificationCenter.default.post(name: .clipboardImageCaptured, object: nil)
            }
            return stored
        }

        return false
    }

    private func readTextPayload() -> String? {
        if let attributed = pasteboard.readObjects(forClasses: [NSAttributedString.self]),
           let first = attributed.first as? NSAttributedString {
            return first.string
        }

        if let plain = pasteboard.string(forType: .string), !plain.isEmpty {
            return plain
        }

        return nil
    }

    private func readImagePayload() -> NSImage? {
        let images = pasteboard.readObjects(forClasses: [NSImage.self]) as? [NSImage]
        return images?.first
    }

    private func hasFileURLPayload() -> Bool {
        let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL]
        return !(urls?.isEmpty ?? true)
    }

    private func hasTransientOrConcealedMarkers() -> Bool {
        let types = pasteboard.types ?? []
        return types.contains(NSPasteboard.PasteboardType("org.nspasteboard.TransientType"))
            || types.contains(NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType"))
    }

    private func log(_ message: String) {
        print("[watcher] \(message)")
    }

    private static func defaultIngestText(_ text: String, _ sourceAppID: String) -> Bool {
        return text.withCString { textPointer in
            sourceAppID.withCString { sourcePointer in
                pasty_history_ingest_text(textPointer, sourcePointer)
            }
        }
    }

    private static func defaultIngestImage(_ bytes: Data, _ width: Int, _ height: Int, _ formatHint: String, _ sourceAppID: String) -> Bool {
        return bytes.withUnsafeBytes { rawBuffer in
            guard let rawPointer = rawBuffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                return false
            }
            return sourceAppID.withCString { sourcePointer in
                formatHint.withCString { formatPointer in
                    pasty_history_ingest_image(rawPointer, numericCast(bytes.count), numericCast(width), numericCast(height), formatPointer, sourcePointer)
                }
            }
        }
    }
}
