# Requirements: My SuperWhisper

**Defined:** 2026-03-15
**Core Value:** Frictionless voice-to-text that produces clean, well-formatted Spanish text — press a key, speak, press again, and polished text appears where you're typing. Local STT + Haiku cleanup.

## v1 Requirements

Requirements for initial release. Each maps to roadmap phases.

### Recording

- [x] **REC-01**: User can press a global hotkey to start recording from any application
- [x] **REC-02**: User can press the same hotkey again to stop recording and trigger transcription
- [x] **REC-03**: User sees an animated waveform visualization while recording is active
- [x] **REC-04**: User can press Escape to cancel recording without pasting any text
- [x] **REC-05**: User can configure which hotkey activates recording (default: Option+Space, not Ctrl+Space due to macOS conflict)

### Audio

- [x] **AUD-01**: App captures audio from the default or selected microphone while recording
- [x] **AUD-02**: Audio is resampled to 16kHz mono Float32 for STT model input
- [x] **AUD-03**: Voice Activity Detection (VAD) filters silence before sending to STT to prevent hallucination

### Transcription

- [x] **STT-01**: Audio is transcribed locally using a speech-to-text model optimized for Spanish on Apple Silicon
- [x] **STT-02**: STT model is pre-loaded at app launch to avoid cold-start latency
- [x] **STT-03**: Transcription completes within reasonable time (<3s for 30-60s of speech on Apple Silicon)

### Text Cleanup

- [x] **CLN-01**: Haiku API adds correct punctuation (periods, commas, question/exclamation marks)
- [x] **CLN-02**: Haiku API adds proper capitalization and paragraph breaks
- [x] **CLN-03**: Haiku API removes Spanish filler words ("eh", "este", "o sea", "bueno", "pues") and verbal repetitions
- [x] **CLN-04**: Haiku API preserves the user's original meaning — no paraphrasing or content addition
- [x] **CLN-05**: Haiku API cleanup completes in <2s for typical transcription length

### Custom Vocabulary

- [x] **VOC-01**: User can define a correction dictionary (misspelled names, technical terms, brand names)
- [x] **VOC-02**: Corrections are applied after LLM cleanup to fix persistent misrecognitions

### Output

- [x] **OUT-01**: Clean text is automatically pasted at the current cursor position (simulates Cmd+V)
- [x] **OUT-02**: Auto-paste works system-wide in any macOS application (Slack, VS Code, browsers, Notes, etc.)
- [x] **OUT-03**: User can view a history of recent transcriptions (last 10-20) to recover text
- [x] **OUT-04**: User can copy any item from the transcription history to clipboard

### macOS Integration

- [x] **MAC-01**: App runs as a menubar application with status icon showing current state (idle/recording/processing/done)
- [x] **MAC-02**: App prompts for Accessibility and Microphone permissions on first launch with clear explanations
- [x] **MAC-03**: App checks permission health on every launch (permissions can reset after OS updates)
- [x] **MAC-04**: User can select which microphone to use from a list of available audio inputs
- [x] **MAC-05**: App consumes less than 200MB RAM when idle (only STT model in memory, no local LLM)
- [x] **MAC-06**: App requires macOS 14+ on Apple Silicon (M1 or later)

### Privacy & API

- [x] **PRV-01**: Audio is transcribed 100% locally — raw audio never leaves the machine
- [x] **PRV-02**: Only transcribed text (not audio) is sent to Anthropic's Haiku API for cleanup
- [x] **PRV-03**: User can configure their Anthropic API key in settings
- [x] **PRV-04**: App gracefully handles API errors (network down, invalid key) with clear user feedback

## v2 Requirements

Deferred to future release. Tracked but not in current roadmap.

### Interaction

- **INT-01**: Push-to-talk mode (hold hotkey to record, release to stop) as alternative to toggle
- **INT-02**: Configurable LLM cleanup aggressiveness (light vs full modes)

### Multi-language

- **LANG-01**: English language support in addition to Spanish
- **LANG-02**: Automatic language detection between supported languages

### Advanced

- **ADV-01**: Reformulation modes (formal email, structured notes)
- **ADV-02**: Keyboard-driven history navigation

### Offline

- **OFF-01**: Local LLM fallback for text cleanup when offline (Ollama/MLX)
- **OFF-02**: Full offline operation after initial model download

## Out of Scope

Explicitly excluded. Documented to prevent scope creep.

| Feature | Reason |
|---------|--------|
| Real-time streaming transcription | Doubles complexity, degrades accuracy vs batch, local models don't support it well |
| Voice commands / macros | Separate always-listening model, massively increases scope |
| Audio file import / transcription | Different UX and pipeline, different product |
| Meeting recording & summarization | Privacy concerns, different product mode entirely |
| Cloud STT | Audio must stay local — only text goes to API |
| Continuous/always-on dictation | High CPU/memory, accidental transcription risk |
| Mac App Store distribution | CGEventPost for paste is blocked in sandboxed apps |
| iOS/iPad version | macOS only for v1 |
| Intel Mac support | Apple Silicon only — leverages Neural Engine/Metal |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| REC-01 | Phase 1 | Done (01-01) |
| REC-02 | Phase 2 | Complete |
| REC-03 | Phase 2 | Complete |
| REC-04 | Phase 1 | Done (01-01) |
| REC-05 | Phase 4 | Complete |
| AUD-01 | Phase 2 | Complete |
| AUD-02 | Phase 2 | Complete |
| AUD-03 | Phase 2 | Complete |
| STT-01 | Phase 2 | Complete |
| STT-02 | Phase 2 | Complete |
| STT-03 | Phase 2 | Complete |
| CLN-01 | Phase 3 | Complete |
| CLN-02 | Phase 3 | Complete |
| CLN-03 | Phase 3 | Complete |
| CLN-04 | Phase 3 | Complete |
| CLN-05 | Phase 3 | Complete |
| VOC-01 | Phase 4 | Complete |
| VOC-02 | Phase 4 | Complete |
| OUT-01 | Phase 1 | Complete |
| OUT-02 | Phase 1 | Complete |
| OUT-03 | Phase 4 | Complete |
| OUT-04 | Phase 4 | Complete |
| MAC-01 | Phase 1 | Done (01-01) |
| MAC-02 | Phase 1 | Complete |
| MAC-03 | Phase 1 | Complete |
| MAC-04 | Phase 4 | Complete |
| MAC-05 | Phase 4 | Complete |
| MAC-06 | Phase 1 | Done (01-01) |
| PRV-01 | Phase 1 | Done (01-01) |
| PRV-02 | Phase 3 | Complete |
| PRV-03 | Phase 3 | Complete |
| PRV-04 | Phase 3 | Complete |

**Coverage:**
- v1 requirements: 32 total
- Mapped to phases: 32
- Unmapped: 0

---
*Requirements defined: 2026-03-15*
*Last updated: 2026-03-15 after Haiku API decision — 32 requirements mapped*
