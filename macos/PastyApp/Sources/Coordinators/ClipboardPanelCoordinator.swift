import Cocoa
import Combine
import KeyboardShortcuts
import ApplicationServices

/// Coordinator for clipboard panel lifecycle management
/// Manages the panel window and view model binding
@MainActor
class ClipboardPanelCoordinator: NSObject {
    // MARK: - Properties

    private let window: ClipboardPanelWindow
    private let mainPanelViewModel: MainPanelViewModel
    private let previewPanelViewModel: PreviewPanelViewModel
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init(
        mainPanelViewModel: MainPanelViewModel? = nil,
        previewPanelViewModel: PreviewPanelViewModel? = nil
    ) {
        self.mainPanelViewModel = mainPanelViewModel ?? MainPanelViewModel()
        self.previewPanelViewModel = previewPanelViewModel ?? PreviewPanelViewModel()
        self.window = ClipboardPanelWindow(
            mainPanelViewModel: self.mainPanelViewModel,
            previewPanelViewModel: self.previewPanelViewModel
        )

        super.init()

        setupBindings()
    }

    // MARK: - Public Methods

    /// Show the clipboard panel
    func showPanel() {
        window.showPanel()
    }

    /// Hide the clipboard panel
    func hidePanel() {
        window.hidePanel()
    }

    /// Toggle panel visibility
    func togglePanel() {
        NSLog("🔔 togglePanel called - window.isPanelShown = \(window.isPanelShown)")

        // Cmd+Shift+V only shows the panel, never hides it
        // Use isPanelShown to track panel state since isVisible may not update correctly with hidesOnDeactivate
        if window.isPanelShown {
            NSLog("🔔 Panel already visible, ensuring it's on current screen")
            window.repositionToMouseScreen()
        } else {
            NSLog("🔔 Panel not visible, showing it")
            showPanel()
        }
    }

    /// Get the window reference
    var panelWindow: NSPanel {
        return window
    }

    // MARK: - Setup

    private func setupBindings() {
        // Additional bindings if needed
        Logger.info("Clipboard panel coordinator initialized")
    }
}

// MARK: - Global Shortcut Handler

extension ClipboardPanelCoordinator {
    /// Setup global keyboard shortcut for toggling panel
    func setupGlobalShortcut() {
        // Check accessibility permissions first
        let hasPermission = hasAccessibilityPermissions()
        Logger.info("Accessibility permission: \(hasPermission ? "GRANTED" : "DENIED")")

        if !hasPermission {
            showAccessibilityPermissionAlert()
        }

        // Add observer for shortcut trigger
        KeyboardShortcuts.onKeyUp(for: .togglePanel) { [weak self] in
            Logger.info("Shortcut triggered: ⌘+Shift+V")
            self?.togglePanel()
        }

        // Log the shortcut name for debugging
        let shortcut = KeyboardShortcuts.Shortcut(name: .togglePanel)
        Logger.info("Global keyboard shortcut registered: \(String(describing: shortcut))")
    }

    /// Check if the app has accessibility permissions
    private func hasAccessibilityPermissions() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false]
        let accessEnabled = AXIsProcessTrustedWithOptions(options as CFDictionary)

        if !accessEnabled {
            Logger.warning("Accessibility permissions NOT granted - global shortcuts may not work")
        } else {
            Logger.info("Accessibility permissions granted")
        }

        return accessEnabled
    }

    /// Show alert to guide user to grant accessibility permissions
    private func showAccessibilityPermissionAlert() {
        let alert = NSAlert()
        alert.messageText = "Accessibility Permission Required"
        alert.informativeText = """
        Pasty needs Accessibility permission to use global keyboard shortcuts.

        Please grant permission:
        1. Open System Settings > Privacy & Security > Accessibility
        2. Find PastyApp in the list and enable it

        Without this permission, the ⌘+Shift+V shortcut will not work when the app is in the background.
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Later")

        let response = alert.runModal()

        if response == .alertFirstButtonReturn {
            // Open System Settings to Accessibility pane
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                NSWorkspace.shared.open(url)
            }
        }
    }
}

// MARK: - KeyboardShortcuts Extension

extension KeyboardShortcuts.Name {
    /// Shortcut name for toggling the clipboard panel
    static let togglePanel = Self("togglePanel", default: .init(.v, modifiers: [.command, .shift]))
}
