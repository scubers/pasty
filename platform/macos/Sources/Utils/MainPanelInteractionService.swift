import AppKit
import ApplicationServices
import Combine

struct FrontmostAppTracker: Equatable {
    let processIdentifier: pid_t
    let bundleIdentifier: String?
}

protocol MainPanelInteractionService {
    var outsideClickMonitor: AnyPublisher<NSEvent, Never> { get }

    func trackAndRestoreFrontmostApplication() -> FrontmostAppTracker?
    func restoreFrontmostApplication()
    func startOutsideClickMonitoring()
    func stopOutsideClickMonitoring()

    func copyToPasteboard(_ content: String) -> Bool
    func copyToPasteboard(_ image: NSImage) -> Bool
    func sendPasteCommand()
}

final class MainPanelInteractionServiceImpl: MainPanelInteractionService {
    var outsideClickMonitor: AnyPublisher<NSEvent, Never> {
        outsideClickSubject.eraseToAnyPublisher()
    }

    private let outsideClickSubject = PassthroughSubject<NSEvent, Never>()
    private var outsideClickEventMonitor: Any?
    private var previousFrontmostApp: NSRunningApplication?
    private var hasRequestedAccessibilityPrompt = false

    func trackAndRestoreFrontmostApplication() -> FrontmostAppTracker? {
        previousFrontmostApp = NSWorkspace.shared.frontmostApplication
        guard let previousFrontmostApp else {
            return nil
        }

        return FrontmostAppTracker(
            processIdentifier: previousFrontmostApp.processIdentifier,
            bundleIdentifier: previousFrontmostApp.bundleIdentifier
        )
    }

    func restoreFrontmostApplication() {
        guard let previousFrontmostApp else {
            return
        }
        if previousFrontmostApp.bundleIdentifier == Bundle.main.bundleIdentifier {
            return
        }
        previousFrontmostApp.activate()
    }

    func startOutsideClickMonitoring() {
        guard outsideClickEventMonitor == nil else {
            return
        }

        outsideClickEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            self?.outsideClickSubject.send(event)
        }
    }

    func stopOutsideClickMonitoring() {
        guard let outsideClickEventMonitor else {
            return
        }
        NSEvent.removeMonitor(outsideClickEventMonitor)
        self.outsideClickEventMonitor = nil
    }

    func copyToPasteboard(_ content: String) -> Bool {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        return pasteboard.setString(content, forType: .string)
    }

    func copyToPasteboard(_ image: NSImage) -> Bool {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        return pasteboard.writeObjects([image])
    }

    func sendPasteCommand() {
        guard let previousFrontmostApp else {
            return
        }
        if previousFrontmostApp.bundleIdentifier == Bundle.main.bundleIdentifier {
            return
        }
        // Cmd+V simulation requires Accessibility trust; prompt on first failure.
        guard ensureAccessibilityPermissionForPaste() else {
            print("[main-panel] accessibility permission missing, paste command not sent")
            return
        }

        guard let source = CGEventSource(stateID: .combinedSessionState) else {
            print("[main-panel] failed to create CGEventSource for paste command")
            return
        }

        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false) else {
            print("[main-panel] failed to create Cmd+V key events")
            return
        }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand

        keyDown.post(tap: .cgSessionEventTap)
        keyUp.post(tap: .cgSessionEventTap)
    }

    private func ensureAccessibilityPermissionForPaste() -> Bool {
        if AXIsProcessTrusted() {
            hasRequestedAccessibilityPrompt = false
            return true
        }

        if !hasRequestedAccessibilityPrompt {
            // Trigger system Settings prompt once per denied session.
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            _ = AXIsProcessTrustedWithOptions(options)
            hasRequestedAccessibilityPrompt = true
        }

        return false
    }
}
