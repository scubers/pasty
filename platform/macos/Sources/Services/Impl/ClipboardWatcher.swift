// Pasty - Copyright (c) 2026. MIT License.

import Cocoa
import PastyCore

import Combine

final class ClipboardWatcher {
    private let coordinator: AppCoordinator

    private var maxPayloadBytes: Int {
        coordinator.settings.clipboard.maxContentSizeBytes
    }

    typealias IngestOutcome = (ok: Bool, inserted: Bool)
    typealias TextIngest = (_ runtime: UnsafeMutableRawPointer?, _ text: String, _ sourceAppID: String) -> IngestOutcome
    typealias ImageIngest = (_ runtime: UnsafeMutableRawPointer?, _ bytes: Data, _ width: Int, _ height: Int, _ formatHint: String, _ sourceAppID: String) -> IngestOutcome

    private var timer: Timer?
    private var lastChangeCount: Int
    private let pasteboard: NSPasteboard
    private let ingestText: TextIngest
    private let ingestImage: ImageIngest
    private var onChange: ((Bool) -> Void)?
    private var cancellables = Set<AnyCancellable>()

    init(
        coordinator: AppCoordinator,
        pasteboard: NSPasteboard = .general,
        ingestText: @escaping TextIngest = ClipboardWatcher.defaultIngestText,
        ingestImage: @escaping ImageIngest = ClipboardWatcher.defaultIngestImage
    ) {
        self.coordinator = coordinator
        self.pasteboard = pasteboard
        self.ingestText = ingestText
        self.ingestImage = ingestImage
        self.lastChangeCount = pasteboard.changeCount
        
        coordinator.$settings
            .map(\.clipboard.pollingIntervalMs)
            .removeDuplicates()
            .sink { [weak self] intervalMs in
                guard let self = self, self.timer != nil else { return }
                self.startTimer(interval: TimeInterval(intervalMs) / 1000.0)
            }
            .store(in: &cancellables)
    }

    /// Starts polling clipboard changes.
    /// - Parameters:
    ///   - onChange: Optional callback triggered after a clipboard change is persisted.
    ///               `inserted=true` indicates a new row was inserted; false means dedupe/update.
    func start(onChange: ((Bool) -> Void)? = nil) {
        stop()
        self.onChange = onChange
        let intervalMs = coordinator.settings.clipboard.pollingIntervalMs
        startTimer(interval: TimeInterval(intervalMs) / 1000.0)
    }
    
    private func startTimer(interval: TimeInterval) {
        timer?.invalidate()
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
            let outcome = captureCurrentClipboard()
            if outcome.ok {
                onChange?(outcome.inserted)
            }
        }
    }

    private func captureCurrentClipboard() -> IngestOutcome {
        if hasFileURLPayload() {
            log("ignore_file_or_folder_reference")
            return (false, false)
        }

        if hasTransientOrConcealedMarkers() {
            log("skip_transient_or_concealed")
            return (false, false)
        }

        let sourceAppID = ClipboardSourceAttribution.detectSourceAppID(from: pasteboard)

        if let text = readTextPayload() {
            let utf8Count = text.utf8.count
            if utf8Count > maxPayloadBytes {
                log("skip_large_text bytes=\(utf8Count)")
                return (false, false)
            }

            let outcome = ingestText(coordinator.coreRuntime, text, sourceAppID)
            log(outcome.ok ? "capture_text_success inserted=\(outcome.inserted)" : "capture_text_failed")
            return outcome
        }

        if let image = readImagePayload(),
           let tiffData = image.tiffRepresentation,
           let bitmap = NSBitmapImageRep(data: tiffData),
           let pngData = bitmap.representation(using: .png, properties: [:]) {
            if pngData.count > maxPayloadBytes {
                log("skip_large_image bytes=\(pngData.count)")
                return (false, false)
            }

            let width = Int(bitmap.pixelsWide)
            let height = Int(bitmap.pixelsHigh)
            let outcome = ingestImage(coordinator.coreRuntime, pngData, width, height, "png", sourceAppID)
            log(outcome.ok ? "capture_image_success inserted=\(outcome.inserted)" : "capture_image_failed")
            if outcome.ok {
                coordinator.dispatch(.clipboardImageCaptured)
            }
            return outcome
        }

        return (false, false)
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
        LoggerService.debug("[watcher] \(message)")
    }

    private static func defaultIngestText(_ runtime: UnsafeMutableRawPointer?, _ text: String, _ sourceAppID: String) -> IngestOutcome {
        guard let runtime else {
            return (false, false)
        }
        var inserted = false
        let ok = text.withCString { textPointer in
            sourceAppID.withCString { sourcePointer in
                pasty_history_ingest_text_with_result(runtime, textPointer, sourcePointer, &inserted)
            }
        }
        return (ok, inserted)
    }

    private static func defaultIngestImage(_ runtime: UnsafeMutableRawPointer?, _ bytes: Data, _ width: Int, _ height: Int, _ formatHint: String, _ sourceAppID: String) -> IngestOutcome {
        guard let runtime else {
            return (false, false)
        }
        var inserted = false
        let ok = bytes.withUnsafeBytes { rawBuffer in
            guard let rawPointer = rawBuffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                return false
            }
            return sourceAppID.withCString { sourcePointer in
                formatHint.withCString { formatPointer in
                    pasty_history_ingest_image_with_result(
                        runtime,
                        rawPointer,
                        numericCast(bytes.count),
                        numericCast(width),
                        numericCast(height),
                        formatPointer,
                        sourcePointer,
                        &inserted
                    )
                }
            }
        }
        return (ok, inserted)
    }
}
