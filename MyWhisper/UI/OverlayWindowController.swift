import AppKit
import SwiftUI

@MainActor
final class OverlayWindowController: OverlayWindowControllerProtocol {
    private var panel: NSPanel?
    private let viewModel = OverlayViewModel()

    func show() {
        guard panel == nil else { return }

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 100, height: 48),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        viewModel.mode = .recording(audioLevel: 0)
        panel.contentView = NSHostingView(rootView: OverlayView(viewModel: viewModel))

        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let x = screenFrame.midX - 50
            let y = screenFrame.midY + 60
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        } else {
            panel.center()
        }

        // CRITICAL: orderFront, NOT makeKeyAndOrderFront — must not steal focus
        panel.orderFront(nil)
        self.panel = panel
    }

    func hide() {
        panel?.orderOut(nil)
        panel = nil
    }

    func showProcessing() {
        viewModel.mode = .processing
    }

    func updateAudioLevel(_ level: Float) {
        viewModel.mode = .recording(audioLevel: level)
    }
}
