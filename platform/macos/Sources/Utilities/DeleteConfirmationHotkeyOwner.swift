import AppKit

final class DeleteConfirmationHotkeyOwner: InAppHotkeyOwner {
    let hotkeyOwnerID = "deleteConfirmation"

    private weak var alert: NSAlert?
    private let onConfirm: () -> Void
    private let onCancel: () -> Void

    init(alert: NSAlert, onConfirm: @escaping () -> Void, onCancel: @escaping () -> Void) {
        self.alert = alert
        self.onConfirm = onConfirm
        self.onCancel = onCancel
    }

    func canHandleInAppHotkey() -> Bool {
        guard let alert else {
            return false
        }
        return alert.window.isVisible
    }

    func handleInAppHotkey(_ event: NSEvent) -> Bool {
        switch event.keyCode {
        case 53:
            onCancel()
            alert?.window.orderOut(nil)
            return true
        case 36:
            onConfirm()
            alert?.window.orderOut(nil)
            return true
        default:
            return false
        }
    }
}
