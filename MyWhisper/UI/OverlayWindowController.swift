import AppKit
import SwiftUI

final class OverlayWindowController: OverlayWindowControllerProtocol {
    private var panel: NSPanel?
    private var currentMode: OverlayMode = .recording(audioLevel: 0)

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

        currentMode = .recording(audioLevel: 0)
        panel.contentView = NSHostingView(rootView: OverlayView(mode: currentMode))

        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let x = screenFrame.midX - 50
            let y = screenFrame.midY + 60
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        } else {
            panel.center()
        }

        // CRITICAL: orderFront, NOT makeKeyAndOrderFront — must not steal focus
        // Pitfall 5: makeKeyAndOrderFront steals focus from target app, breaking paste
        panel.orderFront(nil)
        self.panel = panel
    }

    func hide() {
        panel?.orderOut(nil)
        panel = nil
    }

    func showProcessing() {
        currentMode = .processing
        updateHostingView()
    }

    func updateAudioLevel(_ level: Float) {
        currentMode = .recording(audioLevel: level)
        updateHostingView()
    }

    private func updateHostingView() {
        guard let panel = panel else { return }
        panel.contentView = NSHostingView(rootView: OverlayView(mode: currentMode))
    }
}
