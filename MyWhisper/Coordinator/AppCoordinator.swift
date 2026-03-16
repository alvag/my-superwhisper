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
    weak var permissionsManager: (any PermissionsManaging)?
    var sttEngine: (any STTEngineProtocol)?

    private var audioLevelTimer: Timer?

    func handleHotkey() async {
        switch state {
        case .idle:
            // On-the-fly microphone permission (MAC-02)
            if let pm = permissionsManager {
                let granted = await pm.requestMicrophone()
                if !granted {
                    transitionTo(.error("microphone"))
                    return
                }
            }
            // Start recording
            do {
                try audioRecorder?.start()
            } catch {
                transitionTo(.error("microphone"))
                return
            }
            transitionTo(.recording)
            escapeMonitor?.startMonitoring()
            overlayController?.show()
            startAudioLevelPolling()

        case .recording:
            escapeMonitor?.stopMonitoring()
            stopAudioLevelPolling()

            // Get accumulated audio buffer
            let buffer = audioRecorder?.stop() ?? []

            // VAD gate -- silence check (AUD-03)
            guard VAD.hasSpeech(in: buffer) else {
                overlayController?.hide()
                NotificationHelper.show(title: "No se detecto voz")
                transitionTo(.idle)
                return
            }

            // Switch overlay from waveform to spinner
            overlayController?.showProcessing()
            transitionTo(.processing)

            // Transcribe via WhisperKit (STT-01)
            do {
                guard let text = try await sttEngine?.transcribe(buffer) else {
                    throw STTError.notLoaded
                }
                overlayController?.hide()
                await textInjector?.inject(text)
                transitionTo(.idle)
            } catch {
                overlayController?.hide()
                NotificationHelper.show(
                    title: "Error de transcripcion",
                    body: error.localizedDescription
                )
                transitionTo(.idle)
            }

        case .processing:
            break // Ignored per spec

        case .error:
            transitionTo(.idle)
        }
    }

    func handleEscape() {
        guard state == .recording else { return }
        escapeMonitor?.stopMonitoring()
        stopAudioLevelPolling()
        overlayController?.hide()
        audioRecorder?.cancel()
        NSSound.beep()
        transitionTo(.idle)
    }

    private func transitionTo(_ newState: AppState) {
        state = newState
        menubarController?.update(state: newState)
    }

    // MARK: - Audio Level Polling

    private func startAudioLevelPolling() {
        // Poll audioLevel at ~30fps for overlay visualization
        audioLevelTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, let recorder = self.audioRecorder else { return }
                self.overlayController?.updateAudioLevel(recorder.audioLevel)
            }
        }
    }

    private func stopAudioLevelPolling() {
        audioLevelTimer?.invalidate()
        audioLevelTimer = nil
    }
}
