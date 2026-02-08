import Cocoa
import SwiftUI
import SnapKit

final class MainPanelWindowController: NSWindowController {
    private let hostingController: NSHostingController<MainPanelView>
    private let viewModel: MainPanelViewModel

    init(viewModel: MainPanelViewModel) {
        self.viewModel = viewModel
        let view = MainPanelView(viewModel: viewModel)
        self.hostingController = NSHostingController(rootView: view)

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.nonactivatingPanel, .borderless, .resizable],
            backing: .buffered,
            defer: false
        )

        panel.isFloatingPanel = true
        panel.level = .floating
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        super.init(window: panel)
        setupLayout()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        guard let panel = window, let contentView = panel.contentView else { return }

        contentView.addSubview(hostingController.view)
        hostingController.view.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    func show(at point: NSPoint) {
        guard let panel = window else { return }

        let screen = NSScreen.screens.first { screen in
            screen.frame.contains(point)
        }

        if let screen = screen {
            let screenCenter = NSPoint(
                x: screen.frame.midX - panel.frame.width / 2,
                y: screen.frame.midY - panel.frame.height / 2 + 100 // Visual center often higher
            )
            // Ensure within bounds
            var targetOrigin = screenCenter
            if targetOrigin.x < screen.frame.minX { targetOrigin.x = screen.frame.minX }
            if targetOrigin.x + panel.frame.width > screen.frame.maxX { targetOrigin.x = screen.frame.maxX - panel.frame.width }
            if targetOrigin.y < screen.frame.minY { targetOrigin.y = screen.frame.minY }
            if targetOrigin.y + panel.frame.height > screen.frame.maxY { targetOrigin.y = screen.frame.maxY - panel.frame.height }
            
            panel.setFrameOrigin(targetOrigin)
        } else {
            panel.setFrameOrigin(point)
        }

        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func hide() {
        window?.orderOut(nil)
    }
}
