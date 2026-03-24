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

## Milestone: v1.1 — Pause Playback

**Shipped:** 2026-03-17
**Phases:** 2 | **Plans:** 4 | **Timeline:** 1 day

### What Was Built
- MediaPlaybackService: HID media key simulation via CGEventPost(.cghidEventTap) for system-wide pause/resume
- AppCoordinator FSM integration: pause on idle→recording, resume on recording→processing/escape/error
- Settings toggle "Pausar reproduccion al grabar" with UserDefaults persistence (default ON)
- NSWorkspace.runningApplications guard preventing Music.app cold-launch
- 11 unit tests (7 coordinator mock + 4 service logic) + 14 manual QA scenarios

### What Worked
- Phase 5 CONTEXT.md from discuss-phase was extremely detailed — locked all key decisions (mechanism, timing, delay, error handling) before research even started
- Research confirmed SuperWhisper uses identical approach — high confidence going into planning
- TDD for the NSWorkspace guard (Phase 6 Plan 01) — test-first caught nothing but established confidence
- 2-wave structure (implementation → tests) was clean and efficient for Phase 5
- Checkpoint-based manual QA (Phase 6 Plan 02) worked well — clear pass/fail for each scenario

### What Was Inefficient
- Phase 6 research overlapped heavily with Phase 5 research (same domain, same pitfalls) — could have been skipped
- Music.app guard fix was planned proactively (before confirming the bug) — turned out correct but could have been wasted work
- 3 pre-existing test failures from v1.0 still unresolved (KeychainService, HaikuCleanupService, MenubarController)

### Patterns Established
- NSWorkspace.runningApplications for "is any app of type X running" checks — lightweight, no entitlements needed
- CGEventPost(.cghidEventTap) for system-wide media key events — same tap location as TextInjector
- Manual QA checklist as a plan task with checkpoint — structured way to do human verification in GSD

### Key Lessons
1. discuss-phase with detailed locked decisions produces the highest quality plans — researcher and planner have clear constraints instead of guessing
2. For small milestones (2 phases), research on the verification phase adds limited value — the domain is the same
3. Music.app cold-launch via rcd is a well-known macOS behavior — NSWorkspace guard is the pragmatic fix (not NowPlaying detection)
4. HID media keys work reliably across Spotify, Apple Music, and Safari — browser support is better than expected

### Cost Observations
- Model mix: orchestrator on opus, subagents on sonnet (same as v1.0)
- Phase 5: ~15 min total (2 plans, 5 tasks)
- Phase 6: ~20 min total (2 plans, 3 tasks including manual QA wait)
- Notable: entire milestone completed in a single session

---

## Milestone: v1.3 — Settings UX

**Shipped:** 2026-03-24
**Phases:** 2 | **Plans:** 3 | **Timeline:** 1 day

### What Was Built
- NSPanel reemplazado por NSWindow + NSHostingController para ventana persistente con activation policy lifecycle
- SettingsView expandida a SwiftUI Form con 4 secciones agrupadas (Grabación, API, Vocabulario, Sistema)
- VocabularyEntry con Identifiable para ForEach binding, controles conectados a SettingsViewModel via @Observable

### What Worked
- UI-SPEC como design contract antes de planificación — definió decisiones de diseño (SF Symbols, secciones, controles) sin ambigüedad
- Plan con código inline (paso 1 y paso 2 explícitos) — el executor implementó casi textualmente, mínima desviación
- Checkpoint de verificación visual capturó 2 bugs que el build no detecta (window sizing, exclusive access)

### What Was Inefficient
- Executor removió minHeight del plan pero NSHostingController necesitaba height hint — iteración post-merge para corregir
- sizeThatFits(in: CGFloat.greatestFiniteMagnitude) causó crash — enfoque equivocado antes de la solución simple (minHeight: 400)
- ForEach exclusive access violation es un pitfall conocido de SwiftUI que el plan debería haber anticipado

### Patterns Established
- Task { @MainActor in } para diferir mutaciones de array dentro de ForEach binding — evita exclusive access sin DispatchQueue
- .tag(nil as T?) y .tag(value as T?) para Picker con selection opcional — cast explícito obligatorio
- NSHostingController + .frame(minWidth:, minHeight:) para dimensionamiento correcto de ventanas SwiftUI en NSWindow

### Key Lessons
1. Checkpoints de verificación visual son esenciales para UI — el build no detecta problemas de layout ni de interacción runtime
2. Los planes con código inline reducen desviaciones del executor pero no eliminan pitfalls de runtime (exclusive access, window sizing)
3. NSHostingController necesita hints de tamaño cuando el contenido SwiftUI no tiene dimensiones intrínsecas claras

### Cost Observations
- Model mix: orchestrator on opus, executor on sonnet, verifier on sonnet
- Phase 9: ~15 min (2 plans, 4 tasks)
- Phase 10: ~10 min execution + 15 min post-merge fixes (window sizing + exclusive access)
- Notable: fixes post-merge fueron más caros en contexto que la ejecución original

---

## Cross-Milestone Trends

### Process Evolution

| Milestone | Timeline | Phases | Key Change |
|-----------|----------|--------|------------|
| v1.0 | 2 days | 4 | Initial project — established all patterns |
| v1.1 | 1 day | 2 | First feature addition to shipped product |
| v1.2 | 1 day | 2 | Quality improvements (hallucination, volume) |
| v1.3 | 1 day | 2 | UI migration — SwiftUI + window lifecycle |

### Cumulative Quality

| Milestone | Plans | Requirements | Verification Score |
|-----------|-------|-------------|-------------------|
| v1.0 | 13 | 32/32 | 45/45 must-haves |
| v1.1 | 4 | 6/6 | 11/11 must-haves + 14/14 QA |
| v1.2 | 5 | 9/9 | 39 tests (24 Haiku + 15 Volume) |
| v1.3 | 3 | 11/11 | 5/5 must-haves + human approval |

### Top Lessons (Verified Across Milestones)

1. Hard dependency chains between phases prevent integration surprises
2. Plan verification loops catch structural issues before expensive execution
3. Detailed discuss-phase decisions produce the highest quality downstream plans (confirmed v1.1)
4. Visual checkpoints are essential for UI phases — build success ≠ correct behavior (confirmed v1.3)
