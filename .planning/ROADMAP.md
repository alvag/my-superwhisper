# Roadmap: My SuperWhisper

## Milestones

- ✅ **v1.0 MVP** — Phases 1-4 (shipped 2026-03-16)
- **v1.1 Pause Playback** — Phases 5-6 (current)

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

### v1.1 Pause Playback

- [ ] **Phase 5: Pause Playback Implementation** - MediaPlaybackService wired into FSM + Settings toggle
- [ ] **Phase 6: Integration Verification** - Compatibility matrix validated across players and edge cases

## Phase Details

### Phase 5: Pause Playback Implementation
**Goal**: The app automatically pauses and resumes media playback around recordings, with a user-controlled toggle in Settings
**Depends on**: Phase 4 (existing FSM, Settings panel, UserDefaults patterns)
**Requirements**: MEDIA-01, MEDIA-02, MEDIA-03, MEDIA-04, SETT-01, SETT-02
**Success Criteria** (what must be TRUE):
  1. Playing music in Spotify/Apple Music pauses when the user presses the recording hotkey and resumes after transcription completes
  2. Media paused by the app resumes when recording is cancelled via Escape
  3. Media the user had already paused before recording stays paused after recording ends (no double-toggle)
  4. Settings panel shows a "Pausar reproducción al grabar" toggle; when off, no media events are sent during recording
  5. The toggle state persists across app restarts
**Plans**: TBD

### Phase 6: Integration Verification
**Goal**: Pause Playback behavior is confirmed correct across all player and edge-case scenarios before shipping
**Depends on**: Phase 5
**Requirements**: (none — validates Phase 5 requirements)
**Success Criteria** (what must be TRUE):
  1. Spotify, Apple Music, VLC, and YouTube in Safari each pause on recording start and resume on stop
  2. Recording with nothing playing completes without launching Music.app or producing spurious playback events
  3. Rapid double-tap hotkey does not leave media in wrong state (minimum-duration guard holds)
  4. Settings toggle OFF: complete recording cycle against Spotify produces zero pause/resume events
**Plans**: TBD

## Progress

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 1. Foundation | v1.0 | 4/4 | Complete | 2026-03-15 |
| 2. Audio + Transcription | v1.0 | 3/3 | Complete | 2026-03-16 |
| 3. Haiku Cleanup | v1.0 | 2/2 | Complete | 2026-03-16 |
| 4. Settings, History, and Polish | v1.0 | 4/4 | Complete | 2026-03-16 |
| 5. Pause Playback Implementation | v1.1 | 0/? | Not started | - |
| 6. Integration Verification | v1.1 | 0/? | Not started | - |
