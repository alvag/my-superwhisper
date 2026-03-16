import AppKit
import CoreGraphics

final class TextInjector: TextInjectorProtocol {
    private weak var permissionsManager: PermissionsManager?

    init(permissionsManager: PermissionsManager? = nil) {
        self.permissionsManager = permissionsManager
    }

    func inject(_ text: String) async {
        // Step 1: Request Accessibility on-the-fly (prompts system dialog on first use)
        if let pm = permissionsManager {
            _ = pm.requestAccessibility()
        }

        // Step 2: Write to clipboard (overwrites previous content — per spec, no restore)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        // Step 3: Wait 150ms for clipboard write to propagate to target app
        try? await Task.sleep(for: .milliseconds(150))

        // Step 4: Attempt paste via CGEventPost (requires Accessibility to be granted)
        guard AXIsProcessTrusted() else {
            // Accessibility not yet granted — text is in clipboard, notify user
            await showPasteFailureNotification()
            return
        }

        // Step 5: Simulate Cmd+V
        let source = CGEventSource(stateID: .hidSystemState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true)
        let keyUp   = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
        keyDown?.flags = .maskCommand
        keyUp?.flags   = .maskCommand
        keyDown?.post(tap: .cgSessionEventTap)
        keyUp?.post(tap: .cgSessionEventTap)
    }

    @MainActor
    private func showPasteFailureNotification() async {
        // Fallback: in-app floating notification (no UNUserNotificationCenter permission needed)
        // Phase 1: use simple NSAlert as placeholder; Phase 4 can upgrade to toast
        let alert = NSAlert()
        alert.messageText = "Texto copiado"
        alert.informativeText = "Pegá con Cmd+V"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
