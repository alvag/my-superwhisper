import AppKit

final class StatusMenuController: NSObject {
    private weak var coordinator: AppCoordinator?
    private var haikuCleanup: (any HaikuCleanupProtocol)?
    private var vocabularyService: VocabularyService?
    private var microphoneService: MicrophoneDeviceService?
    private var settingsWindowController: SettingsWindowController?
    private var aboutWindowController: AboutWindowController?
    var historyWindowController: HistoryWindowController?

    init(
        coordinator: AppCoordinator,
        haikuCleanup: (any HaikuCleanupProtocol)? = nil,
        vocabularyService: VocabularyService? = nil,
        microphoneService: MicrophoneDeviceService? = nil
    ) {
        self.coordinator = coordinator
        self.haikuCleanup = haikuCleanup
        self.vocabularyService = vocabularyService
        self.microphoneService = microphoneService
        super.init()
    }

    func buildMenu() -> NSMenu {
        let menu = NSMenu()
        // Acerca de MyWhisper at the top
        let aboutItem = NSMenuItem(title: "Acerca de MyWhisper", action: #selector(openAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)
        menu.addItem(.separator())
        // Status item (updated dynamically by observing coordinator.state)
        let statusItem = NSMenuItem(title: "Listo", action: nil, keyEquivalent: "")
        statusItem.isEnabled = false
        menu.addItem(statusItem)
        menu.addItem(.separator())
        // Hotkey display
        let hotkeyItem = NSMenuItem(title: "Atajo: \u{2325}Space", action: nil, keyEquivalent: "")
        hotkeyItem.isEnabled = false
        menu.addItem(hotkeyItem)
        menu.addItem(.separator())
        // Historial
        let historyItem = NSMenuItem(title: "Historial", action: #selector(openHistory), keyEquivalent: "")
        historyItem.target = self
        menu.addItem(historyItem)
        // Settings (now fully implemented)
        let settingsItem = NSMenuItem(title: "Preferencias...", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Salir", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        return menu
    }

    @objc private func openAbout() {
        Task { @MainActor in
            if aboutWindowController == nil {
                aboutWindowController = AboutWindowController()
            }
            aboutWindowController?.show()
        }
    }

    @objc private func openHistory() {
        Task { @MainActor in
            historyWindowController?.show()
        }
    }

    @objc private func openSettings() {
        Task { @MainActor in
            if settingsWindowController == nil, let vocab = vocabularyService, let mic = microphoneService {
                settingsWindowController = SettingsWindowController(
                    vocabularyService: vocab,
                    microphoneService: mic,
                    haikuCleanup: haikuCleanup
                )
            }
            settingsWindowController?.show()
        }
    }
}
