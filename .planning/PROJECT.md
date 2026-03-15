# My SuperWhisper

## What This Is

A local-first voice-to-text macOS menubar application for Apple Silicon. The user presses a global hotkey (Option+Space) to start recording speech, speaks freely, then presses the hotkey again to stop. The audio is transcribed locally using a high-quality speech-to-text model, then cleaned up by Anthropic's Haiku model via API (punctuation, formatting, filler word removal), and the final text is automatically pasted at the cursor position. Transcription is 100% local — text cleanup uses Haiku API for quality and simplicity (no local LLM to manage).

## Core Value

Frictionless voice-to-text that produces clean, well-formatted Spanish text — press a key, speak, press again, and polished text appears where you're typing. Local STT + Haiku cleanup.

## Requirements

### Validated

(None yet — ship to validate)

### Active

- [ ] Global hotkey (Ctrl+Space) toggles recording on/off from anywhere in macOS
- [ ] Audio capture from default microphone while recording is active
- [ ] Visual indicator in menubar showing recording state (idle/recording/processing)
- [ ] Local speech-to-text transcription optimized for Spanish on Apple Silicon
- [ ] Haiku API post-processing: add punctuation, capitalization, paragraph breaks
- [ ] Haiku API post-processing: remove filler words ("eh", "este", "o sea", repetitions)
- [ ] Auto-paste transcribed+cleaned text at current cursor position (simulate Cmd+V)
- [ ] Menubar app with status icon, basic settings, and activity log
- [ ] STT runs locally; text cleanup uses Haiku API (requires internet for cleanup only)
- [ ] Configurable hotkey (default Option+Space)
- [ ] Reasonable processing time (quality over speed — 3-5s acceptable)

### Out of Scope

- Multi-language support — Spanish only for v1
- Cloud-based transcription — STT must stay local (audio never leaves the machine)
- iOS/iPad version — macOS only
- Real-time streaming transcription — batch after recording stops
- Custom voice commands or macros
- Text-to-speech / voice synthesis
- Reformulation/professional rewriting modes — only punctuation + filler removal for v1

## Context

- Target hardware: Apple Silicon Macs (M1/M2/M3/M4) with Neural Engine and unified memory
- Inspired by SuperWhisper and WhisperFlow — commercial apps that do similar but use cloud or Whisper
- User primarily dictates in Spanish
- STT model to be determined by research (Nvidia Parakeet, Whisper.cpp, faster-whisper, or others optimized for Apple Silicon)
- LLM cleanup: Anthropic Haiku via API — no local LLM needed, simplifies architecture significantly
- App framework to be determined by research (Swift/SwiftUI native, Tauri, or Electron)
- Quality of final text is prioritized over raw speed — user accepts 3-5 second processing time
- The app needs macOS accessibility permissions for global hotkey capture and simulated keystrokes

## Constraints

- **Platform**: macOS only, Apple Silicon (M1+) — must leverage Metal/Neural Engine
- **Privacy**: Audio never leaves the machine (local STT). Only transcribed text goes to Haiku API for cleanup
- **Language**: Spanish as primary and only supported language in v1
- **UX**: Must feel instant-ish — total pipeline (transcribe + clean + paste) under 5 seconds for typical utterances (30-60 seconds of speech)
- **Resources**: Should not consume excessive RAM/CPU when idle — lightweight background process

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Local STT + Haiku cleanup | Audio stays local for privacy; text cleanup via Haiku API for quality and simplicity — no local LLM to manage | — Pending |
| Menubar app style | Unobtrusive, always accessible, macOS-native feel | — Pending |
| Auto-paste behavior | Minimum friction — text appears where you need it | — Pending |
| Spanish-only v1 | Focused scope, optimize for one language well | — Pending |
| Quality over speed | User prefers clean text even if it takes a few seconds more | — Pending |

---
*Last updated: 2026-03-15 after Haiku API decision for LLM cleanup*
