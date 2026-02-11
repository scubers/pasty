import AppKit

/// Protocol for any component that wants to handle application-level hotkeys.
/// Components must conform to this protocol to participate in the hotkey permission system.
@MainActor
protocol InAppHotkeyOwner: AnyObject {
    /// Unique identifier for this owner (e.g., "mainPanel", "deleteConfirmation")
    var hotkeyOwnerID: String { get }

    /// Priority for this owner (optional, default to 0 for LIFO order)
    var hotkeyPriority: Int { get }

    /// Whether this owner can currently handle hotkeys
    /// - Returns: true if the owner is in a state to handle keyboard events
    func canHandleInAppHotkey() -> Bool

    /// Handle a keyboard event
    /// - Parameter event: The keyboard event to handle
    /// - Returns: true if the event was consumed, false otherwise
    func handleInAppHotkey(_ event: NSEvent) -> Bool
}

/// Default priority implementation
extension InAppHotkeyOwner {
    var hotkeyPriority: Int {
        return 0
    }
}

/// Token representing a hotkey permission request.
/// Call `resign()` to give up the permission.
@MainActor
protocol InAppHotkeyPermissionToken: AnyObject {
    func resign()
}

/// Internal token implementation
final class HotkeyPermissionToken: InAppHotkeyPermissionToken {
    private let resignCallback: () -> Void

    init(resignCallback: @escaping () -> Void) {
        self.resignCallback = resignCallback
    }

    func resign() {
        resignCallback()
    }
}
