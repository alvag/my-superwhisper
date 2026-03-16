# Project Research Summary

**Project:** my-superwhisper — v1.1 Pause Playback
**Domain:** macOS system-wide media playback control integrated into an existing local voice-to-text menubar app
**Researched:** 2026-03-16
**Confidence:** HIGH

## Executive Summary

This research covers the v1.1 milestone for an already-shipped macOS menubar app (my-superwhisper). The core product — local Spanish-optimized voice-to-text with auto-paste — is complete and validated at v1.0. The v1.1 feature is a single, well-scoped addition: automatically pause system media when the user starts recording, and resume it when recording ends. All four research domains converge on the same conclusion: this feature is implemented via HID media key event simulation using `NSEvent.otherEvent` (subtype 8, `NX_KEYTYPE_PLAY`) posted via `CGEventPost(.cghidEventTap)` — the identical mechanism used by BackgroundMusic, BeardedSpice, and SuperWhisper itself since v1.44.0 (January 2025, made default in v2.7.0 November 2025).

The recommended implementation is a new `MediaPlaybackService` (~60 lines of Swift) injected into the existing `AppCoordinator` FSM as side effects at state transitions. No new SPM dependencies, no new entitlements, no new permissions are required. The app is already non-sandboxed and already uses `CGEventPost` for paste simulation in `TextInjector.swift` — the media key variant is structurally identical. The entire implementation surface is one new file and three modified files, plus one new Settings checkbox.

The key risk is the double-toggle problem: if the user had media paused before starting a recording, the recording-stop event will erroneously resume it. The pragmatic v1.1 mitigation is a `pausedByApp` flag combined with a user-facing Settings toggle (on by default) and a documented limitation. The technically correct solution — querying whether media was playing before pausing — is blocked on macOS 15.4+ by Apple's entitlement gate on `MediaRemote.framework`. This is acceptable for v1.1; per-app AppleScript targeting is the right escalation path for v1.2 if user reports warrant it.

## Key Findings

### Recommended Stack

The v1.1 feature requires no new frameworks or packages. All needed APIs are already imported by the project: `AppKit` (NSEvent), `CoreGraphics` (CGEvent, already used in `TextInjector.swift`), and `IOKit.hidsystem` (header-only import for the `NX_KEYTYPE_PLAY = 16` constant). The HID media key pattern has been stable since macOS 10.6 and works on all versions through macOS Sequoia (15.x).

The critical stack decision is what NOT to use. `MediaRemote.framework` — the most commonly referenced approach for media control — is broken for third-party apps on macOS 15.4+. Apple added entitlement verification inside `mediaremoted`; any app without `com.apple.mediaremote` (Apple-only, unavailable to third parties) is silently denied. `MPRemoteCommandCenter` controls only the app's own audio session, not other apps. Third-party interceptor libraries (`SPMediaKeyTap`, `MediaKeyTap`) receive incoming media keys; they do not send them.

**Core technologies:**
- `NSEvent.otherEvent(with: .systemDefined, subtype: 8)` — constructs a synthetic HID auxiliary key event targeting `NX_KEYTYPE_PLAY`; the only public mechanism for sending a system-wide play/pause command
- `CGEvent.post(tap: .cghidEventTap)` — delivers the event to the macOS HID event stream; same tap used by `TextInjector.swift` for paste simulation; no new entitlements needed
- `IOKit.hidsystem` (header-only) — provides the stable `NX_KEYTYPE_PLAY = 16` constant; zero linkage change required in Swift

### Expected Features

The v1.1 scope is tightly defined. V1.0 shipped all table-stakes features for the voice-to-text product. V1.1 adds one high-value behavioral feature that SuperWhisper first shipped in v1.44.0 and made default in v2.7.0 — confirming it is now a table-stakes expectation for the category.

**Must have (table stakes for v1.1):**
- Pause active media player on recording start — users expect SuperWhisper parity
- Resume media when recording ends, after pipeline completes (not at stop-hotkey press — resuming during 3-5s transcription is jarring)
- Resume media when recording is cancelled via Escape — user abandoned the recording; media should come back
- Settings toggle, on by default — feature is disruptive to users who do not want it

**Should have (v1.1 polish):**
- `pausedByApp` flag guard: only resume if the app was responsible for pausing — prevents double-toggle edge case
- 150-200ms delay between pause command and `AVAudioEngine.start()` — prevents Spotify fade audio bleeding into recording buffer, degrading first-word transcription accuracy
- Minimum recording duration guard (500ms) — prevents rapid double-tap from generating spurious pause/resume pairs

**Defer (v2+):**
- Per-app AppleScript targeting (Spotify, Apple Music) — required only if toggle semantics generate sustained user complaints
- Push-to-talk mode media pause — short hold-to-talk recordings make the media round-trip marginal
- Reformulation modes, multi-language support — orthogonal to this milestone

### Architecture Approach

The implementation follows the FSM side-effect injection pattern already established in the codebase. A new `MediaPlaybackService` encapsulates all CGEvent logic behind a `MediaPlaybackServiceProtocol`, injected into `AppCoordinator` by `AppDelegate` at startup. The coordinator calls `mediaPlayback?.pause()` at the `idle → recording` transition and `mediaPlayback?.resume()` at both `recording → processing` (normal stop) and in `handleEscape()` (cancel). `SettingsWindowController` adds a checkbox that writes directly to `UserDefaults` — `MediaPlaybackService` reads the key at call time, requiring zero coupling between the Settings UI and the service.

**Major components:**
1. `MediaPlaybackService` (new, `MyWhisper/System/MediaPlaybackService.swift`) — all media key logic; reads `UserDefaults["pausePlaybackEnabled"]`; posts `NX_KEYTYPE_PLAY` key-down + key-up via `CGEventPost`
2. `AppCoordinator` (modified) — adds `mediaPlayback` property and three call sites: pause on `idle → recording`, resume on `recording → *`, resume on Escape cancel
3. `SettingsWindowController` (modified) — adds "Pausar reproducción al grabar" NSButton checkbox as Section 6; persists to UserDefaults; no new dependency injection required
4. `AppDelegate` (modified) — instantiates `MediaPlaybackService` and assigns it to `coordinator.mediaPlayback`
5. `AppCoordinatorDependencies` (modified) — declares `MediaPlaybackServiceProtocol` for unit test mocking

Build order: protocol first (Step 1), then service (Step 2) and coordinator call sites (Step 3) in parallel, then AppDelegate wiring (Step 4, depends on 2+3), then Settings UI (Step 5, independent), then unit tests (Step 6).

### Critical Pitfalls

1. **MediaRemote private framework broken on macOS 15.4+** — Do not use `dlopen`/`dlsym` against `MediaRemote.framework`. Apple added entitlement verification in `mediaremoted` with 15.4; third-party apps are silently denied. The failure is invisible — function calls succeed but return empty data. Use `CGEventPost` with `NX_KEYTYPE_PLAY` from the start, not as a fallback.

2. **Audio engine start / pause race (music bleeds into recording)** — Spotify's pause has a 100-200ms fade. If `AVAudioEngine.start()` fires immediately after the pause command, fading music audio enters the recording buffer and degrades first-word accuracy. Always send pause before engine start and add a 150-200ms `Task.sleep` before calling `AVAudioEngine.start()`.

3. **Double-toggle: resuming media the user had intentionally paused** — The toggle-based approach (pause on start, resume on stop) is wrong when the user had already paused media before recording. Track `pausedByApp: Bool`; only send resume if the flag is `true`. For v1.1, accept that reliable "is something currently playing?" detection is not possible on macOS 15.4+; the flag prevents double-resume even if it cannot prevent false-pause.

4. **Media key routed to wrong app** — macOS routes media keys to whichever app holds the Now Playing token — not necessarily the player the user expects (browsers compete aggressively for this token). Accept as a known limitation and document it next to the Settings toggle. Per-app targeting is v1.2+ scope.

5. **FSM state corruption on rapid double-tap** — Fast double-press sends pause then immediately resume before the media player processes the first event. The existing FSM guards `processing` state; extend with a minimum recording duration (500ms) and ensure resume fires only after pipeline completion, not immediately after engine stop.

## Implications for Roadmap

This is a compact, two-phase milestone with a natural gate between implementation and integration testing.

### Phase 1: Core Implementation

**Rationale:** All logic is internal to the app. Dependencies are deterministic and fully specified in ARCHITECTURE.md. No external unknowns block implementation. The Settings UI is the only unit that can be built independently of the service wiring.

**Delivers:** Working pause/resume cycle wired into the recording FSM; Settings toggle that persists across restarts; all pitfall mitigations built in from day one (flag guard, pause-before-engine-start delay, minimum duration guard).

**Addresses:** Pause on recording start, resume on normal stop, resume on Escape cancel, `pausedByApp` flag, 150ms delay, Settings checkbox, UserDefaults persistence.

**Avoids:** MediaRemote (never introduced), audio bleed (delay built in), double-resume (flag built in from the start, not retrofitted), FSM corruption (minimum-duration guard extended in this phase).

Build sequence:
1. `AppCoordinatorDependencies.swift` — add `MediaPlaybackServiceProtocol`
2. `MediaPlaybackService.swift` (new file) — service conforming to protocol
3. `AppCoordinator.swift` — add property + 3 call sites
4. `AppDelegate.swift` — instantiate and wire service (depends on 2 and 3)
5. `SettingsWindowController.swift` — add checkbox (independent of 2-4)
6. Unit tests — mock protocol; verify pause/resume call sites and toggle-off guard

### Phase 2: Integration Testing and Verification

**Rationale:** The media key routing behavior depends on macOS system state (which app holds Now Playing focus). Functional correctness cannot be verified by unit tests alone. A dedicated test pass against a compatibility matrix is required before shipping.

**Delivers:** Verified behavior across the four key player scenarios; documented limitations in Settings UI; confidence the feature ships without regressions; the 12-item "Looks Done But Isn't" checklist from PITFALLS.md fully passed.

**Test matrix:** Spotify native app, Apple Music, YouTube/Safari, YouTube/Chrome, nothing playing, user-manually-paused Spotify before recording, Settings toggle OFF, rapid double-tap hotkey, recording cancelled via Escape, recording ending normally, app restart (Settings persistence).

### Phase Ordering Rationale

- Phase 1 must precede Phase 2 — nothing to test until implementation exists.
- The Settings UI (Step 5 in Phase 1) can be built in parallel with Steps 2-4 but must be complete before Phase 2 (the toggle-off test path requires it).
- Unit tests (Step 6) are the Phase 1 → Phase 2 gate: if coordinator call-site tests pass, the remaining risk is external system behavior, which is what Phase 2 covers.

### Research Flags

Phases with standard patterns — no additional research needed before implementation:
- **Phase 1:** Implementation is fully specified. Exact Swift code is provided in STACK.md and ARCHITECTURE.md. The HID media key pattern is 15+ years documented. Existing codebase is already read. Build directly from the spec.
- **Phase 2:** Test matrix is fully defined in PITFALLS.md checklist. Execute the checklist; no upfront research required.

No phases in this milestone require a `/gsd:research-phase` call. The research files contain sufficient detail to implement directly.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | HID media key pattern in continuous production use since macOS 10.6; independently confirmed by BackgroundMusic (open source), BeardedSpice (open source), and SuperWhisper (production app); existing codebase confirms `CGEventPost` already works without new entitlements |
| Features | HIGH | SuperWhisper changelog confirms this exact feature at specific version dates; competitor analysis comprehensive; v1.1 scope is tightly bounded with no ambiguous requirements |
| Architecture | HIGH | Existing codebase read directly; component boundaries are explicit; full implementation code drafted in ARCHITECTURE.md; no architectural unknowns remain |
| Pitfalls | HIGH (implementation pitfalls), MEDIUM (browser compat specifics) | MediaRemote breakage verified via multiple developer reports and community tracking; CGEvent approach confirmed by production codebase; browser-specific behavior varies by macOS and browser version — needs empirical validation in Phase 2 |

**Overall confidence:** HIGH

### Gaps to Address

- **False-pause when nothing is playing** — Sending a play/pause event when nothing is active may silently no-op, or on some configurations launch Music.app. No clean public API exists to pre-check playback state on macOS 15.4+. Validate empirically during Phase 2 integration testing. If Music.app launches, add a guard (AppleScript `tell application "Music" to player state` is the most reliable available check for the Music-app-launch case specifically).

- **Browser media resume reliability** — YouTube/Chrome resume via media key is documented as potentially unreliable in PITFALLS.md (Chrome's Web Media Session implementation sometimes requires tab focus for resume). Confirm during Phase 2. If confirmed unreliable, add a Settings UI caveat: "Works best with native media apps. Browser-based players may require manual resume."

- **Bluetooth SCO profile switching** — A separate macOS/hardware behavior: mic activation forces Bluetooth headphones to SCO profile, degrading audio quality. Not fixable in app code. Document in the Settings tooltip next to the Pause Playback toggle during Phase 1 implementation.

## Sources

### Primary (HIGH confidence)
- Existing codebase (`TextInjector.swift`, `AppCoordinator.swift`, `AppDelegate.swift`) — read directly; confirms `CGEventPost` usage, FSM structure, component boundaries
- [Rogue Amoeba: Apple Keyboard Media Key Event Handling (2007)](https://weblog.rogueamoeba.com/2007/09/29/apple-keyboard-media-key-event-handling/) — NSEvent systemDefined subtype 8 pattern; technique confirmed in continuous production use
- [Apple Developer Docs: MPRemoteCommandCenter](https://developer.apple.com/documentation/mediaplayer/mpremotecommandcenter) — confirmed incoming command handler for own app only, not an outgoing sender
- [BackgroundMusic source (kyleneideck)](https://github.com/kyleneideck/BackgroundMusic) — open source; confirms media key posting as system-wide approach; AppleScript as per-app fallback
- [SuperWhisper changelog](https://superwhisper.com/changelog) — Pause media added v1.44.0 (Jan 2025), refined v2.2.4 (Aug 2025), default in v2.7.0 (Nov 2025)
- [CGEvent Taps and Code Signing: The Silent Disable Race — Daniel Raffel (2026-02-19)](https://danielraffel.me/til/2026/02/19/cgevent-taps-and-code-signing-the-silent-disable-race/) — CGEvent tap silent disable after re-signing

### Secondary (MEDIUM confidence)
- [MediaRemote breakage on macOS 15.4 — feedback-assistant/reports #637](https://github.com/feedback-assistant/reports/issues/637) — community-tracked breakage with multiple independent confirmations
- [ungive/mediaremote-adapter](https://github.com/ungive/mediaremote-adapter) — Perl adapter workaround; confirms scope of entitlement restriction and why it is not a viable path
- [Apple Developer Forums: Play/Pause Now Playing with MediaRemote (thread/688433)](https://developer.apple.com/forums/thread/688433) — developer discussion confirming MediaRemote restrictions
- [Qiita: macOS media key emulation in Swift](https://qiita.com/nak435/items/53d952147c3986afd7fc) — Swift implementation cross-reference
- [AutoPause HN thread](https://news.ycombinator.com/item?id=44823938) — Bluetooth SCO side effect; browser media key behavior notes

### Tertiary (for reference)
- [SuperWhisper on X re: pause music (2025)](https://x.com/superwhisperapp/status/1963687889193095282) — confirmed behavior in production
- [mpv-player/mpv Issue #4834](https://github.com/mpv-player/mpv/issues/4834) — Now Playing token contention between media apps

---
*Research completed: 2026-03-16*
*Ready for roadmap: yes*
