import Cocoa
import SwiftUI
import SnapKit
import Combine

private final class MainPanelWindow: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    var onWindowDidMove: ((NSPoint) -> Void)?
    var onMouseInteraction: (() -> Void)?

    override func sendEvent(_ event: NSEvent) {
        super.sendEvent(event)
        switch event.type {
        case .leftMouseUp, .rightMouseUp, .otherMouseUp:
            onMouseInteraction?()
        default:
            break
        }
    }
}

final class MainPanelWindowController: NSWindowController, NSWindowDelegate, InAppHotkeyOwner {
    private let hostingController: NSHostingController<AnyView>
    private let viewModel: MainPanelViewModel
    private let coordinator: AppCoordinator
    private var lastShownScreenID: String?
    private var lastFrameOrigin: NSPoint?
    private var hotkeyPermissionToken: InAppHotkeyPermissionToken?
    private var cancellables = Set<AnyCancellable>()

    init(viewModel: MainPanelViewModel, coordinator: AppCoordinator) {
        self.viewModel = viewModel
        self.coordinator = coordinator
        let view = AnyView(
            MainPanelView()
                .environmentObject(viewModel)
                .environmentObject(coordinator)
        )
        self.hostingController = NSHostingController(rootView: view)

        let settings = coordinator.settings.appearance
        let panel = MainPanelWindow(
            contentRect: NSRect(x: 0, y: 0, width: settings.panelWidth, height: settings.panelHeight),
            styleMask: [.borderless, .fullSizeContentView, .resizable],
            backing: .buffered,
            defer: false
        )

        panel.isFloatingPanel = true
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.level = .floating
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        super.init(window: panel)
        panel.delegate = self
        panel.onMouseInteraction = { [weak self] in
            self?.viewModel.send(.panelInteracted)
        }
        setupLayout()
        
        coordinator.$settings
            .map(\.appearance)
            .removeDuplicates()
            .sink { [weak self] appearance in
                self?.updatePanelSize(width: appearance.panelWidth, height: appearance.panelHeight)
            }
            .store(in: &cancellables)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        guard let panel = window, let contentView = panel.contentView else { return }
        
        contentView.wantsLayer = true
        contentView.layer?.cornerRadius = 16
        contentView.layer?.masksToBounds = true
        
        let view = NSView()
        for subview in contentView.subviews {
            subview.removeFromSuperview()
            view.addSubview(subview)
            
            panel.contentView = view
        }

        contentView.addSubview(hostingController.view)
        hostingController.view.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    private func updatePanelSize(width: Double, height: Double) {
        guard let panel = window else { return }
        var frame = panel.frame
        if frame.size.width != width || frame.size.height != height {
            let oldHeight = frame.size.height
            frame.size = NSSize(width: width, height: height)
            frame.origin.y += (oldHeight - height) // Keep top fixed
            panel.setFrame(frame, display: true, animate: true)
        }
    }

    func show(at point: NSPoint) {
        guard let panel = window else { return }

        let screen = NSScreen.screens.first(where: { $0.frame.contains(point) }) ?? NSScreen.main
        let screenID = screenIdentifier(for: screen)

        let preferredOrigin: NSPoint
        if screenID == lastShownScreenID, let lastFrameOrigin {
            preferredOrigin = lastFrameOrigin
        } else {
            preferredOrigin = calculateDefaultPosition(screen: screen)
        }

        let clampedOrigin = clampOrigin(preferredOrigin, in: screen, panelSize: panel.frame.size)
        panel.setFrameOrigin(clampedOrigin)

        lastShownScreenID = screenID
        lastFrameOrigin = clampedOrigin

        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        hotkeyPermissionToken = InAppHotkeyPermissionManager.shared.request(owner: self)
    }

    func hide() {
        window?.orderOut(nil)
        hotkeyPermissionToken?.resign()
        hotkeyPermissionToken = nil
    }

    func windowDidMove(_ notification: Notification) {
        guard let panel = window else {
            return
        }
        let screen = panel.screen ?? NSScreen.screens.first(where: { $0.frame.contains(panel.frame.origin) })
        let clampedOrigin = clampOrigin(panel.frame.origin, in: screen, panelSize: panel.frame.size)
        if panel.frame.origin != clampedOrigin {
            panel.setFrameOrigin(clampedOrigin)
        }
        lastShownScreenID = screenIdentifier(for: screen)
        lastFrameOrigin = clampedOrigin
        (panel as? MainPanelWindow)?.onWindowDidMove?(clampedOrigin)
    }

    func canHandleInAppHotkey() -> Bool {
        guard let panel = window,
              panel.isKeyWindow,
              NSApp.keyWindow === panel,
              panel.attachedSheet == nil,
              viewModel.state.pendingDeleteItem == nil else {
            return false
        }

        return panel.isVisible
    }

    func handleInAppHotkey(_ event: NSEvent) -> Bool {
        let isCommandPressed = event.modifierFlags.contains(.command)

        switch (event.keyCode, isCommandPressed) {
        case (53, _): // esc
            viewModel.send(.togglePanel)
            return true
        case (126, _): // up
            viewModel.send(.moveSelectionUp)
            return true
        case (125, _): // down
            viewModel.send(.moveSelectionDown)
            return true
        case (36, true): // cmd+enter
            viewModel.send(.copySelected)
            return true
        case (36, false): // enter
            viewModel.send(.pasteSelectedAndClose)
            return true
        case (2, true): // cmd+d
            viewModel.send(.prepareDeleteSelected)
            return true
        default:
            return false
        }
    }

    private func calculateDefaultPosition(screen: NSScreen?) -> NSPoint {
        guard let screen else {
            return NSPoint(x: 120, y: 120)
        }
        let visibleFrame = screen.visibleFrame
        return NSPoint(
            x: visibleFrame.midX - 400,
            y: visibleFrame.midY - 300 + 100
        )
    }

    private func clampOrigin(_ origin: NSPoint, in screen: NSScreen?, panelSize: NSSize) -> NSPoint {
        guard let screen else {
            return origin
        }
        let bounds = screen.visibleFrame
        var clamped = origin
        clamped.x = min(max(clamped.x, bounds.minX), bounds.maxX - panelSize.width)
        clamped.y = min(max(clamped.y, bounds.minY), bounds.maxY - panelSize.height)
        return clamped
    }

    private func screenIdentifier(for screen: NSScreen?) -> String? {
        guard let screen,
              let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
            return nil
        }
        return number.stringValue
    }

    var hotkeyOwnerID: String {
        "mainPanel"
    }
}
