# Phase 7: Implementation - Context

**Gathered:** 2026-03-17
**Status:** Ready for planning

<domain>
## Phase Boundary

Both dictation quality features coded, wired, and building: (1) Haiku never appends hallucinated courtesy phrases — dual-layer defense via Rule 6 in prompt + post-processing suffix strip, (2) mic input volume auto-maximizes on recording start and restores on every exit path. Includes settings toggle for volume feature.

</domain>

<decisions>
## Implementation Decisions

### Suffix strip logic
- Compare Haiku output against raw STT text to detect hallucinated additions
- If a phrase appears at the END of Haiku output but is NOT present in raw WhisperKit text, strip it
- Only strip "gracias" for now — the only confirmed hallucination pattern
- Legitimate "gracias" (present in raw STT) is preserved verbatim
- Strip runs AFTER Haiku response, BEFORE vocabulary corrections

### Volume toggle
- Add settings toggle "Maximizar volumen al grabar" (default: ON) — follows same pattern as "Pausar reproduccion al grabar"
- UserDefaults key, persisted, checked by MicInputVolumeService.isEnabled
- When toggle is OFF, volume service is a no-op (same pattern as MediaPlaybackService)
- This adds requirement VOL-06 to the milestone

### Prompt Rule 6 design
- Broad structural rule + specific examples
- Framing: "El texto viene de reconocimiento de voz (STT) y puede terminar abruptamente. NO completes ni agregues palabras de cortesía al final (gracias, de nada, hasta luego). Si la oración termina abruptamente, termínala igual."
- Appended as Rule 6 to existing numbered list in systemPrompt
- Works in conjunction with suffix strip as dual-layer defense

### Claude's Discretion
- Exact system prompt wording for Rule 6 (within the structural + examples constraint above)
- MicInputVolumeService internal implementation (CoreAudio HAL calls, error handling)
- Volume maximize/restore call placement relative to engine start (research suggests after engine.start(), but verify)
- Test strategy for both features

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Haiku cleanup
- `.planning/research/STACK.md` — Haiku prompt engineering pattern for preventing hallucinated additions
- `.planning/research/FEATURES.md` — Dual-layer defense rationale (prompt + post-processing), Whisper hallucination sources
- `.planning/phases/03-haiku-cleanup/03-CONTEXT.md` — Original Haiku prompt design decisions, fallback philosophy

### Volume control
- `.planning/research/STACK.md` — CoreAudio HAL API pattern: `kAudioDevicePropertyVolumeScalar` + `ScopeInput` + `AudioObjectIsPropertySettable`
- `.planning/research/ARCHITECTURE.md` — Integration points, build order, device resolution approach
- `.planning/research/PITFALLS.md` — 6 exit paths for volume restore, device settability caveat, `defer` trap in async

### Project
- `.planning/PROJECT.md` — Core value, constraints, key decisions
- `.planning/REQUIREMENTS.md` — HAIKU-01/02, VOL-01/02/03/04/05 + new VOL-06

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `HaikuCleanupService.swift:19-31` — existing systemPrompt with 5 rules. Rule 6 appends to this string
- `MicrophoneDeviceService.swift` — CoreAudio HAL pattern with `AudioObjectGetPropertyData`, `AudioObjectPropertyAddress`. Same API family for volume read/write
- `MediaPlaybackService.swift` — isEnabled pattern with UserDefaults toggle, pausedByApp state tracking. Volume service mirrors this design
- `AppCoordinator.swift:54-68` — media pause integration point. Volume maximize inserts at same location (after pause, before engine start)

### Established Patterns
- Protocol-based DI: `MediaPlaybackServiceProtocol`, `HaikuCleanupProtocol` — new `MicInputVolumeServiceProtocol` follows same
- `UserDefaults.register(defaults:)` in AppDelegate for default values (pausePlaybackEnabled pattern)
- All services injected into AppCoordinator as optional properties, nil-safe

### Integration Points
- `AppCoordinator.handleHotkey()` line 54: volume maximize goes after `mediaPlayback?.pause()` + 150ms delay, before `audioRecorder?.start()`
- `AppCoordinator.handleHotkey()` line 73: volume restore goes alongside `mediaPlayback?.resume()` at recording→processing transition
- `AppCoordinator.handleEscape()` line 175: volume restore on cancel path
- `AppCoordinator.handleHotkey()` line 61: volume restore on start failure path
- `HaikuCleanupService.clean()` return value: suffix strip wraps around this call in AppCoordinator
- `SettingsWindowController` — add toggle row for volume feature

</code_context>

<specifics>
## Specific Ideas

- El problema de "gracias" es frecuente — el usuario lo nota en uso diario. Fix es prioridad.
- Solo "gracias" confirmado como hallucination — no over-engineer el strip para frases no confirmadas
- Toggle de volumen sigue el mismo patrón UX que el toggle de pausa de playback — consistencia en Settings

</specifics>

<deferred>
## Deferred Ideas

- VOL-06 (toggle setting) was added to scope during discussion — update REQUIREMENTS.md and ROADMAP.md
- Expandir suffix strip a más frases si aparecen nuevos patterns de hallucination — futuro

</deferred>

---

*Phase: 07-implementation*
*Context gathered: 2026-03-17*
