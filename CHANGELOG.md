# Changelog

All notable changes to My SuperWhisper will be documented in this file.

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
