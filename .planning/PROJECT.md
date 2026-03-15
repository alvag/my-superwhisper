# My SuperWhisper

## What This Is

A local-first voice-to-text macOS menubar application for Apple Silicon. The user presses a global hotkey (Ctrl+Space) to start recording speech, speaks freely, then presses the hotkey again to stop. The audio is transcribed locally using a high-quality speech-to-text model, cleaned up by a local LLM (punctuation, formatting, filler word removal), and the final text is automatically pasted at the cursor position. Everything runs 100% locally — no cloud services, no data leaves the machine.

## Core Value

Frictionless voice-to-text that produces clean, well-formatted Spanish text locally — press a key, speak, press again, and polished text appears where you're typing.

## Requirements

### Validated

(None yet — ship to validate)

### Active

- [ ] Global hotkey (Ctrl+Space) toggles recording on/off from anywhere in macOS
- [ ] Audio capture from default microphone while recording is active
- [ ] Visual indicator in menubar showing recording state (idle/recording/processing)
- [ ] Local speech-to-text transcription optimized for Spanish on Apple Silicon
- [ ] Local LLM post-processing: add punctuation, capitalization, paragraph breaks
- [ ] Local LLM post-processing: remove filler words ("eh", "este", "o sea", repetitions)
- [ ] Auto-paste transcribed+cleaned text at current cursor position (simulate Cmd+V)
- [ ] Menubar app with status icon, basic settings, and activity log
- [ ] All processing runs locally — zero network calls for transcription or cleanup
- [ ] Configurable hotkey (default Ctrl+Space)
- [ ] Reasonable processing time (quality over speed — 3-5s acceptable)

### Out of Scope

- Multi-language support — Spanish only for v1
- Cloud-based transcription or LLM — fully local requirement
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
- LLM runtime to be determined by research (Ollama, llama.cpp, MLX, or others optimized for Apple Silicon)
- App framework to be determined by research (Swift/SwiftUI native, Tauri, or Electron)
- Quality of final text is prioritized over raw speed — user accepts 3-5 second processing time
- The app needs macOS accessibility permissions for global hotkey capture and simulated keystrokes

## Constraints

- **Platform**: macOS only, Apple Silicon (M1+) — must leverage Metal/Neural Engine
- **Privacy**: 100% local processing, no network calls for core functionality
- **Language**: Spanish as primary and only supported language in v1
- **UX**: Must feel instant-ish — total pipeline (transcribe + clean + paste) under 5 seconds for typical utterances (30-60 seconds of speech)
- **Resources**: Should not consume excessive RAM/CPU when idle — lightweight background process

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Local-only processing | Privacy-first, no dependency on external services | — Pending |
| Menubar app style | Unobtrusive, always accessible, macOS-native feel | — Pending |
| Auto-paste behavior | Minimum friction — text appears where you need it | — Pending |
| Spanish-only v1 | Focused scope, optimize for one language well | — Pending |
| Quality over speed | User prefers clean text even if it takes a few seconds more | — Pending |

---
*Last updated: 2026-03-15 after initialization*
