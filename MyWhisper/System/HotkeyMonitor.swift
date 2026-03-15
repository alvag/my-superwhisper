import HotKey
import AppKit

final class HotkeyMonitor {
    private var hotKey: HotKey?
    private weak var coordinator: AppCoordinator?

    init(coordinator: AppCoordinator) {
        self.coordinator = coordinator
        hotKey = HotKey(key: .space, modifiers: [.option])
        hotKey?.keyDownHandler = { [weak self] in
            guard let coordinator = self?.coordinator else { return }
            Task { @MainActor in
                await coordinator.handleHotkey()
            }
        }
    }

    func unregister() {
        hotKey = nil
    }
}
