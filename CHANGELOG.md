# Changelog

All notable changes to My SuperWhisper will be documented in this file.

## [Unreleased] - 2026-04-23 — Listening Overlay Polish

### Changed
- Cleaned up the listening overlay container so the rounded capsule renders cleanly without clipped dark bottom artifacts
- Reworked the listening animation from a basic red-bar look into a more polished waveform-style visualization
- Tuned overlay stroke, shadow, spacing, and panel sizing for a more native macOS feel

### Technical
- Disabled the native panel shadow and moved visual depth styling into SwiftUI for more predictable rendering
- Increased overlay panel bounds/padding so the material, shadow, and rounded shape are not cut off
- Updated the audio visualization to use seven capsule bars, a refined gradient, and spring-based animation

## [v1.3] - 2026-03-24 — Settings UX

### Added
- Ventana de Settings persistente: permanece abierta al hacer click fuera (NSWindow reemplaza NSPanel)
- SwiftUI Form con 4 secciones agrupadas estilo System Settings: Grabacion, API, Vocabulario, Sistema
- SF Symbols en headers de seccion (mic.fill, key.fill, textformat.abc, gear)
- Picker de microfono con opcion "Predeterminado del sistema" y dispositivos disponibles
- Lista de vocabulario editable inline con botones +/- para agregar y eliminar correcciones
- Boton "Configurar clave API..." que abre el panel existente de ingreso

### Changed
- SettingsWindowController: NSPanel reemplazado por NSWindow + NSHostingController para ciclo de vida correcto
- SettingsView: expandida de 1 seccion placeholder a Form completo con 4 secciones
- VocabularyEntry: agregado Identifiable conformance (var id: UUID) para ForEach binding syntax
- Activation policy lifecycle: .regular al abrir Settings, .accessory al cerrar, con restauracion de foco

### Technical
- SettingsViewModel con @Observable y @Bindable bridge — didSet persistence sin @AppStorage
- Picker con .tag(nil as AudioDeviceID?) y .tag(device.id as AudioDeviceID?) para seleccion correcta con tipo opcional
- ForEach($viewModel.vocabularyEntries) con binding syntax habilitada por Identifiable
- Task { @MainActor in } para diferir mutacion de array y evitar exclusive access violation
- import CoreAudio en SettingsView para AudioDeviceID en scope

## [v1.2] - 2026-03-17 — Dictation Quality

### Added
- Haiku Rule 6: prohibir adicion de frases de cortesia alucinadas (gracias, de nada, hasta luego) en el system prompt
- Post-processing suffix strip que remueve "gracias" alucinado cuando no esta en el input STT original
- Auto-maximize mic input volume (1.0) al iniciar grabacion via CoreAudio HAL
- Restaurar volumen original del mic al terminar grabacion (todos los exit paths: stop, Escape, VAD, error)
- Settings toggle "Maximizar volumen al grabar" (default: ON)
- Degradacion silenciosa en dispositivos sin volumen de entrada ajustable

### Changed
- MediaPlaybackService: reemplazado HID media key toggle por MRMediaRemoteSendCommand explicito (pause=1, play=0) via framework privado MediaRemote
- MediaPlaybackService: consulta MRMediaRemoteGetNowPlayingApplicationIsPlaying antes de pausar para no reanudar media que ya estaba en pausa

### Technical
- MicInputVolumeService con CoreAudio AudioObjectGet/SetPropertyData y AudioObjectIsPropertySettable guard
- MicInputVolumeServiceProtocol para DI injection en AppCoordinator
- resolveActiveDeviceID() valida dispositivo seleccionado contra availableInputDevices() en cada llamada
- stripHallucinatedSuffix() con trimming de puntuacion para variantes "Gracias"/"Gracias."
- 39 tests nuevos: 24 Haiku QA (hallucination, preservation, regression, edge cases) + 15 Volume QA (exit paths, ordering, delegation)

## [v1.1] - 2026-03-17 — Pause Playback

### Added
- Auto-pause media playback (Spotify, Apple Music, YouTube/Safari) when recording starts
- Auto-resume media playback when recording stops
- Settings toggle "Pausar reproduccion al grabar" (default: ON)
- Music.app launch guard — prevents rcd from opening Music.app when no media app is running

### Technical
- MediaPlaybackService using HID media keys via CGEventPost
- isAnyMediaAppRunning() guard via NSWorkspace
- 11 unit tests (7 coordinator + 4 service)

## [v1.0] - 2026-03-16 — MVP

### Added
- Global hotkey (Option+Space) toggles recording on/off from anywhere in macOS
- Local speech-to-text via WhisperKit large-v3 optimized for Spanish on Apple Silicon
- Haiku API post-processing: punctuation, capitalization, paragraph breaks, filler word removal
- Auto-paste transcribed text at cursor via CGEventPost
- Animated waveform visualization during recording
- Menubar app with recording state indicator (idle/recording/processing)
- Configurable hotkey via KeyboardShortcuts
- Microphone selection from available audio inputs
- Transcription history (last 20 entries, click-to-copy)
- Custom vocabulary corrections (case-insensitive, post-Haiku)
- API key management with Keychain storage and validation
- Permission health check on every launch
- Graceful error handling with fallback to raw text
- DMG distribution signed with Developer ID + Apple notarization
