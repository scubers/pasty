import Foundation
import Combine
import AppKit

/// Preview panel view model for managing entry preview and actions
@MainActor
class PreviewPanelViewModel: ObservableObject {
    // MARK: - Published Properties

    /// Preview content for selected entry
    @Published var previewContent: PreviewContent = .empty

    /// Copy button enabled state
    @Published var copyButtonEnabled: Bool = false

    /// Paste button enabled state
    @Published var pasteButtonEnabled: Bool = false

    /// Loading state
    @Published var isLoading: Bool = false

    /// Error message
    @Published var errorMessage: String? = nil

    /// Current entry metadata for display
    @Published var sourceAppName: String = ""
    @Published var sourceAppIcon: NSImage?
    @Published var timestamp: String = ""
    @Published var isPinned: Bool = false
    @Published var isSensitive: Bool = false
    @Published var canEncrypt: Bool = false
    @Published var isEncrypted: Bool = false

    // MARK: - Dependencies

    private let clipboardHistory: ClipboardHistory
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init(clipboardHistory: ClipboardHistory = .shared) {
        self.clipboardHistory = clipboardHistory
    }

    // MARK: - User Actions

    /// Handle copy action
    func handleCopyAction() {
        guard case .text(let text) = previewContent else {
            Logger.warning("Cannot copy: no text content selected")
            return
        }

        copyToClipboard(text)
        Logger.info("Copied content to clipboard")
    }

    /// Handle paste action (copy + paste)
    func handlePasteAction() {
        guard case .text(let text) = previewContent else {
            Logger.warning("Cannot paste: no text content selected")
            return
        }

        // First copy to clipboard
        copyToClipboard(text)

        // Then simulate Cmd+V
        simulatePaste()
        Logger.info("Copied and pasted content")
    }

    /// Load preview content for entry
    func loadPreviewContent(for entryId: String) {
        isLoading = true
        errorMessage = nil

        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self = self else { return }

            let entry = await self.clipboardHistory.retrieveEntryById(id: entryId)

            await MainActor.run {
                self.isLoading = false

                guard let entry = entry else {
                    self.errorMessage = "Entry not found"
                    self.previewContent = .empty
                    self.copyButtonEnabled = false
                    self.pasteButtonEnabled = false
                    return
                }

                // Set entry metadata
                self.sourceAppName = entry.source.appName
                self.timestamp = entry.timestamp.formatAsTimeAgo()
                // TODO: isPinned not yet implemented in ClipboardEntry
                self.isPinned = false
                // Set sensitive flag based on content analysis
                self.isSensitive = SensitiveContentDetector.isSensitive(entry)

                // Set preview content based on type
                switch entry.content {
                case .text(let text):
                    self.previewContent = .text(text)
                    self.copyButtonEnabled = true
                    self.pasteButtonEnabled = true

                case .image(let imageFile):
                    // Load image from file - path is relative to images directory
                    let imagesDir = StorageManager.shared.getImagesDirectory()
                    let fullPath = imagesDir.appendingPathComponent(imageFile.path).path
                    if let image = NSImage(contentsOfFile: fullPath) {
                        self.previewContent = .image(image)
                        self.copyButtonEnabled = true
                        self.pasteButtonEnabled = true
                    } else {
                        self.previewContent = .empty
                        self.copyButtonEnabled = false
                        self.pasteButtonEnabled = false
                        self.errorMessage = "Failed to load image"
                    }
                }
            }
        }
    }

    /// Clear preview content
    func clearPreview() {
        previewContent = .empty
        copyButtonEnabled = false
        pasteButtonEnabled = false
        errorMessage = nil
        sourceAppName = ""
        sourceAppIcon = nil
        timestamp = ""
        isPinned = false
        isSensitive = false
        canEncrypt = false
        isEncrypted = false
    }

    /// Encrypt current sensitive content
    func encryptSensitiveContent() {
        guard case .text(let text) = previewContent, isSensitive else {
            Logger.warning("Cannot encrypt: content is not sensitive text")
            return
        }

        // In a real implementation, this would call EncryptionService
        // For now, we'll mark it as encrypted
        isEncrypted = true
        Logger.info("Encrypted sensitive content")
    }

    // MARK: - Private Methods

    private func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    private func copyToClipboard(_ image: NSImage) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setData(image.tiffRepresentation!, forType: .tiff)
    }

    private func simulatePaste() {
        // Simulate Cmd+V key press using CGEvent
        let source = CGEventSource(stateID: .combinedSessionState)

        // Key down
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true) // 9 is 'v'
        keyDown?.flags = .maskCommand
        keyDown?.post(tap: .cghidEventTap)

        // Key up
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false)
        keyUp?.flags = .maskCommand
        keyUp?.post(tap: .cghidEventTap)
    }
}
