# Roadmap: My SuperWhisper

## Overview

Four phases following the hard dependency chain of this app: system integration must come before audio, audio before STT, STT before LLM cleanup. Phase 1 establishes the macOS foundation (menubar, hotkey, paste, permissions) with no ML. Phase 2 adds the full audio-to-raw-text pipeline. Phase 3 wires in LLM cleanup to produce the final polished output — delivering the core product promise. Phase 4 completes v1 with settings, history, vocabulary, and distribution readiness.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [x] **Phase 1: Foundation** - macOS app shell with hotkey, menubar, paste, and permissions — no ML (completed 2026-03-15)
- [x] **Phase 2: Audio + Transcription** - Full pipeline from microphone input to raw Spanish text at cursor (completed 2026-03-16)
- [ ] **Phase 3: Haiku Cleanup** - Adds Anthropic Haiku API post-processing to deliver clean, punctuated text end-to-end
- [ ] **Phase 4: Settings, History, and Polish** - Configurable settings, transcription history, vocabulary corrections, and distribution readiness

## Phase Details

### Phase 1: Foundation
**Goal**: Users can press a hotkey from any app, see recording state in the menubar, and have text pasted at their cursor — without any ML
**Depends on**: Nothing (first phase)
**Requirements**: MAC-01, MAC-02, MAC-03, MAC-06, PRV-01, PRV-02, REC-01, REC-04, OUT-01, OUT-02
**Success Criteria** (what must be TRUE):
  1. User presses the hotkey from any running application and the menubar icon changes state
  2. User can cancel an active recording session by pressing Escape with no text pasted
  3. App prompts for Accessibility and Microphone permissions on first launch with clear explanations
  4. App detects when permissions have been revoked (e.g., after OS update) and surfaces a recovery prompt on every launch
  5. Text placed on the clipboard is automatically pasted at the current cursor position in any app (Slack, VS Code, browser, Notes)
**Plans**: 4 plans

Plans:
- [x] 01-01-PLAN.md — Xcode scaffold, AppState FSM, AppCoordinator, HotkeyMonitor, EscapeMonitor, MenubarController
- [x] 01-02-PLAN.md — PermissionsManager (health check + on-the-fly requesting) and PermissionBlockedView
- [x] 01-03-PLAN.md — TextInjector (paste simulation), AudioRecorder stub, OverlayWindowController, full wiring
- [x] 01-04-PLAN.md — Gap closure: wire on-the-fly microphone permission request into AppCoordinator (MAC-02 partial fix)

### Phase 2: Audio + Transcription
**Goal**: Users can speak after pressing the hotkey and receive the raw transcribed Spanish text pasted at their cursor
**Depends on**: Phase 1
**Requirements**: AUD-01, AUD-02, AUD-03, STT-01, STT-02, STT-03, REC-02, REC-03
**Success Criteria** (what must be TRUE):
  1. User sees an animated waveform visualization in the UI while the microphone is actively recording
  2. User presses the hotkey a second time and raw transcribed Spanish text appears at the cursor within 5 seconds for a 30-60 second recording
  3. A recording with no detectable speech (silence or background noise only) does not trigger transcription and produces no pasted output
  4. App is responsive immediately on launch — STT model is pre-loaded so the first recording does not incur a cold-start delay
**Plans**: 3 plans

Plans:
- [ ] 02-01-PLAN.md — Real AudioRecorder (AVAudioEngine capture + resampling + RMS), VAD module, reactive OverlayView with spinner mode
- [ ] 02-02-PLAN.md — WhisperKit SPM dependency, STTEngine actor with model lifecycle and Spanish transcription
- [ ] 02-03-PLAN.md — Full pipeline wiring (AppCoordinator + AppDelegate), NotificationHelper, updated tests, end-to-end verification

### Phase 3: Haiku Cleanup
**Goal**: Users receive clean, well-punctuated Spanish text with filler words removed via Anthropic Haiku API — the complete core product promise delivered end-to-end
**Depends on**: Phase 2
**Requirements**: CLN-01, CLN-02, CLN-03, CLN-04, CLN-05, PRV-02, PRV-03, PRV-04
**Success Criteria** (what must be TRUE):
  1. Pasted text has correct punctuation (periods, commas, question marks), capitalization, and paragraph breaks — raw STT output is never pasted
  2. Spanish filler words ("eh", "este", "o sea", "bueno", "pues") and verbal repetitions are removed from pasted output
  3. The user's original meaning and wording are preserved — Haiku does not paraphrase or add content
  4. Full end-to-end pipeline (record → transcribe → Haiku cleanup → paste) completes within 5 seconds for a typical 30-60 second dictation
  5. User can configure their Anthropic API key in settings and app handles API errors gracefully
**Plans**: 2 plans

Plans:
- [ ] 03-01-PLAN.md — HaikuCleanupService (protocol, actor, error enum) + KeychainService + unit tests
- [ ] 03-02-PLAN.md — API key modal, AppCoordinator integration, AppDelegate wiring, coordinator tests

### Phase 4: Settings, History, and Polish
**Goal**: Users can customize the app to fit their workflow, recover past transcriptions, and the app is ready for distribution
**Depends on**: Phase 3
**Requirements**: VOC-01, VOC-02, OUT-03, OUT-04, MAC-04, MAC-05, REC-05
**Success Criteria** (what must be TRUE):
  1. User can change the recording hotkey from the settings UI and the new hotkey works immediately across all apps
  2. User can select which microphone to use from a list of available audio inputs in settings
  3. User can view the last 10-20 transcriptions in a history panel and copy any entry to the clipboard
  4. User can define custom word corrections (e.g., a brand name the STT consistently misspells) that are applied to every transcription
  5. App consumes less than 200MB RAM when idle (no active recording or processing) — per MAC-05
**Plans**: TBD

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3 → 4

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Foundation | 4/4 | Complete    | 2026-03-16 |
| 2. Audio + Transcription | 3/3 | Complete   | 2026-03-16 |
| 3. Haiku Cleanup | 0/2 | Not started | - |
| 4. Settings, History, and Polish | 0/TBD | Not started | - |
