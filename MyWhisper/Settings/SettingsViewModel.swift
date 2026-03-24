import Foundation
import CoreAudio
import ServiceManagement

@Observable
@MainActor
final class SettingsViewModel {

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

    // -- Closure para abrir APIKeyWindowController sin importar AppKit --
    var openAPIKey: () -> Void = {}

    // -- Servicios inyectados --
    private let vocabularyService: VocabularyService
    private let microphoneService: MicrophoneDeviceService

    init(vocabularyService: VocabularyService,
         microphoneService: MicrophoneDeviceService,
         haikuCleanup: (any HaikuCleanupProtocol)?) {
        self.vocabularyService = vocabularyService
        self.microphoneService = microphoneService
        // Cargar valores iniciales de la capa de persistencia existente
        self.pausePlaybackEnabled = UserDefaults.standard.bool(forKey: "pausePlaybackEnabled")
        self.maximizeMicVolumeEnabled = UserDefaults.standard.bool(forKey: "maximizeMicVolumeEnabled")
        self.launchAtLoginEnabled = SMAppService.mainApp.status == .enabled
        self.selectedMicID = microphoneService.selectedDeviceID
        self.vocabularyEntries = vocabularyService.entries
        self.availableMics = microphoneService.availableInputDevices()
    }
}
