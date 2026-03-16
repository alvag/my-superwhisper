# Project Retrospective

*A living document updated after each milestone. Lessons feed forward into future planning.*

## Milestone: v1.0 — MVP

**Shipped:** 2026-03-16
**Phases:** 4 | **Plans:** 13 | **Timeline:** 2 days

### What Was Built
- macOS menubar app with FSM-based state management, global hotkey, permission handling
- Real-time audio capture (AVAudioEngine) with WhisperKit local STT for Spanish
- Anthropic Haiku API text cleanup — punctuation, filler removal, meaning preservation
- Settings panel (hotkey recorder, mic selector, API key, vocabulary, launch-at-login)
- Transcription history (last 20, click-to-copy) and vocabulary corrections
- Distribution pipeline (DMG, Developer ID signing, Apple notarization)

### What Worked
- Hard dependency chain (foundation → audio → STT → cleanup → settings) prevented integration issues
- Protocol-based DI pattern (AudioRecorderProtocol, HaikuCleanupProtocol, etc.) enabled clean testing and gradual implementation
- TDD for services in Phase 4 caught issues early (VocabularyService, TranscriptionHistoryService)
- Plan checker verification loop caught 4 blockers before execution (missing DMG task, test coverage gaps)
- Graceful fallback philosophy ("el usuario siempre recibe texto") simplified error handling

### What Was Inefficient
- Phase 3 roadmap checkbox not marked complete despite all plans having SUMMARYs — manual status tracking drift
- VALIDATION.md created from template but never formally signed off (nyquist_compliant: false for all phases)
- Some Phase 4 plan tasks had `<acceptance_criteria>` instead of `<done>` — inconsistent schema across plans
- 3 pre-existing test failures (KeychainService, HaikuCleanupService, TextInjector) carried through without resolution

### Patterns Established
- NSPanel + NSApp.setActivationPolicy lifecycle for auxiliary windows (APIKeyWindowController → SettingsWindowController → HistoryWindowController)
- nonisolated(unsafe) for single Float values bridging audio thread to main thread
- UserDefaults for simple persistence (settings, history, vocabulary) — consistent across Phase 4
- CoreAudio AudioUnitSetProperty for mic device selection before AVAudioEngine.start()
- KeyboardShortcuts library (sindresorhus) for configurable hotkeys with RecorderCocoa widget

### Key Lessons
1. Plan checker verification is high-value — caught missing distribution task that would have been discovered late in execution
2. WhisperKit CoreML model memory is managed by Neural Engine on Apple Silicon, not process RSS — idle RAM is much lower than disk model size suggests
3. Non-sandboxed distribution (Developer ID) is required for CGEventPost — this constraint should be validated at project start, not discovered during research
4. 150ms delay between clipboard write and CGEventPost prevents race condition where target app reads stale clipboard

### Cost Observations
- Model mix: orchestrator on opus, subagents (researcher, planner, checker, executor, verifier) on sonnet
- Phases executed in ~10-15 min each (plans 2-3 tasks, 5-12 files)
- Notable: parallel Wave 3 execution (04-03 + 04-04) saved time on the final wave

---

## Cross-Milestone Trends

### Process Evolution

| Milestone | Timeline | Phases | Key Change |
|-----------|----------|--------|------------|
| v1.0 | 2 days | 4 | Initial project — established all patterns |

### Cumulative Quality

| Milestone | Plans | Requirements | Verification Score |
|-----------|-------|-------------|-------------------|
| v1.0 | 13 | 32/32 | 45/45 must-haves |

### Top Lessons (Verified Across Milestones)

1. Hard dependency chains between phases prevent integration surprises
2. Plan verification loops catch structural issues before expensive execution
