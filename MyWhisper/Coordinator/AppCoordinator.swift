import AppKit
import Observation

@MainActor
@Observable
final class AppCoordinator {
    internal(set) var state: AppState = .idle

    // Injected after init — weak to avoid retain cycles
    weak var menubarController: MenubarController?
    var overlayController: (any OverlayWindowControllerProtocol)?
    var audioRecorder: (any AudioRecorderProtocol)?
    var textInjector: (any TextInjectorProtocol)?
    var escapeMonitor: EscapeMonitor?

    func handleHotkey() async {
        switch state {
        case .idle:
            transitionTo(.recording)
            escapeMonitor?.startMonitoring()
            overlayController?.show()
            audioRecorder?.startStub()
        case .recording:
            escapeMonitor?.stopMonitoring()
            overlayController?.hide()
            audioRecorder?.stopStub()
            transitionTo(.processing)
            // Phase 1: inject placeholder text; Phase 2+ replaces this
            await textInjector?.inject("Texto de prueba")
            transitionTo(.idle)
        case .processing:
            break // Ignored per spec
        case .error:
            transitionTo(.idle)
        }
    }

    func handleEscape() {
        guard state == .recording else { return }
        escapeMonitor?.stopMonitoring()
        overlayController?.hide()
        audioRecorder?.cancelStub()
        NSSound.beep()
        transitionTo(.idle)
    }

    private func transitionTo(_ newState: AppState) {
        state = newState
        menubarController?.update(state: newState)
    }
}
