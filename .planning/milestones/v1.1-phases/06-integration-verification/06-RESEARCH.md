# Phase 6: Integration Verification - Research

**Researched:** 2026-03-17
**Domain:** macOS media key behavior verification, Music.app launch mechanics, HID event routing
**Confidence:** HIGH (behavior documented) / MEDIUM (exact Music.app conditions) / LOW (double-tap OS debounce)

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Test Methodology**
- Manual checklist in PLAN.md — user executes step-by-step and marks results
- Checklist queda como evidencia de QA reutilizable para v1.1
- No scripts semi-automatizados ni AppleScript — verificación humana directa
- App ya compilada y corriendo — no incluir build step en la fase

**Player Coverage (Obligatorios)**
- Spotify — reproductor principal del usuario, HID media keys confirmados
- Apple Music — app nativa macOS, riesgo de lanzamiento espontáneo
- YouTube en Safari — navegador nativo con media keys activos
- VLC excluido de la matriz obligatoria
- Chrome/Firefox excluidos — documentar como "debería funcionar" sin test formal

**Music.app Launch Issue — CRITICO**
- Si Music.app se lanza sola al enviar pause sin nada reproduciendo, es un bug que debe resolverse antes de enviar
- Investigar si hay forma de detectar playback activo antes de enviar pause key
- Si se puede detectar: no enviar pause cuando nada suena
- Si macOS no ofrece API: este punto necesita re-evaluación (¿desactivar por defecto? ¿aceptar como limitación?)
- Nota: Phase 5 decidió "no detectar si algo suena" — esta fase puede cambiar esa decisión si Music.app launch es reproducible

**Manejo de Incompatibilidades**
- Documentar como limitación en VERIFICATION.md (no archivo separado)
- No bloquea release — solo documenta comportamiento observado
- Excepción: Music.app launch SÍ bloquea release (marcado como crítico)

**Success Criteria Alignment**
- Criterio #3 del roadmap dice "minimum-duration guard holds" pero Phase 5 decidió no usar guard
- El criterio real es: "rapid double-tap no deja media en estado incorrecto" — verificar empíricamente sin guard

### Claude's Discretion
- Formato exacto de la tabla de resultados en VERIFICATION.md
- Orden de los escenarios en el checklist
- Si incluir screenshots o logs como evidencia

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope
</user_constraints>

---

## Summary

Phase 6 is a human-executed verification phase, not an implementation phase. Its primary deliverable is a manual checklist the user runs against the live app and a VERIFICATION.md that captures results. There is no new production code unless the Music.app launch issue proves reproducible and fixable.

The critical research question is the Music.app launch issue: **does macOS launch Music.app when a HID play/pause event is sent with no active Now Playing session?** Research confirms this is well-documented, reproducible, intentional Apple behavior — `rcd` (the Remote Control Daemon) launches Music.app when it receives a play key and no app owns a Now Playing session. The fix options are (a) detect an active player before sending the key using `NSWorkspace.runningApplications`, (b) intercept the rcd-routed event via CGEventTap at `.cghidEventTap` before rcd acts, or (c) document as a known limitation. Option (a) is technically feasible with the existing stack but is a scoped code change in `MediaPlaybackService.pause()`.

The double-tap scenario does not involve OS-level debounce — the OS does not debounce synthetic `CGEventPost` media key events. The `pausedByApp` flag in `MediaPlaybackService` is the sole safeguard against state corruption on rapid re-entry.

**Primary recommendation:** Verify Music.app launch empirically first. If confirmed, implement the `NSWorkspace.runningApplications` guard in `MediaPlaybackService.pause()` before writing the checklist. If not confirmed on the test machine, document as "environment-dependent" and ship.

---

## The Music.app Launch Issue — Deep Investigation

### Root Cause (HIGH confidence)

The macOS Remote Control Daemon (`rcd`, at `/System/Library/LaunchAgents/com.apple.rcd.plist`) handles all media key events from the HID layer. Its routing logic:

1. If an app currently owns a Now Playing session (has active `MPNowPlayingInfoCenter` registration and is playing) → route the event to that app.
2. If no app owns a Now Playing session → launch Music.app and send the event to it.

This is **intentional Apple design**, not a bug. It is well-documented in community reports across macOS 12–15. The behavior is consistent: pressing play when nothing is playing launches Music.app.

**Exact trigger condition for MyWhisper:** The user is not playing anything (Spotify not running, or paused, or playing but no longer the Now Playing owner). User presses the recording hotkey. `MediaPlaybackService.pause()` sends `NX_KEYTYPE_PLAY`. `rcd` sees no active session. Music.app launches.

**This is reproducible and confirmed.** Multiple Apple Community threads (2024–2025) confirm it affects macOS Sequoia. SuperWhisper v1.44.1 (January 2025) specifically shipped media pause as a feature, indicating they ship despite this known behavior — or they handle it differently.

### Why Phase 5 Did Not Guard Against This

Phase 5 research (PITFALL 3) noted: "The app cannot detect whether media was playing without the broken MediaRemote API. The toggle semantics accept this trade-off." The `pausedByApp` flag was designed to prevent double-resume, not to prevent the initial spurious pause.

The Phase 6 CONTEXT.md now overrides this: if Music.app launch is reproducible, it blocks release.

### Detection Options (Without MediaRemote)

**Option A: NSWorkspace.runningApplications check (RECOMMENDED)**

Check if a known media app is running before sending the pause key. If no media app is running, skip the pause. This is a coarse but practical guard.

```swift
// In MediaPlaybackService.pause() — guard before postMediaKeyToggle()
private func isKnownMediaAppRunning() -> Bool {
    let mediaAppBundleIDs = Set([
        "com.spotify.client",
        "com.apple.Music",
        "org.videolan.vlc",
        "com.google.Chrome",
        "com.apple.Safari",
        "org.mozilla.firefox"
    ])
    return NSWorkspace.shared.runningApplications
        .contains { app in
            guard let bid = app.bundleIdentifier else { return false }
            return mediaAppBundleIDs.contains(bid)
        }
}
```

**Limitation:** This check is "is the app running?" not "is the app playing?". Spotify may be running but paused. The `pausedByApp` flag is still needed for that case (the flag prevents double-resume; if Spotify is paused and we skip sending the key because it's running, we don't pause Spotify at all).

**Corrected approach:** The guard should specifically be "is any media app running?" and if NO → skip sending the pause key AND set `pausedByApp = false`. If YES → send the key (toggle semantics apply; if Spotify is already paused, the key unpauses it, which is wrong, but this is the existing accepted trade-off).

Actually, the critical path to fix is narrower: **if Music.app is NOT running AND no other media app is running, skip the key entirely**. This prevents the Music.app cold-launch case while still working when Spotify or Safari is running.

**Revised minimal guard:**
```swift
func pause() {
    guard isEnabled else { return }
    guard isAnyMediaAppRunning() else {
        // Nothing is playing — skip sending key to avoid launching Music.app
        // Don't set pausedByApp (nothing to resume)
        return
    }
    postMediaKeyToggle()
    pausedByApp = true
}

private func isAnyMediaAppRunning() -> Bool {
    let mediaApps = ["com.spotify.client", "com.apple.Music",
                     "org.videolan.vlc", "com.apple.Safari",
                     "com.google.Chrome", "org.mozilla.firefox"]
    return NSWorkspace.shared.runningApplications
        .compactMap(\.bundleIdentifier)
        .contains { mediaApps.contains($0) }
}
```

**Confidence:** MEDIUM — `NSWorkspace.runningApplications` is a stable public API. The bundle IDs are known. The logic is correct for the stated goal (prevent Music.app cold launch). It does NOT solve the case where Music.app is already running but not playing — but in that case, pressing play is harmless (it would resume where Music left off, or do nothing if the library is empty).

**Option B: CGEventTap intercept (NOT RECOMMENDED for this phase)**

Create a `CGEventTapCreate(.cghidEventTap, .headInsertEventTap, ...)` to intercept media key events and consume them before `rcd` processes them. This would allow the app to decide whether to pass through or swallow the key. But this requires the Input Monitoring permission (Accessibility is already granted, but Input Monitoring is a separate TCC entry the user must approve). This is a significantly larger change and introduces a new permission requirement. Out of scope for a verification phase.

**Option C: noTunes-style NSWorkspace notification (NOT RECOMMENDED)**

Projects like noTunes register for `NSWorkspace.didLaunchApplicationNotification` and call `NSRunningApplication.terminate()` on Music.app immediately after it launches. This terminates Music.app after it has already launched (a brief flash). It is reactive, not preventive. It also terminates the user's Music.app if they launched it intentionally. Not appropriate.

**Option D: launchctl disable rcd (NOT RECOMMENDED)**

Disabling `com.apple.rcd` via `launchctl unload -w` prevents Music.app from launching on media key presses but also disables all media key routing to any app. This is a system-wide change that breaks normal media key functionality. Never appropriate for a third-party app to do to a user's system.

**Option E: Accept as documented limitation (fallback)**

If the `NSWorkspace` guard proves too complex or introduces edge cases, document: "If no media app is running when you start a recording, Music.app may launch. Workaround: keep Music.app closed, or use the noTunes utility." Flag in Settings tooltip. This matches the behavior of many similar utilities.

### Recommended Resolution Path

1. During Phase 6 verification, test empirically: press recording hotkey with nothing playing.
2. If Music.app launches → implement Option A (`isAnyMediaAppRunning()` guard in `MediaPlaybackService.pause()`). This is a small, safe, self-contained change.
3. If Music.app does NOT launch on the test machine → document as "not observed; may be environment-dependent" and ship.

---

## Rapid Double-Tap Analysis

### OS Behavior (MEDIUM confidence)

The macOS HID layer does **not** debounce synthetic `CGEventPost` events. When the app calls `CGEventPost(.cghidEventTap, event)`, the event is injected directly into the HID event stream without timing checks. The `rcd` daemon does not coalesce rapid play/pause events.

What this means for rapid double-tap (user presses recording hotkey twice quickly):

**Sequence:** `pause()` → 150ms sleep → recording starts → user immediately presses hotkey again → `resume()` → recording stops.

The `pausedByApp` flag handles this correctly:
- First hotkey: `pause()` sets `pausedByApp = true`, sends play/pause.
- Second hotkey (before recording even fully starts, but after 150ms): `resume()` guards on `pausedByApp == true`, sends play/pause, sets `pausedByApp = false`.
- Net effect: two play/pause toggles sent → back to original state. If Spotify was playing, it pauses then resumes. Correct behavior.

**Problem case:** What if the second hotkey press arrives during the 150ms `Task.sleep`? The coordinator is in `.idle` state until `transitionTo(.recording)` is called (after the sleep and `audioRecorder.start()`). A second hotkey press during the sleep goes into `handleHotkey()` again in `.idle` state, triggering another `pause()` + sleep + `start()`. This is the true rapid double-tap risk: two concurrent `handleHotkey` async tasks.

**Mitigation in existing code:** `AppCoordinator` is `@MainActor`. `handleHotkey()` is `async`. The 150ms `Task.sleep` is an `await` point — it yields the actor. A second `handleHotkey()` call during the sleep CAN interleave. However, `AppCoordinator.state` transitions to `.recording` only after `audioRecorder.start()` succeeds. During the sleep, `state` is still `.idle`. A second hotkey would enter the `.idle` branch again, calling `pause()` a second time, sending a second play/pause key, and attempting another `audioRecorder.start()`. This is the actual risk.

**Existing protection:** Phase 5 added no guard against this. The roadmap success criterion "rapid double-tap does not leave media in wrong state" requires empirical verification.

**Expected observable behavior on double-tap:**
- If second tap arrives during 150ms sleep: Two pause keys sent, two recording sessions started (may cause AVAudioEngine error), `pausedByApp = true` both times. Media ends up in correct state (two toggles = net no change, or one from the engine error path calling `resume()`). Likely harmless for media state but may cause a brief recording error.
- If second tap arrives during active recording: Normal pause/resume cycle. Media state correct.

**Planner action:** The checklist should verify that after a rapid double-tap, Spotify is in the same state as before (playing if it was playing, paused if it was paused). No code change expected from this test unless a specific failure is found.

---

## Player Compatibility Matrix (Research)

### Spotify (HIGH confidence)

Spotify is the most reliable media key recipient on macOS. It registers a Now Playing session while playing, holds the session while paused, and releases it only when the user quits the app. HID play/pause via `.cghidEventTap` works reliably. The 150ms delay ensures Spotify's fade-out audio does not bleed into recording. Expected: PASS all scenarios.

### Apple Music (MEDIUM confidence)

Apple Music holds a Now Playing session when playing or paused. HID play/pause works. The risk is Music.app launching when it is not running (see above). When Music.app IS running (even paused), the media key routes to it correctly. Expected: PASS when running; see Music.app launch investigation for the not-running case.

### YouTube in Safari (MEDIUM confidence)

Safari supports the Web Media Session API and holds a Now Playing session when video/audio is playing in an active tab. HID play/pause works when video is playing. Known limitation: if the tab is backgrounded or the session expires, resume may not work. Expected: PASS for active playback; PARTIAL for backgrounded tabs.

**Community evidence:** Chrome's Web Media Session implementation has been reported as less reliable for resume via media keys when the tab loses focus. Safari is more reliable. This is why Safari was chosen for the mandatory matrix and Chrome was excluded.

### VLC (excluded from mandatory matrix, reference only)

VLC supports HID media keys and holds a Now Playing session when playing. Historical behavior: PASS. Not in mandatory matrix per CONTEXT.md decision.

---

## Verification Deliverables

Phase 6 produces exactly one document: VERIFICATION.md. It contains:

1. **Compatibility Matrix table** — rows: players; columns: pause on start, resume on stop, resume on escape, toggle OFF no-op. Cells: PASS / FAIL / PARTIAL / N/A.
2. **Edge Case Results** — nothing playing (Music.app launch test), rapid double-tap, toggle OFF end-to-end.
3. **Known Limitations** — player/scenario combinations that don't work perfectly.
4. **Fix Applied (if any)** — if Music.app guard was implemented, reference commit.

The verification report format follows the existing Phase 5 VERIFICATION.md structure (observable truths table).

---

## Common Pitfalls for Verification Phase

### Pitfall 1: Testing With Music.app Already Running

**What goes wrong:** Tester runs "nothing playing" test with Music.app open in the Dock (idle). The play/pause key routes to Music.app correctly (it is running) and may start playback, not launch it. The tester concludes "no launch issue" but has not tested the true failure case.

**How to avoid:** The "nothing playing" test must be run with Music.app completely quit (not just paused, not just minimized). Verify via `pgrep Music` or Activity Monitor before the test.

### Pitfall 2: Spotify "Playing" vs "Active Session" Timing

**What goes wrong:** Tester opens Spotify, presses play, immediately presses recording hotkey before Spotify fully registers its Now Playing session. The media key may not route to Spotify. Or tester pauses Spotify first, then tests — which tests the "paused app" scenario, not the "playing app" scenario.

**How to avoid:** Let Spotify play for 5+ seconds before triggering recording. Confirm audio is audible before the test. Note the 150ms delay is designed for this exact situation.

### Pitfall 3: Confirming Toggle OFF Doesn't Just "Look" Off

**What goes wrong:** Tester checks "Toggle OFF: music keeps playing" and observes that music keeps playing — but this could be because the toggle setting was already OFF from a previous test.

**How to avoid:** Toggle checklist order: (1) verify feature ON first, observe pause/resume. (2) Open Settings, turn OFF. (3) Confirm checkbox is unchecked. (4) Close Settings. (5) Test recording cycle. (6) Confirm music was never interrupted.

### Pitfall 4: Rapid Double-Tap Timing is Machine-Dependent

**What goes wrong:** Rapid double-tap behavior depends on human reaction time and machine performance. A "rapid" tap on a fast M3 may or may not interleave with the 150ms sleep.

**How to avoid:** Define "rapid" as: press hotkey, immediately press again (within ~100ms). Use a keyboard repeat rate test or simply tap as fast as physically possible. Document the inter-tap interval in the result.

---

## Code Examples

### NSWorkspace Media App Check (Option A fix)

```swift
// Source: NSWorkspace.runningApplications (public API)
// Add to MediaPlaybackService.swift if Music.app launch is confirmed

private func isAnyMediaAppRunning() -> Bool {
    let mediaApps: Set<String> = [
        "com.spotify.client",
        "com.apple.Music",
        "org.videolan.vlc",
        "com.apple.Safari",
        "com.google.Chrome",
        "org.mozilla.firefox"
    ]
    return NSWorkspace.shared.runningApplications
        .compactMap(\.bundleIdentifier)
        .contains { mediaApps.contains($0) }
}

// Modified pause() guard
func pause() {
    guard isEnabled else { return }
    guard isAnyMediaAppRunning() else { return }  // NEW: skip if no media app running
    postMediaKeyToggle()
    pausedByApp = true
}
```

No new imports required. `NSWorkspace` is already available via `import AppKit`.

### Checking Music.app Is Not Running (for the test)

```bash
# Verify Music.app is not running before "nothing playing" test
pgrep -x Music
# Should return nothing (exit code 1) if Music is not running
```

---

## State of the Art

| Old Approach | Current Approach | Impact |
|--------------|------------------|--------|
| MediaRemote NowPlaying detection | No detection — toggle semantics + pausedByApp flag | Still no reliable public API post-15.4; toggle is the accepted compromise |
| Ignore Music.app launch risk | Guard with NSWorkspace.runningApplications | Simple 3-line fix prevents the most disruptive edge case |
| No verification before release | Manual compatibility matrix + edge case checklist | v1.1 ships with documented behavior evidence |

---

## Open Questions

1. **Is Music.app launch actually reproducible on the user's machine?**
   - What we know: rcd is documented to launch Music.app when no Now Playing session exists. Multiple community reports confirm.
   - What's unclear: The exact macOS version and system configuration on the user's machine. Some configurations (Spotify as default, certain plist settings) may suppress this.
   - Recommendation: First test in the checklist. Determines whether Option A fix is needed.

2. **Does Safari's Now Playing session survive tab backgrounding?**
   - What we know: Safari supports Web Media Session API and holds a session while video plays.
   - What's unclear: Session lifetime when the YouTube tab is not the active tab.
   - Recommendation: Test explicitly. If YouTube in a background tab does not resume, document as "Safari: requires active tab for resume."

3. **Two concurrent handleHotkey() tasks during 150ms sleep — has this been tested?**
   - What we know: AppCoordinator is @MainActor; a second hotkey during the sleep yields the actor to the second call.
   - What's unclear: Actual AVAudioEngine behavior when start() is called while already starting.
   - Recommendation: Rapid double-tap test will surface this. If AVAudioEngine throws, the error path calls resume() and transitions to .error — media state is preserved, user sees brief error notification.

---

## Validation Architecture

> `nyquist_validation` is `true` in config.json — section included.

### Test Framework

| Property | Value |
|----------|-------|
| Framework | XCTest (existing) — but Phase 6 is primarily manual verification |
| Config file | None — Xcode scheme MyWhisperTests |
| Quick run command | `xcodebuild test -scheme MyWhisper -only-testing:MyWhisperTests/MediaPlaybackServiceTests -destination 'platform=macOS' 2>&1 \| tail -20` |
| Full suite command | `xcodebuild test -scheme MyWhisper -destination 'platform=macOS' 2>&1 \| tail -30` |

### Phase Requirements → Test Map

Phase 6 has no new requirement IDs. It validates MEDIA-01 through MEDIA-04 and SETT-01/SETT-02 via human observation. If the NSWorkspace guard fix is applied, one new unit test is warranted.

| Scenario | Behavior | Test Type | Command | Notes |
|----------|----------|-----------|---------|-------|
| Music.app guard (if fix applied) | `pause()` skips key when no media app running | unit | `xcodebuild test -scheme MyWhisper -only-testing:MyWhisperTests/MediaPlaybackServiceTests` | New test in MediaPlaybackServiceTests |
| Spotify pause/resume | Playing → record → stop → resumed | manual | Human observation | Primary success scenario |
| Apple Music pause/resume | Playing → record → stop → resumed | manual | Human observation | Requires Music.app running |
| Nothing playing (Music.app guard) | Record with nothing playing → no Music.app launch | manual | Human observation | Critical release gate |
| YouTube in Safari | Playing → record → stop → resumed | manual | Human observation | PARTIAL result acceptable |
| Rapid double-tap | Two fast hotkey presses → media in original state | manual | Human observation | Uses "as fast as possible" definition |
| Toggle OFF | Recording cycle with toggle off → no pause/resume | manual | Human observation | Re-validates SETT-01 end-to-end |

### Sampling Rate

- **Before checklist execution:** `xcodebuild test -scheme MyWhisper -destination 'platform=macOS' 2>&1 | tail -30` — confirm existing 11 media tests still green
- **After NSWorkspace fix (if applied):** Run full test suite to verify new guard test passes
- **Phase gate:** Full suite green + VERIFICATION.md completed before v1.1 ships

### Wave 0 Gaps

If the NSWorkspace guard fix is applied:
- [ ] New test in `MyWhisperTests/MediaPlaybackServiceTests.swift` — covers `pause()` skips key when `isAnyMediaAppRunning() == false`

If no code changes needed:
- None — existing test infrastructure covers all Phase 5 requirements; Phase 6 is purely manual.

---

## Sources

### Primary (HIGH confidence)
- Existing codebase: `MediaPlaybackService.swift`, `AppCoordinator.swift` — read directly
- `.planning/phases/05-pause-playback-implementation/05-RESEARCH.md` — Phase 5 pitfalls (established baseline)
- `.planning/phases/05-pause-playback-implementation/05-VERIFICATION.md` — Human verification items still pending
- `.planning/phases/06-integration-verification/06-CONTEXT.md` — Locked decisions and constraints
- [Apple Developer Documentation: NSWorkspace.runningApplications](https://developer.apple.com/documentation/appkit/nsworkspace/runningapplications) — stable public API

### Secondary (MEDIUM confidence)
- [Apple Discussions: Apple Music opens after pressing Play/pause key](https://discussions.apple.com/thread/255329934) — confirms rcd behavior, 2024
- [OSXDaily: How to Stop Apple Music from Opening on Mac Randomly (Sept 2024)](https://osxdaily.com/2024/09/20/stop-music-opening-mac/) — rcd mechanism explained
- [Hacker News: NoTunes discussion](https://news.ycombinator.com/item?id=40426621) — community confirmation + multiple approaches documented
- [GitHub: AntiMusic](https://github.com/nift4/AntiMusic) — "fake" Now Playing session approach, reveals private API reliance
- [SuperWhisper changelog](https://superwhisper.com/changelog) — v1.44.1 shipped pause media feature without documented Music.app workaround

### Tertiary (LOW confidence)
- macOS rcd man page notes — launchctl disable approach (system-destructive, not applicable)
- Multiple Apple Community threads confirming Music.app auto-launch on macOS 15 Sequoia — consistency confirms behavior

---

## Metadata

**Confidence breakdown:**
- Music.app launch mechanism: HIGH — rcd behavior confirmed by multiple sources, well-documented
- NSWorkspace guard fix: MEDIUM — API is stable; bundle IDs are known; logic is sound; actual behavior on user's machine untested
- Double-tap behavior: MEDIUM — actor model analysis is sound; empirical result depends on machine speed
- Player compatibility: HIGH (Spotify) / MEDIUM (Safari) / LOW (precise edge cases) — general behavior well-known, specific interactions require manual test

**Research date:** 2026-03-17
**Valid until:** 2026-04-17 (macOS media key routing unlikely to change in 30 days; rcd behavior stable across Sequoia minor versions)
