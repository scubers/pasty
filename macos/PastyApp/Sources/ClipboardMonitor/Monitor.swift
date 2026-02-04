import Cocoa
import Foundation

/// System-wide clipboard change detection via NSPasteboard polling
class Monitor {
    private var timer: Timer?
    private var lastChangeCount: Int = 0
    private let pasteboard = NSPasteboard.general

    /// Start monitoring with callback
    func startMonitoring(callback: @escaping () -> Void) {
        lastChangeCount = pasteboard.changeCount

        timer = Timer.scheduledTimer(
            withTimeInterval: 0.5,
            repeats: true
        ) { [weak self] _ in
            self?.checkForChanges(callback: callback)
        }
    }

    /// Stop monitoring
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    /// Check for changes via changeCount comparison
    private func checkForChanges(callback: @escaping () -> Void) {
        let currentChangeCount = pasteboard.changeCount

        if currentChangeCount != lastChangeCount {
            lastChangeCount = currentChangeCount
            callback()
        }
    }
}
