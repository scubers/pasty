// Pasty2 - Copyright (c) 2026. MIT License.

import Cocoa
import PastyCore

final class ClipboardWatcher {
    private static let maxPayloadBytes = 10 * 1024 * 1024

    private var timer: Timer?
    private var lastChangeCount: Int
    private let pasteboard: NSPasteboard

    init(pasteboard: NSPasteboard = .general) {
        self.pasteboard = pasteboard
        self.lastChangeCount = pasteboard.changeCount
    }

    func start(interval: TimeInterval = 0.4, onChange: (() -> Void)? = nil) {
        stop()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            guard let self else {
                return
            }
            let current = self.pasteboard.changeCount
            if current != self.lastChangeCount {
                self.lastChangeCount = current
                self.captureCurrentClipboard()
                onChange?()
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func captureCurrentClipboard() {
        if hasFileURLPayload() {
            log("ignore_file_or_folder_reference")
            return
        }

        if hasTransientOrConcealedMarkers() {
            log("skip_transient_or_concealed")
            return
        }

        let sourceAppID = ClipboardSourceAttribution.detectSourceAppID(from: pasteboard)

        if let text = readTextPayload() {
            let utf8Count = text.utf8.count
            if utf8Count > Self.maxPayloadBytes {
                log("skip_large_text bytes=\(utf8Count)")
                return
            }

            let stored = text.withCString { textPointer in
                sourceAppID.withCString { sourcePointer in
                    pasty_history_ingest_text(textPointer, sourcePointer)
                }
            }
            log(stored ? "capture_text_success" : "capture_text_failed")
            return
        }

        if let image = readImagePayload(),
           let tiffData = image.tiffRepresentation,
           let bitmap = NSBitmapImageRep(data: tiffData),
           let pngData = bitmap.representation(using: .png, properties: [:]) {
            if pngData.count > Self.maxPayloadBytes {
                log("skip_large_image bytes=\(pngData.count)")
                return
            }

            let byteCount = pngData.count
            let width = Int(bitmap.pixelsWide)
            let height = Int(bitmap.pixelsHigh)
            let stored = pngData.withUnsafeBytes { rawBuffer in
                guard let rawPointer = rawBuffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                    return false
                }
                return sourceAppID.withCString { sourcePointer in
                    "png".withCString { formatPointer in
                        pasty_history_ingest_image(rawPointer, numericCast(byteCount), numericCast(width), numericCast(height), formatPointer, sourcePointer)
                    }
                }
            }
            log(stored ? "capture_image_success" : "capture_image_failed")
        }
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
}
