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
    var haikuCleanup: (any HaikuCleanupProtocol)?
    var apiKeyWindowController: APIKeyWindowController?
    var vocabularyService: VocabularyService?
    var historyService: TranscriptionHistoryService?
    var mediaPlayback: (any MediaPlaybackServiceProtocol)?
    var micVolumeService: (any MicInputVolumeServiceProtocol)?
    private var apiKeyMarkedInvalid = false

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

            // API key gate — prompt on-the-fly if no key configured
            if let haiku = haikuCleanup {
                let hasKey = await haiku.hasAPIKey
                if !hasKey || apiKeyMarkedInvalid {
                    apiKeyMarkedInvalid = false
                    apiKeyWindowController?.show { [weak self] in
                        // Key saved — user can try recording again
                        Task { @MainActor in
                            await self?.handleHotkey()
                        }
                    }
                    return  // Don't start recording yet
                }
            }

            // Pause media BEFORE starting audio engine (MEDIA-01, MEDIA-03)
            mediaPlayback?.pause()
            try? await Task.sleep(for: .milliseconds(150))

            micVolumeService?.maximizeAndSave()

            // Start recording
            do {
                try audioRecorder?.start()
            } catch {
                mediaPlayback?.resume()  // Resume on start failure
                micVolumeService?.restore()
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
            mediaPlayback?.resume()   // MEDIA-02 — resume BEFORE stop so ALL exit paths (VAD fail, error, success) are covered
            micVolumeService?.restore()

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
                guard let rawText = try await sttEngine?.transcribe(buffer) else {
                    throw STTError.notLoaded
                }

                // Haiku cleanup (CLN-01/02/03/04) — fallback to raw on any error
                let finalText: String
                if let haiku = haikuCleanup {
                    do {
                        finalText = try await haiku.clean(rawText)
                    } catch let error as HaikuCleanupError {
                        switch error {
                        case .authFailed:
                            NotificationHelper.show(
                                title: "Clave de API invalida",
                                body: "Texto pegado sin limpiar"
                            )
                            apiKeyMarkedInvalid = true
                        case .noAPIKey:
                            NotificationHelper.show(
                                title: "Sin clave de API",
                                body: "Texto pegado sin limpiar"
                            )
                            apiKeyMarkedInvalid = true
                        default:
                            NotificationHelper.show(
                                title: "Texto pegado sin limpiar",
                                body: "Error de conexion"
                            )
                        }
                        finalText = rawText
                    } catch {
                        NotificationHelper.show(
                            title: "Texto pegado sin limpiar",
                            body: "Error de conexion"
                        )
                        finalText = rawText
                    }
                } else {
                    finalText = rawText
                }

                // Strip hallucinated suffix (HAIKU-02) — safety net after Haiku cleanup
                let strippedText = stripHallucinatedSuffix(from: finalText, rawInput: rawText)

                // Apply vocabulary corrections AFTER Haiku cleanup (VOC-02)
                let correctedText: String
                if let vocab = vocabularyService {
                    correctedText = vocab.apply(to: strippedText)
                } else {
                    correctedText = strippedText
                }

                overlayController?.hide()
                await textInjector?.inject(correctedText)

                // Save to transcription history (OUT-03)
                historyService?.append(correctedText)

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

    private func markAPIKeyInvalid() {
        apiKeyMarkedInvalid = true
    }

    func handleEscape() {
        guard state == .recording else { return }
        escapeMonitor?.stopMonitoring()
        stopAudioLevelPolling()
        overlayController?.hide()
        audioRecorder?.cancel()
        mediaPlayback?.resume()   // Resume on cancel
        micVolumeService?.restore()
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

    // MARK: - Hallucination Strip

    private func stripHallucinatedSuffix(from output: String, rawInput: String) -> String {
        let confirmedPatterns = ["gracias"]  // Only expand with confirmed evidence
        let lowercasedInput = rawInput.lowercased()
        var result = output
        for pattern in confirmedPatterns {
            // Trim trailing punctuation before checking suffix
            let trimmedResult = result
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: ".,;:!?"))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            // Only strip if pattern is at the END of output AND was NOT in raw STT text
            guard trimmedResult.lowercased().hasSuffix(pattern),
                  !lowercasedInput.contains(pattern) else { continue }
            let suffixStart = trimmedResult.index(trimmedResult.endIndex, offsetBy: -pattern.count)
            result = String(trimmedResult[..<suffixStart])
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: ".,;:!?"))
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return result
    }
}
