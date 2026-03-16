# Phase 2: Audio + Transcription - Context

**Gathered:** 2026-03-15
**Status:** Ready for planning

<domain>
## Phase Boundary

Full pipeline from microphone input to raw Spanish text pasted at cursor. Replaces Phase 1 stubs with real audio capture, voice activity detection, and local speech-to-text via WhisperKit. No LLM cleanup — raw transcription output is pasted directly. Haiku cleanup is Phase 3.

</domain>

<decisions>
## Implementation Decisions

### Waveform Visualization
- Existing 5 bars in OverlayView become reactive to real microphone audio levels — taller bars = louder audio, flat bars during silence
- Bars stay red always — consistent with red menubar icon during recording
- Overlay size unchanged: 100x48 pts capsule with material blur
- Update latency ~30-60ms (~16-33 fps) — must feel instantaneous response to voice

### Silence / No-Speech Handling
- VAD runs post-recording only — after user presses hotkey to stop, analyze the full buffer for voice presence
- If no speech detected: do NOT transcribe, do NOT paste text
- Show macOS native notification: "No se detectó voz"
- Return to idle state immediately

### Processing Flow
- On stop: overlay transitions from waveform bars to a spinner animation while WhisperKit transcribes
- Overlay stays visible during processing (spinner) — disappears when transcription completes and text is pasted
- Menubar icon changes to blue (processing) as already established in Phase 1
- On transcription error: overlay disappears, macOS native notification with error message, return to idle
- Notification pattern consistent across all cases: "No se detectó voz", "Error de transcripción", and Phase 1's "Texto copiado — pegá con Cmd+V"

### Model Loading
- WhisperKit model pre-loaded at app launch (applicationDidFinishLaunching) — no cold-start on first recording (STT-02)
- If user tries to record before model finishes loading: allow recording normally, show spinner when stopped, wait for model to finish loading, then transcribe
- First app launch: download model automatically with progress shown in menubar dropdown ("Descargando modelo...")
- Model cached locally after first download — subsequent launches load from disk

### STT Model & Quality
- Use largest available WhisperKit model (large-v3) — maximum transcription accuracy for Spanish
- Force language to Spanish (language="es") — no auto-detection, better accuracy, v2 can add multi-language
- Expect ~1-3GB RAM for model, ~3-5s transcription time for 30-60s audio on Apple Silicon
- Audio resampled to 16kHz mono Float32 per AUD-02

### Output
- Phase 2 pastes raw WhisperKit output directly — no punctuation cleanup, no filler removal
- Text may contain muletillas ("eh", "este", "o sea") and lack punctuation — this is expected and correct for Phase 2
- Phase 3 adds Haiku API cleanup to produce polished output

### Claude's Discretion
- VAD implementation approach (energy-based threshold, WebRTC VAD, or Silero VAD — researcher decides)
- Audio buffer collection strategy and format conversion pipeline
- Spinner animation style in overlay during processing
- Model download progress UI details
- WhisperKit configuration parameters beyond language and model size
- Error categorization and specific error messages

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project Context
- `.planning/PROJECT.md` — Project vision, constraints (local STT, Apple Silicon, Spanish only v1)
- `.planning/REQUIREMENTS.md` — AUD-01/02/03, STT-01/02/03, REC-02/03 requirements for this phase
- `.planning/ROADMAP.md` — Phase 2 success criteria and dependency on Phase 1

### Phase 1 Context
- `.planning/phases/01-foundation/01-CONTEXT.md` — Hotkey behavior, menubar states, overlay design, paste mechanism decisions

### Research (from Phase 1)
- `.planning/research/ARCHITECTURE.md` — Component architecture, FSM design, data flow
- `.planning/research/STACK.md` — Swift/SwiftUI stack, HotKey library, AVFoundation, CGEventPost
- `.planning/research/PITFALLS.md` — Known pitfalls including VAD library selection concern (STATE.md blocker)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `AudioRecorder.swift` — Stub with AVAudioEngine setup, tap installation, start/stop/cancel. Phase 2 replaces stub methods with real capture
- `OverlayView.swift` — 5 animated bars (placeholder). Phase 2 adds audio level input to drive bar heights
- `AppCoordinator.swift` — FSM with idle/recording/processing/error states. Phase 2 replaces `textInjector?.inject("Texto de prueba")` with real STT pipeline
- `TextInjector.swift` — Clipboard + CGEventPost paste. Already works — Phase 2 just passes real transcription text

### Established Patterns
- `AudioRecorderProtocol` — startStub/stopStub/cancelStub methods need renaming to start/stop/cancel with real implementation
- `@Observable` + `@MainActor` on AppCoordinator — state updates drive UI reactively
- `OverlayWindowControllerProtocol` — show/hide interface for overlay
- `PermissionsManaging` — on-the-fly microphone permission request already wired in handleHotkey()

### Integration Points
- `AppCoordinator.handleHotkey()` — recording→processing transition needs real audio buffer → STT → paste pipeline
- `AppDelegate.applicationDidFinishLaunching` — model pre-loading goes here
- `OverlayView` — needs audio level data binding (new property/protocol method)
- `Package.swift` — WhisperKit dependency needs to be added

</code_context>

<specifics>
## Specific Ideas

- Overlay spinner during processing gives the user clear feedback that transcription is happening (not a hang)
- macOS native notifications for all feedback (silence, errors) — consistent system-level UX
- Model download on first launch is a one-time cost — acceptable since app needs internet for Haiku API in Phase 3 anyway

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 02-audio-transcription*
*Context gathered: 2026-03-15*
