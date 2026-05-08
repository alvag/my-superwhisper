import Foundation
import CoreAudio
import ServiceManagement
import AppKit
import AVFoundation

struct PermissionItem: Identifiable {
    let id: String
    let title: String
    let detail: String
    let isGranted: Bool
}

@Observable
@MainActor
final class SettingsViewModel {
    private static let micTestSampleCount = 12
    private static let micTestSampleInterval: Duration = .milliseconds(100)
    private static let micTestSignalThreshold: Float = 0.02

    // -- Bool toggles con didSet -> UserDefaults --
    var pausePlaybackEnabled: Bool {
        didSet { UserDefaults.standard.set(pausePlaybackEnabled, forKey: "pausePlaybackEnabled") }
    }
    var maximizeMicVolumeEnabled: Bool {
        didSet { UserDefaults.standard.set(maximizeMicVolumeEnabled, forKey: "maximizeMicVolumeEnabled") }
    }

    // -- Launch at login con SMAppService --
    var launchAtLoginEnabled: Bool {
        didSet {
            do {
                if launchAtLoginEnabled { try SMAppService.mainApp.register() }
                else { try SMAppService.mainApp.unregister() }
            } catch {
                print("[Settings] LaunchAtLogin error: \(error)")
                launchAtLoginEnabled = SMAppService.mainApp.status == .enabled
            }
        }
    }

    // -- Microphone con delegate a service --
    var selectedMicID: AudioDeviceID? {
        didSet { microphoneService.selectedDeviceID = selectedMicID }
    }

    // -- Vocabulary con delegate a service --
    var vocabularyEntries: [VocabularyEntry] {
        didSet { vocabularyService.entries = vocabularyEntries }
    }

    // -- Read-only computed/stored --
    private(set) var availableMics: [AudioDeviceInfo] = []
    private(set) var permissionItems: [PermissionItem] = []
    private(set) var apiKeyConfigured = false
    private(set) var apiValidationStatus = "Sin validar todavía"
    private(set) var apiValidationInFlight = false
    private(set) var diagnostics = AppDiagnosticsStore.snapshot()
    private(set) var whisperReady = false
    private(set) var whisperLoadProgress: Double = 0.0
    private(set) var whisperModelName = AppDiagnosticsStore.sttModelName
    private(set) var whisperAssetsStatus = ModelAssetsStatus.missing.displayText
    private(set) var whisperAssetsPath = ""
    private(set) var whisperActionInFlight = false
    private(set) var runtimeState = AppState.idle.description
    private(set) var micTestInFlight = false
    private(set) var micTestStatus = "Sin probar"
    private(set) var micTestLevel: Double = 0.0

    // -- Closure para abrir APIKeyWindowController sin importar AppKit --
    var openAPIKey: () -> Void = {}

    // -- Servicios inyectados --
    private let vocabularyService: VocabularyService
    private let microphoneService: MicrophoneDeviceService
    private let permissionsManager: PermissionsManager
    private weak var coordinator: AppCoordinator?
    private let haikuCleanup: (any HaikuCleanupProtocol)?
    private let sttEngine: (any STTEngineProtocol)?
    private var refreshTimer: Timer?

    init(vocabularyService: VocabularyService,
         microphoneService: MicrophoneDeviceService,
         permissionsManager: PermissionsManager,
         coordinator: AppCoordinator?,
         haikuCleanup: (any HaikuCleanupProtocol)?,
         sttEngine: (any STTEngineProtocol)?) {
        self.vocabularyService = vocabularyService
        self.microphoneService = microphoneService
        self.permissionsManager = permissionsManager
        self.coordinator = coordinator
        self.haikuCleanup = haikuCleanup
        self.sttEngine = sttEngine
        // Cargar valores iniciales de la capa de persistencia existente
        self.pausePlaybackEnabled = UserDefaults.standard.bool(forKey: "pausePlaybackEnabled")
        self.maximizeMicVolumeEnabled = UserDefaults.standard.bool(forKey: "maximizeMicVolumeEnabled")
        self.launchAtLoginEnabled = SMAppService.mainApp.status == .enabled
        self.selectedMicID = microphoneService.selectedDeviceID
        self.vocabularyEntries = vocabularyService.entries
        self.availableMics = microphoneService.availableInputDevices()
        refreshStatuses()

        Task {
            await refreshWhisperStatus()
        }
    }

    func refreshStatuses() {
        let micStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        let accessibilityGranted = AXIsProcessTrusted()

        permissionItems = [
            PermissionItem(
                id: "microphone",
                title: "Micrófono",
                detail: accessibilityText(for: micStatus),
                isGranted: micStatus == .authorized
            ),
            PermissionItem(
                id: "accessibility",
                title: "Accesibilidad",
                detail: accessibilityGranted ? "Permiso concedido para pegar texto" : "Necesario para pegar texto automáticamente",
                isGranted: accessibilityGranted
            ),
            PermissionItem(
                id: "paste",
                title: "Automatización / pegado",
                detail: accessibilityGranted ? "Listo para inyectar texto en otras apps" : "Bloqueado mientras Accesibilidad no esté concedido",
                isGranted: accessibilityGranted
            )
        ]

        apiKeyConfigured = KeychainService.load() != nil
        apiValidationStatus = AppDiagnosticsStore.lastAPIValidation()
        diagnostics = AppDiagnosticsStore.snapshot()
        refreshRuntimeState()
    }

    func startRuntimeRefresh() {
        refreshTimer?.invalidate()
        refreshRuntimeState()
        Task { await refreshWhisperStatus() }
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshRuntimeState()
                await self?.refreshWhisperStatus()
            }
        }
    }

    func stopRuntimeRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    func openAccessibilitySettings() {
        permissionsManager.openSystemSettingsForAccessibility()
        refreshStatuses()
    }

    func openMicrophoneSettings() {
        permissionsManager.openSystemSettingsForMicrophone()
        refreshStatuses()
    }

    func testAPIConnection() {
        guard let haikuCleanup else { return }

        apiValidationInFlight = true
        apiValidationStatus = "Validando..."
        Task {
            defer {
                Task { @MainActor in
                    self.apiValidationInFlight = false
                    self.refreshStatuses()
                }
            }

            do {
                try await haikuCleanup.validateStoredAPIKey()
            } catch {
                // Status is persisted by HaikuCleanupService; no extra handling needed here.
            }
        }
    }

    func copyDiagnosticsToClipboard() {
        let snapshot = AppDiagnosticsStore.snapshot()
        let permissions = permissionItems.map { "- \($0.title): \($0.isGranted ? "ok" : "bloqueado") — \($0.detail)" }.joined(separator: "\n")
        let text = """
        MyWhisper diagnostics
        Versión: \(snapshot.appVersion)
        Modelo STT: \(snapshot.sttModel)
        Whisper assets: \(whisperAssetsStatus)
        Whisper path: \(whisperAssetsPath)
        Estado runtime: \(runtimeState)
        Provider limpieza: \(snapshot.cleanupProvider)
        API key configurada: \(apiKeyConfigured ? "sí" : "no")
        Última validación API: \(snapshot.lastAPIValidation)
        Whisper listo: \(whisperReady ? "sí" : "no")
        Progreso carga Whisper: \(Int(whisperLoadProgress * 100))%
        Último error: \(snapshot.lastTranscriptionError)

        Permisos:
        \(permissions)
        """

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    func prepareWhisperModel() {
        guard let sttEngine else { return }
        whisperActionInFlight = true
        Task {
            do {
                try await sttEngine.prepareModel()
            } catch {
                AppDiagnosticsStore.recordTranscriptionError("Whisper prepare: \(error.localizedDescription)")
            }
            whisperActionInFlight = false
            await refreshWhisperStatus()
        }
    }

    func resetWhisperModel() {
        guard let sttEngine else { return }
        whisperActionInFlight = true
        Task {
            do {
                try await sttEngine.resetModelAssets()
            } catch {
                AppDiagnosticsStore.recordTranscriptionError("Whisper reset: \(error.localizedDescription)")
            }
            whisperActionInFlight = false
            await refreshWhisperStatus()
        }
    }

    func runMicTest() {
        guard !micTestInFlight else { return }

        micTestInFlight = true
        micTestStatus = "Probando..."
        micTestLevel = 0.0

        Task {
            let granted = await permissionsManager.requestMicrophone()
            guard granted else {
                micTestStatus = "Permiso de micrófono pendiente"
                micTestInFlight = false
                return
            }

            let recorder = AudioRecorder()
            recorder.microphoneService = microphoneService

            do {
                try recorder.start()
                defer { recorder.cancel() }

                var peak: Float = 0.0
                for _ in 0..<Self.micTestSampleCount {
                    try await Task.sleep(for: Self.micTestSampleInterval)
                    peak = max(peak, recorder.audioLevel)
                    micTestLevel = Double(peak)
                }
                micTestStatus = peak > Self.micTestSignalThreshold ? "Entrada detectada" : "Sin señal clara"
            } catch {
                micTestStatus = "No se pudo iniciar: \(error.localizedDescription)"
            }

            micTestInFlight = false
        }
    }

    private func refreshWhisperStatus() async {
        guard let sttEngine else { return }
        whisperReady = await sttEngine.isReady
        whisperLoadProgress = await sttEngine.loadProgress
        whisperModelName = await sttEngine.modelName
        whisperAssetsStatus = await sttEngine.modelAssetsStatus.displayText
        whisperAssetsPath = await sttEngine.modelDirectory.path
        diagnostics = AppDiagnosticsStore.snapshot()
    }

    private func refreshRuntimeState() {
        runtimeState = coordinator?.state.description ?? AppState.idle.description
    }

    private func accessibilityText(for status: AVAuthorizationStatus) -> String {
        switch status {
        case .authorized: return "Permiso concedido"
        case .notDetermined: return "Pendiente de conceder"
        case .denied: return "Denegado"
        case .restricted: return "Restringido"
        @unknown default: return "Estado desconocido"
        }
    }
}
