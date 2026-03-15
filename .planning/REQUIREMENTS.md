# Requirements: My SuperWhisper

**Defined:** 2026-03-15
**Core Value:** Frictionless voice-to-text that produces clean, well-formatted Spanish text locally — press a key, speak, press again, and polished text appears where you're typing.

## v1 Requirements

Requirements for initial release. Each maps to roadmap phases.

### Recording

- [ ] **REC-01**: User can press a global hotkey to start recording from any application
- [ ] **REC-02**: User can press the same hotkey again to stop recording and trigger transcription
- [ ] **REC-03**: User sees an animated waveform visualization while recording is active
- [ ] **REC-04**: User can press Escape to cancel recording without pasting any text
- [ ] **REC-05**: User can configure which hotkey activates recording (default: Option+Space, not Ctrl+Space due to macOS conflict)

### Audio

- [ ] **AUD-01**: App captures audio from the default or selected microphone while recording
- [ ] **AUD-02**: Audio is resampled to 16kHz mono Float32 for STT model input
- [ ] **AUD-03**: Voice Activity Detection (VAD) filters silence before sending to STT to prevent hallucination

### Transcription

- [ ] **STT-01**: Audio is transcribed locally using a speech-to-text model optimized for Spanish on Apple Silicon
- [ ] **STT-02**: STT model is pre-loaded at app launch to avoid cold-start latency
- [ ] **STT-03**: Transcription completes within reasonable time (<3s for 30-60s of speech on Apple Silicon)

### Text Cleanup

- [ ] **CLN-01**: Local LLM adds correct punctuation (periods, commas, question/exclamation marks)
- [ ] **CLN-02**: Local LLM adds proper capitalization and paragraph breaks
- [ ] **CLN-03**: Local LLM removes Spanish filler words ("eh", "este", "o sea", "bueno", "pues") and verbal repetitions
- [ ] **CLN-04**: Local LLM preserves the user's original meaning — no paraphrasing or content addition
- [ ] **CLN-05**: LLM model stays warm in memory for fast inference (<2s for typical transcription cleanup)

### Custom Vocabulary

- [ ] **VOC-01**: User can define a correction dictionary (misspelled names, technical terms, brand names)
- [ ] **VOC-02**: Corrections are applied after LLM cleanup to fix persistent misrecognitions

### Output

- [ ] **OUT-01**: Clean text is automatically pasted at the current cursor position (simulates Cmd+V)
- [ ] **OUT-02**: Auto-paste works system-wide in any macOS application (Slack, VS Code, browsers, Notes, etc.)
- [ ] **OUT-03**: User can view a history of recent transcriptions (last 10-20) to recover text
- [ ] **OUT-04**: User can copy any item from the transcription history to clipboard

### macOS Integration

- [ ] **MAC-01**: App runs as a menubar application with status icon showing current state (idle/recording/processing/done)
- [ ] **MAC-02**: App prompts for Accessibility and Microphone permissions on first launch with clear explanations
- [ ] **MAC-03**: App checks permission health on every launch (permissions can reset after OS updates)
- [ ] **MAC-04**: User can select which microphone to use from a list of available audio inputs
- [ ] **MAC-05**: App consumes less than 100MB RAM when idle (models can be unloaded or memory-mapped)
- [ ] **MAC-06**: App requires macOS 14+ on Apple Silicon (M1 or later)

### Privacy

- [ ] **PRV-01**: All processing (STT + LLM) runs 100% locally — zero network calls for core functionality
- [ ] **PRV-02**: No audio or transcription data is sent to any external service
- [ ] **PRV-03**: App works fully offline after initial model download

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

## Out of Scope

Explicitly excluded. Documented to prevent scope creep.

| Feature | Reason |
|---------|--------|
| Real-time streaming transcription | Doubles complexity, degrades accuracy vs batch, local models don't support it well |
| Voice commands / macros | Separate always-listening model, massively increases scope |
| Audio file import / transcription | Different UX and pipeline, different product |
| Meeting recording & summarization | Privacy concerns, different product mode entirely |
| Cloud fallback | Breaks privacy guarantee, adds network dependency |
| Continuous/always-on dictation | High CPU/memory, accidental transcription risk |
| Mac App Store distribution | CGEventPost for paste is blocked in sandboxed apps |
| iOS/iPad version | macOS only for v1 |
| Intel Mac support | Apple Silicon only — leverages Neural Engine/Metal |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| REC-01 | — | Pending |
| REC-02 | — | Pending |
| REC-03 | — | Pending |
| REC-04 | — | Pending |
| REC-05 | — | Pending |
| AUD-01 | — | Pending |
| AUD-02 | — | Pending |
| AUD-03 | — | Pending |
| STT-01 | — | Pending |
| STT-02 | — | Pending |
| STT-03 | — | Pending |
| CLN-01 | — | Pending |
| CLN-02 | — | Pending |
| CLN-03 | — | Pending |
| CLN-04 | — | Pending |
| CLN-05 | — | Pending |
| VOC-01 | — | Pending |
| VOC-02 | — | Pending |
| OUT-01 | — | Pending |
| OUT-02 | — | Pending |
| OUT-03 | — | Pending |
| OUT-04 | — | Pending |
| MAC-01 | — | Pending |
| MAC-02 | — | Pending |
| MAC-03 | — | Pending |
| MAC-04 | — | Pending |
| MAC-05 | — | Pending |
| MAC-06 | — | Pending |
| PRV-01 | — | Pending |
| PRV-02 | — | Pending |
| PRV-03 | — | Pending |

**Coverage:**
- v1 requirements: 31 total
- Mapped to phases: 0
- Unmapped: 31 ⚠️

---
*Requirements defined: 2026-03-15*
*Last updated: 2026-03-15 after initial definition*
