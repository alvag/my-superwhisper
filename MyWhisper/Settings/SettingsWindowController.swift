import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private let viewModel: SettingsViewModel
    private var apiKeyWindowController: APIKeyWindowController?

    init(vocabularyService: VocabularyService,
         microphoneService: MicrophoneDeviceService,
         permissionsManager: PermissionsManager,
         coordinator: AppCoordinator?,
         haikuCleanup: (any HaikuCleanupProtocol)?,
         sttEngine: (any STTEngineProtocol)?) {
        self.viewModel = SettingsViewModel(
            vocabularyService: vocabularyService,
            microphoneService: microphoneService,
            permissionsManager: permissionsManager,
            coordinator: coordinator,
            haikuCleanup: haikuCleanup,
            sttEngine: sttEngine
        )
        self.apiKeyWindowController = APIKeyWindowController(haikuCleanup: haikuCleanup)
        super.init()
        self.viewModel.openAPIKey = { [weak self] in
            self?.apiKeyWindowController?.show {
                self?.viewModel.refreshStatuses()
            }
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
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 820, height: 720),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.contentViewController = hostingController
        window.title = "MyWhisper — Preferencias"
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 760, height: 640)
        window.delegate = self
        window.center()

        NSApp.setActivationPolicy(.regular)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        self.window = window
    }

    // MARK: - NSWindowDelegate

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        viewModel.stopRuntimeRefresh()
        sender.orderOut(nil)
        NSApp.setActivationPolicy(.accessory)
        NSApp.hide(nil)
        return false
    }
}
