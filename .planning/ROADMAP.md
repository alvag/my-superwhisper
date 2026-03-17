# Roadmap: My SuperWhisper

## Milestones

- ✅ **v1.0 MVP** — Phases 1-4 (shipped 2026-03-16)
- ✅ **v1.1 Pause Playback** — Phases 5-6 (shipped 2026-03-17)
- 🚧 **v1.2 Dictation Quality** — Phases 7-8 (in progress)

## Phases

<details>
<summary>✅ v1.0 MVP (Phases 1-4) — SHIPPED 2026-03-16</summary>

- [x] Phase 1: Foundation (4/4 plans) — completed 2026-03-15
- [x] Phase 2: Audio + Transcription (3/3 plans) — completed 2026-03-16
- [x] Phase 3: Haiku Cleanup (2/2 plans) — completed 2026-03-16
- [x] Phase 4: Settings, History, and Polish (4/4 plans) — completed 2026-03-16

**Total:** 4 phases, 13 plans, 32 requirements satisfied

**Delivered:** Local-first voice-to-text macOS app — press hotkey, speak Spanish, get clean punctuated text at cursor. WhisperKit STT + Haiku API cleanup + configurable settings + history + vocabulary corrections + DMG distribution.

</details>

<details>
<summary>✅ v1.1 Pause Playback (Phases 5-6) — SHIPPED 2026-03-17</summary>

- [x] Phase 5: Pause Playback Implementation (2/2 plans) — completed 2026-03-17
- [x] Phase 6: Integration Verification (2/2 plans) — completed 2026-03-17

**Total:** 2 phases, 4 plans, 6 requirements satisfied

**Delivered:** Auto-pause/resume media playback during recording via HID media keys. Works with Spotify, Apple Music, YouTube/Safari. NSWorkspace guard prevents Music.app cold-launch. Settings toggle with UserDefaults persistence. 14/14 QA scenarios passed.

</details>

### 🚧 v1.2 Dictation Quality (In Progress)

**Milestone Goal:** Improve dictation accuracy and input quality — prevent phantom "gracias" from Haiku cleanup and auto-maximize mic input volume during recording.

- [ ] **Phase 7: Implementation** - Build MicInputVolumeService and add Haiku Rule 6 hallucination guard
- [ ] **Phase 8: Verification** - Validate both features against real speech, hardware, and regression baseline

## Phase Details

### Phase 7: Implementation
**Goal**: Both dictation quality features are coded, wired, and building — mic volume auto-maximizes on record start and restores on every exit, and Haiku never appends hallucinated courtesy phrases
**Depends on**: Phase 6 (v1.1 complete)
**Requirements**: HAIKU-01, HAIKU-02, VOL-01, VOL-02, VOL-03, VOL-04, VOL-05, VOL-06
**Success Criteria** (what must be TRUE):
  1. Recording a voice note causes mic input volume to jump to 1.0 (max) at start and return to its original level when recording stops, is cancelled, or errors out
  2. Haiku system prompt contains a structural Rule 6 prohibiting addition of words absent from the STT input, with "gracias", "de nada", "hasta luego" named as concrete examples
  3. Post-processing strip runs after Haiku response and removes any hallucinated courtesy suffix not present in the raw transcription
  4. On a device where mic input volume is not settable (built-in Mac mic, most USB mics), recording proceeds normally with no error shown to the user
  5. App compiles and runs without regression on normal record/transcribe/paste workflow
**Plans**: 3 plans

Plans:
- [x] 07-01: MicInputVolumeService — CoreAudio read/save/maximize/restore
- [ ] 07-02: AppCoordinator wiring — inject service, call at all 6 exit paths
- [ ] 07-03: HaikuCleanupService Rule 6 + suffix strip

### Phase 8: Verification
**Goal**: Both features are empirically validated against real speech samples and real hardware configurations — hallucination is eliminated, legitimate dictation is preserved, volume control is robust on all exit paths, and v1.1 behavior is unaffected
**Depends on**: Phase 7
**Requirements**: HAIKU-03
**Success Criteria** (what must be TRUE):
  1. 10+ real Spanish transcription samples produce zero hallucinated appended phrases in Haiku output
  2. Transcriptions that legitimately contain "gracias" or "de nada" preserve those words verbatim in the cleaned output
  3. Punctuation, capitalization, filler word removal, and paragraph breaks behave identically to the v1.1 baseline — no regression
  4. Mic volume restore fires correctly when recording is stopped normally, cancelled via Escape, stopped by VAD silence gate, and terminated by a transcription or API error
**Plans**: TBD

Plans:
- [ ] 08-01: Haiku hallucination QA — real samples, regression, legitimate-use preservation
- [ ] 08-02: Volume control QA — all exit paths, non-settable device, device change

## Progress

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 1. Foundation | v1.0 | 4/4 | Complete | 2026-03-15 |
| 2. Audio + Transcription | v1.0 | 3/3 | Complete | 2026-03-16 |
| 3. Haiku Cleanup | v1.0 | 2/2 | Complete | 2026-03-16 |
| 4. Settings, History, and Polish | v1.0 | 4/4 | Complete | 2026-03-16 |
| 5. Pause Playback Implementation | v1.1 | 2/2 | Complete | 2026-03-17 |
| 6. Integration Verification | v1.1 | 2/2 | Complete | 2026-03-17 |
| 7. Implementation | 2/3 | In Progress|  | - |
| 8. Verification | v1.2 | 0/2 | Not started | - |
