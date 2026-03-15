import AppKit

final class EscapeMonitor {
    private var monitor: Any?
    private weak var coordinator: AppCoordinator?

    init(coordinator: AppCoordinator) {
        self.coordinator = coordinator
    }

    func startMonitoring() {
        guard monitor == nil else { return }
        monitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { // kVK_Escape
                Task { @MainActor [weak self] in
                    self?.coordinator?.handleEscape()
                }
            }
        }
    }

    func stopMonitoring() {
        if let m = monitor { NSEvent.removeMonitor(m) }
        monitor = nil
    }
}
