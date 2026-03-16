# My SuperWhisper

## What This Is

A local-first voice-to-text macOS menubar application for Apple Silicon. Press a configurable global hotkey (default Option+Space) to start recording, speak freely, press again to stop. Audio is transcribed locally via WhisperKit (large-v3, Spanish), cleaned up by Anthropic Haiku API (punctuation, filler removal), and the polished text is auto-pasted at the cursor. 3,445 lines of Swift, fully functional with settings, history, vocabulary corrections, and distribution pipeline.

## Core Value

Frictionless voice-to-text that produces clean, well-formatted Spanish text — press a key, speak, press again, and polished text appears where you're typing. Local STT + Haiku cleanup.

## Requirements

### Validated

- ✓ Global hotkey (Option+Space) toggles recording on/off from anywhere in macOS — v1.0
- ✓ Audio capture from default or selected microphone while recording — v1.0
- ✓ Visual indicator in menubar showing recording state (idle/recording/processing) — v1.0
- ✓ Animated waveform visualization during recording — v1.0
- ✓ Local speech-to-text transcription (WhisperKit large-v3) optimized for Spanish on Apple Silicon — v1.0
- ✓ Haiku API post-processing: punctuation, capitalization, paragraph breaks — v1.0
- ✓ Haiku API post-processing: filler word removal ("eh", "este", "o sea") — v1.0
- ✓ Auto-paste transcribed+cleaned text at cursor (Cmd+V simulation) — v1.0
- ✓ Configurable hotkey via KeyboardShortcuts click-to-record — v1.0
- ✓ Microphone selection from available audio inputs — v1.0
- ✓ Transcription history (last 20, click-to-copy) — v1.0
- ✓ Custom vocabulary corrections (case-insensitive, post-Haiku) — v1.0
- ✓ API key management with Keychain storage and validation — v1.0
- ✓ Permission health check on every launch — v1.0
- ✓ Graceful error handling with fallback to raw text — v1.0
- ✓ Idle RAM ~27MB (MAC-05 <200MB) — v1.0

### Active

- [ ] Pause Playback: pausar automáticamente medios en reproducción al iniciar grabación y reanudar al terminar
- [ ] Toggle configurable en Settings para activar/desactivar Pause Playback

## Current Milestone: v1.1 Pause Playback

**Goal:** Pausar automáticamente cualquier medio en reproducción (música, video, etc.) al iniciar grabación y reanudar al terminar, con toggle configurable en Settings.

**Target features:**
- Pause/resume automático de medios al grabar (sistema + terceros)
- Toggle en Settings para activar/desactivar

### Out of Scope

- Multi-language support — Spanish only for v1
- Cloud-based transcription — STT must stay local (audio never leaves the machine)
- iOS/iPad version — macOS only
- Real-time streaming transcription — batch after recording stops
- Custom voice commands or macros
- Text-to-speech / voice synthesis
- Reformulation/professional rewriting modes — only punctuation + filler removal for v1
- Mac App Store distribution — CGEventPost blocked in sandboxed apps

## Context

- **Shipped:** v1.0 on 2026-03-16 (3,445 LOC Swift, 4 phases, 13 plans)
- Target hardware: Apple Silicon Macs (M1/M2/M3/M4) with Neural Engine and unified memory
- Stack: Swift/SwiftUI, WhisperKit (local STT), Anthropic Haiku API (text cleanup), KeyboardShortcuts (hotkey), CoreAudio (mic selection)
- User primarily dictates in Spanish
- Quality of final text prioritized over raw speed — pipeline completes in ~3-5 seconds
- Non-sandboxed (Developer ID distribution) — required for CGEventPost paste simulation
- Distribution: DMG signed with Developer ID + Apple notarization via `scripts/build-dmg.sh`

## Constraints

- **Platform**: macOS only, Apple Silicon (M1+) — leverages Metal/Neural Engine via WhisperKit
- **Privacy**: Audio never leaves the machine (local STT). Only transcribed text goes to Haiku API for cleanup
- **Language**: Spanish as primary and only supported language in v1
- **UX**: Total pipeline (transcribe + clean + paste) under 5 seconds for 30-60s speech
- **Resources**: Idle RSS ~27MB; WhisperKit model memory managed by Neural Engine

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Local STT + Haiku cleanup | Audio stays local for privacy; text cleanup via Haiku API for quality and simplicity | ✓ Good — clean text, simple architecture |
| WhisperKit large-v3 | Best Spanish accuracy on Apple Silicon, CoreML optimized | ✓ Good — <3s transcription for 30-60s audio |
| Menubar app style | Unobtrusive, always accessible, macOS-native feel | ✓ Good |
| Auto-paste via CGEventPost | Minimum friction — text appears where you need it | ✓ Good — works system-wide |
| KeyboardShortcuts (sindresorhus) | Click-to-record UX, conflict detection, UserDefaults persistence | ✓ Good — replaced HotKey in Phase 4 |
| Spanish-only v1 | Focused scope, optimize for one language well | ✓ Good |
| Quality over speed | User prefers clean text even if it takes a few seconds more | ✓ Good |
| UserDefaults for settings/history/vocabulary | Simple, sufficient for v1 data sizes (20 history entries, small vocab list) | ✓ Good |
| Developer ID distribution (not App Store) | CGEventPost blocked in sandboxed apps | ✓ Required |
| Haiku fallback to raw text | User always gets text — degraded quality beats no output | ✓ Good |

---
*Last updated: 2026-03-16 after v1.1 milestone started*
