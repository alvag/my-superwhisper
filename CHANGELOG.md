# Changelog

All notable changes to My SuperWhisper will be documented in this file.

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
