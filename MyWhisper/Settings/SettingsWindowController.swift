import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private let viewModel: SettingsViewModel
    private var apiKeyWindowController: APIKeyWindowController?

    init(vocabularyService: VocabularyService,
         microphoneService: MicrophoneDeviceService,
         haikuCleanup: (any HaikuCleanupProtocol)?) {
        self.viewModel = SettingsViewModel(
            vocabularyService: vocabularyService,
            microphoneService: microphoneService,
            haikuCleanup: haikuCleanup
        )
        self.apiKeyWindowController = APIKeyWindowController(haikuCleanup: haikuCleanup)
        super.init()
        self.viewModel.openAPIKey = { [weak self] in
            self?.apiKeyWindowController?.show()
        }
    }

    func show() {
        if let existing = window {
            NSApp.setActivationPolicy(.regular)
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let hostingController = NSHostingController(rootView: SettingsView(viewModel: viewModel))
        let window = NSWindow(contentViewController: hostingController)
        window.title = "MyWhisper — Preferencias"
        window.isReleasedWhenClosed = false
        window.styleMask = [.titled, .closable]
        window.delegate = self
        window.center()

        NSApp.setActivationPolicy(.regular)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        self.window = window
    }

    // MARK: - NSWindowDelegate

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        sender.orderOut(nil)
        NSApp.setActivationPolicy(.accessory)
        NSApp.hide(nil)
        return false
    }
}
