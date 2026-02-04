import Cocoa
import Foundation

/// NSPasteboard monitoring orchestrator
class ClipboardMonitor {
    private var monitorTimer: Timer?
    private var lastChangeCount: Int = 0
    private let pasteboard = NSPasteboard.general
    private let detector: ContentTypeDetector
    private let coordinator: ClipboardCoordinator

    init(detector: ContentTypeDetector = ContentTypeDetector(),
         coordinator: ClipboardCoordinator = ClipboardCoordinator()) {
        self.detector = detector
        self.coordinator = coordinator
    }

    /// Start monitoring clipboard changes
    func startMonitoring() {
        // Initialize change count
        lastChangeCount = pasteboard.changeCount

        // Poll every 500ms
        monitorTimer = Timer.scheduledTimer(
            withTimeInterval: 0.5,
            repeats: true
        ) { [weak self] _ in
            self?.checkForChanges()
        }

        NSLog("[ClipboardMonitor] Started monitoring clipboard changes")
    }

    /// Stop monitoring clipboard changes
    func stopMonitoring() {
        monitorTimer?.invalidate()
        monitorTimer = nil
        NSLog("[ClipboardMonitor] Stopped monitoring clipboard changes")
    }

    /// Check for clipboard changes
    private func checkForChanges() {
        let currentChangeCount = pasteboard.changeCount

        if currentChangeCount != lastChangeCount {
            lastChangeCount = currentChangeCount
            processClipboardChange()
        }
    }

    /// Process clipboard change with debounce
    private func processClipboardChange() {
        // Detect content type
        let detectedType = detector.detectContentType(from: pasteboard)

        switch detectedType {
        case .text:
            handleTextContent()
        case .image:
            handleImageContent()
        case .fileReference:
            handleFileReference()
        case .unsupported:
            NSLog("[ClipboardMonitor] Unsupported content type ignored")
        }
    }

    /// Handle text content
    private func handleTextContent() {
        guard let text = pasteboard.string(forType: .string) else {
            return
        }

        let source = SourceApplication.current()
        coordinator.storeTextContent(text, source: source)
    }

    /// Handle image content
    private func handleImageContent() {
        // Try PNG first, then TIFF
        guard let imageData = pasteboard.data(forType: .png) ?? pasteboard.data(forType: .tiff) else {
            return
        }

        let source = SourceApplication.current()

        // Determine format
        let format: String
        if pasteboard.data(forType: .png) != nil {
            format = "png"
        } else {
            format = "tiff"
        }

        coordinator.storeImageContent(imageData, format: format, source: source)
    }

    /// Handle file/folder reference (log only)
    private func handleFileReference() {
        if let fileURLs = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] {
            for url in fileURLs {
                NSLog("[ClipboardMonitor] File reference detected: \(url.path)")
            }
        }
    }
}
