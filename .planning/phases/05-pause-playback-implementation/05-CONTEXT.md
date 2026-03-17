# Phase 5: Pause Playback Implementation - Context

**Gathered:** 2026-03-16
**Status:** Ready for planning

<domain>
## Phase Boundary

Auto-pause media playback when recording starts and auto-resume when recording stops, with a configurable toggle in Settings. Covers system and third-party media apps (Spotify, Apple Music, VLC, browsers). No per-app control, no NowPlaying detection — single universal media key simulation.

</domain>

<decisions>
## Implementation Decisions

### Media Control Mechanism
- Use `NSEvent.otherEvent(with: .systemDefined, subtype: 8)` + `CGEventPost(.cghidEventTap)` with `NX_KEYTYPE_PLAY` (keyCode 16)
- Same CGEventPost mechanism already used in `TextInjector.swift` for Cmd+V simulation
- Do NOT use MediaRemote.framework — broken on macOS 15.4+ (Apple added entitlement verification)
- Do NOT use AppleScript per-app approach — too narrow, misses browsers

### Resume Timing
- Resume media immediately when recording stops (transition from recording state), NOT after transcription/paste completes
- User prefers hearing audio resume while processing happens in background (~3-5s)
- This means resume happens at the `recording→processing` transition in AppCoordinator

### State Tracking
- Track `pausedByApp: Bool` flag — only resume if the app was responsible for pausing
- Prevents double-toggle when user had media manually paused before recording
- Flag resets on resume or on cancel (Escape)

### Delay
- 150ms delay between sending pause event and starting AVAudioEngine
- Spotify fade-out takes 100-200ms; without delay, fading audio bleeds into recording buffer

### Settings Toggle
- Single checkbox/toggle: "Pausar reproduccion al grabar"
- Default: ENABLED (activado por defecto)
- Persist in UserDefaults — follows existing pattern from Phase 4
- Placement: in existing Settings panel (SettingsWindowController)

### Error Handling
- Always resume media on any error (transcription failure, API failure, etc.)
- User should never be left without music because of an app error
- Resume on Escape cancel as well

### Edge Cases
- Double-tap rapid hotkey: treat as normal pause/resume cycle, no minimum duration guard
- No attempt to detect if media is actually playing before sending pause — accept toggle semantics

### Claude's Discretion
- Exact protocol name and file organization for MediaPlaybackService
- Whether to use a protocol or concrete class (existing pattern uses protocols)
- Exact placement of toggle within Settings panel layout
- Label wording for the Settings toggle

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project Context
- `.planning/PROJECT.md` — Vision, constraints (local STT, Apple Silicon, non-sandboxed)
- `.planning/REQUIREMENTS.md` — MEDIA-01..04, SETT-01..02 requirements for this phase
- `.planning/ROADMAP.md` — Phase 5 success criteria

### Research (v1.1)
- `.planning/research/STACK.md` — CGEventPost media key mechanism, implementation code pattern
- `.planning/research/ARCHITECTURE.md` — Integration points with AppCoordinator FSM, component design
- `.planning/research/PITFALLS.md` — MediaRemote breakage, delay requirement, edge cases
- `.planning/research/SUMMARY.md` — Executive summary of all research

### Prior Phase Context
- `.planning/phases/04-settings-history-and-polish/04-CONTEXT.md` — Settings panel design, UserDefaults patterns

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `TextInjector.swift` — CGEventPost pattern with CGEventSource(.hidSystemState). MediaPlaybackService will use identical posting mechanism
- `SettingsWindowController` — Existing Settings panel where toggle will be added
- `NotificationHelper.swift` — macOS notifications (if needed for edge cases)
- `VocabularyService` — Example of simple service with UserDefaults persistence and protocol-based DI

### Established Patterns
- Protocol-based DI: `AudioRecorderProtocol`, `STTEngineProtocol`, `HaikuCleanupProtocol` — new service follows same pattern
- `@Observable` + `@MainActor` on AppCoordinator — state updates are reactive
- UserDefaults for simple persistence — toggle follows same pattern as other settings
- Weak references in AppCoordinator to avoid retain cycles

### Integration Points
- `AppCoordinator.handleHotkey()` line 53-58 — pause media before `audioRecorder?.start()`, after 150ms delay
- `AppCoordinator.handleHotkey()` line 64-67 — resume media at recording→processing transition (when user presses hotkey second time)
- `AppCoordinator.handleEscape()` — resume media on cancel
- `AppCoordinator` error paths (lines 141-148) — resume media on transcription failure
- `AppCoordinatorDependencies.swift` — wire new service
- `AppDelegate.applicationDidFinishLaunching` — instantiate MediaPlaybackService
- `SettingsWindowController` — add toggle checkbox

</code_context>

<specifics>
## Specific Ideas

- Same CGEventPost mechanism as TextInjector — proven pattern, no new frameworks needed
- Research confirmed SuperWhisper uses identical approach (shipped v1.44.0, Jan 2025)
- Total implementation: ~1 new file, 3-4 modified files, <100 lines of production code

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 05-pause-playback-implementation*
*Context gathered: 2026-03-16*
