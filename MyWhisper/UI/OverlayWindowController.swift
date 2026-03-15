import AppKit
import SwiftUI

final class OverlayWindowController: OverlayWindowControllerProtocol {
    private var panel: NSPanel?

    func show() {
        guard panel == nil else { return } // Already showing

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 100, height: 48),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.level = .floating                          // Floats above all normal windows
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentView = NSHostingView(rootView: OverlayView())

        // Position: center of main screen, slightly above center (y + 60)
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
}
