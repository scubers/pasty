import Cocoa
import Foundation

/// NSPasteboard monitoring orchestrator
class ClipboardMonitor {
    private var monitorTimer: Timer?
    private var lastChangeCount: Int = 0
    private let pasteboard = NSPasteboard.general
    private let detector: ContentTypeDetector
    private let coordinator: ClipboardCoordinator

    // T077: Debounce logic to prevent rapid successive processing
    private var debounceTimer: Timer?
    private let debounceInterval: TimeInterval = 0.2  // 200ms

    init(detector: ContentTypeDetector = ContentTypeDetector(),
         coordinator: ClipboardCoordinator = ClipboardCoordinator()) {
        self.detector = detector
        self.coordinator = coordinator
    }

    /// Start monitoring clipboard changes
    func startMonitoring() {
        // Initialize change count
        lastChangeCount = pasteboard.changeCount

        // T080: Run monitoring on background queue to avoid blocking main thread
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            // Poll every 500ms
            self.monitorTimer = Timer.scheduledTimer(
                withTimeInterval: 0.5,
                repeats: true
            ) { [weak self] _ in
                self?.checkForChanges()
            }

            // Start the run loop for this thread
            RunLoop.current.run()
        }

        NSLog("[ClipboardMonitor] Started monitoring clipboard changes")
    }

    /// Stop monitoring clipboard changes
    func stopMonitoring() {
        monitorTimer?.invalidate()
        monitorTimer = nil

        // Cancel any pending debounced processing
        debounceTimer?.invalidate()
        debounceTimer = nil

        NSLog("[ClipboardMonitor] Stopped monitoring clipboard changes")
    }

    /// Check for clipboard changes
    private func checkForChanges() {
        let currentChangeCount = pasteboard.changeCount

        if currentChangeCount != lastChangeCount {
            lastChangeCount = currentChangeCount

            // T077: Debounce rapid changes to avoid processing multiple times
            debounceTimer?.invalidate()
            debounceTimer = Timer.scheduledTimer(
                withTimeInterval: debounceInterval,
                repeats: false
            ) { [weak self] _ in
                self?.processClipboardChange()
            }
        }
    }

    /// Process clipboard change with debounce
    private func processClipboardChange() {
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
