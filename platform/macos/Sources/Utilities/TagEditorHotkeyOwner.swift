import AppKit

final class TagEditorHotkeyOwner: InAppHotkeyOwner {
    let hotkeyOwnerID = "tagEditorSheet"

    private let isTagEditorPresented: () -> Bool
    private let onClose: () -> Void
    private let onSave: () -> Void

    init(
        isTagEditorPresented: @escaping () -> Bool,
        onClose: @escaping () -> Void,
        onSave: @escaping () -> Void
    ) {
        self.isTagEditorPresented = isTagEditorPresented
        self.onClose = onClose
        self.onSave = onSave
    }

    func canHandleInAppHotkey() -> Bool {
        return isTagEditorPresented()
    }

    func handleInAppHotkey(_ event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        switch event.keyCode {
        case 53: // Escape
            onClose()
            return true
        case 36 where flags.contains(.command): // Return
            onSave()
            return true
        case 76 where flags.contains(.command): // Enter (numpad)
            onSave()
            return true
        default:
            return false
        }
    }
}
