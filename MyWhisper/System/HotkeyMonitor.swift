import KeyboardShortcuts
import AppKit

extension KeyboardShortcuts.Name {
    static let toggleRecording = Self("toggleRecording",
                                      default: .init(.space, modifiers: [.option]))
}

final class HotkeyMonitor {
    private weak var coordinator: AppCoordinator?

    init(coordinator: AppCoordinator) {
        self.coordinator = coordinator
        KeyboardShortcuts.onKeyDown(for: .toggleRecording) { [weak self] in
            guard let coordinator = self?.coordinator else { return }
            Task { @MainActor in
                await coordinator.handleHotkey()
            }
        }
    }

    func unregister() {
        KeyboardShortcuts.disable(.toggleRecording)
    }
}
