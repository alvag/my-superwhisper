import AppKit

final class StatusMenuController {
    private weak var coordinator: AppCoordinator?

    init(coordinator: AppCoordinator) {
        self.coordinator = coordinator
    }

    func buildMenu() -> NSMenu {
        let menu = NSMenu()
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
        // Settings (stub — Phase 4 implements)
        menu.addItem(NSMenuItem(title: "Preferencias...", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Salir", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        return menu
    }

    @objc private func openSettings() {
        // Phase 4 — stub
    }
}
