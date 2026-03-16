# Pitfalls Research

**Domain:** Local voice-to-text macOS menubar app — v1.1 Pause Playback feature
**Researched:** 2026-03-16
**Confidence:** HIGH (MediaRemote breakage verified via multiple developer sources and official feedback reports), MEDIUM (edge cases around specific media apps), HIGH (CGEvent media key approach, FSM integration)

---

## Critical Pitfalls

### Pitfall 1: MediaRemote is a Private Framework Broken Since macOS 15.4

**What goes wrong:**
The most common approach for reading "now playing" state and sending pause/resume commands on macOS is `MediaRemote.framework` (private) via dlopen + dlsym, using functions like `MRMediaRemoteGetNowPlayingInfo` and `MRMediaRemoteSendCommand`. As of macOS 15.4, Apple added entitlement verification inside `mediaremoted` — any client process without the `com.apple.mediaremote` entitlement (available only to Apple-internal processes) is silently denied access to now-playing information. Apps like LyricsX broke entirely overnight. Third-party apps cannot obtain this entitlement.

**Why it happens:**
MediaRemote has worked via dlopen for over a decade with no public replacement. Developers build features on it without realizing it is private, has no ABI stability guarantee, and Apple can (and did) restrict it at any time. The breakage is silent — function calls succeed but return empty data.

**How to avoid:**
Do NOT use `MediaRemote.framework` directly. Use `CGEvent`-based media key simulation instead — send a play/pause system key event via `NSEvent.otherEvent` with `NX_KEYTYPE_PLAY` (value 16), which works without any entitlement and is the same approach Superwhisper uses. This approach does not require reading "is something currently playing?" — it toggles whatever is currently playing, which is exactly the behavior needed.

If reading now-playing state is required (to avoid sending "resume" when nothing was paused), the only working workaround on macOS 15.4+ is the Perl adapter pattern: spawn `/usr/bin/perl` (which is entitled) with a helper dylib. This is a fragile third-party hack, not a stable foundation.

**Warning signs:**
- `MRMediaRemoteGetNowPlayingInfo` callback receives empty dictionary.
- Spotify/Apple Music does not respond to `MRMediaRemoteSendCommand`.
- Code works on macOS 15.3 or earlier but breaks on 15.4+.
- The framework loads successfully (dlopen returns non-nil) but returns no useful data.

**Phase to address:**
Implementation phase (Phase 1 of v1.1). Do not start with MediaRemote — go straight to the CGEvent media key approach. This is the correct default, not a fallback.

---

### Pitfall 2: Resuming Media the User Had Already Paused Manually

**What goes wrong:**
If the user manually paused Spotify before starting a recording, the app will:
1. Record starts → sends play/pause (no-op — nothing was playing, or worse: starts playing something the user had intentionally stopped).
2. Record ends → sends play/pause again → now music starts when the user wanted it off.

The app cannot distinguish "paused by user" from "paused by us." Without tracking this distinction, the resume on stop is wrong in common cases.

**Why it happens:**
Reading the current playback state on macOS is non-trivial (requires MediaRemote, which is broken since 15.4). Developers assume "just send play/pause on both sides" is safe. It is not. The state they need ("was media playing before we paused it?") requires they observe state before acting, not just toggle blindly.

**How to avoid:**
Query the now-playing state before sending the pause on recording start:
- If something is actively playing → send pause, record that `mediaPausedByApp = true`.
- If nothing is playing → do not send pause, set `mediaPausedByApp = false`.
On recording end: only send play/resume if `mediaPausedByApp == true`, then reset the flag.

For the now-playing query, the CGEvent approach cannot read state — you need either:
1. The Perl adapter workaround for macOS 15.4+ (fragile, adds process overhead).
2. AppleScript targeted at specific apps (Spotify, Apple Music, Vox) — works without MediaRemote, but requires knowing which app is playing.
3. Accept the simpler behavior: toggle on both sides and document the edge case, letting the user disable the feature if it causes issues.

Option 3 (toggle + user toggle in Settings) is recommended for v1.1 scope. Option 2 (AppleScript per-app) is the right answer for v1.2 if users complain.

**Warning signs:**
- Music starts playing when recording ends, but user had paused it before recording.
- Repeated recordings cause media to get out of sync (starts when it should be stopped, or vice versa).
- Users report the feature "turns on their music randomly."

**Phase to address:**
Implementation phase. Design the `mediaPausedByApp` flag into the coordinator from the start. Even if you use the simple toggle approach initially, the flag slot prevents future regressions.

---

### Pitfall 3: Media Key Events Land on the Wrong App

**What goes wrong:**
macOS routes media key events to the application that most recently registered as a media handler. This is not necessarily the frontmost app, and it is not necessarily the app the user thinks is "in control." Edge cases:

- Safari has a YouTube tab open but audio is paused → media keys now go to Safari, not Spotify running in the background.
- A notification sound from Slack briefly takes media focus → subsequent media key goes to Slack (which does nothing visible) rather than Apple Music.
- Multiple audio players are open → the wrong one receives the pause and the one the user cares about keeps playing.

The app cannot control which app receives the media key event. It fires into the system and goes to whoever holds the "now playing" token.

**Why it happens:**
macOS "Now Playing" focus is assigned to the last app that registered with `MPNowPlayingInfoCenter` and actively reported playback state. Browsers, video apps, and notification sounds all compete for this token. The system provides no way for a sender to target a specific app when using the media key approach.

**How to avoid:**
- Accept this as a known limitation and document it clearly in the Settings UI near the Pause Playback toggle: "Pauses the active media player. May not work if multiple media apps are open."
- Do not attempt to solve this in v1.1 — the correct solution (per-app AppleScript targeting) is significantly more complex and requires maintaining an app whitelist.
- Test against the most common scenarios: Spotify + Safari open, Apple Music + browser, YouTube in Safari only. Confirm the pause lands where the user expects in the common case.

**Warning signs:**
- Pause fires successfully (no error) but the wrong app is paused.
- YouTube tab pauses but Spotify keeps playing.
- User reports "sometimes it works, sometimes it doesn't."

**Phase to address:**
Implementation phase. Add the limitation note to the Settings UI during integration. Test with multiple apps open explicitly.

---

### Pitfall 4: AppCoordinator FSM State Corruption on Fast Hotkey Press During Pause/Resume

**What goes wrong:**
The user presses the hotkey rapidly twice. The first press triggers:
- State: `idle → recording`
- Sends media pause.

Before the pause completes (it's async via CGEvent delivery), the second press fires:
- State: `recording → processing`
- Recording stops prematurely (near-zero audio buffer).
- `mediaPausedByApp` flag is `true` but the resume fires immediately, before the pause even arrived at the media player.

Result: media key events fire out of order (pause then resume arrives in the wrong sequence), and the user gets a near-empty transcription. This is an extension of the existing rapid-hotkey problem, now compounded by async media operations.

**Why it happens:**
CGEvent-based media key delivery is asynchronous — the event is posted to the HID event tap and delivery is not guaranteed to be synchronous with the Swift code. If resume is sent immediately after pause, the ordering is not guaranteed if the system is under load.

**How to avoid:**
- The existing AppCoordinator FSM already guards against re-entrant hotkey calls during `processing` state.
- Extend the guard: during the `recording` state transition-in, add a brief delay (50–100ms) before enabling hotkey-to-stop, to prevent accidental double-tap recording starts.
- The media key for pause should be sent before `AVAudioEngine.start()` (record the intent first, then start). Resume should be sent after the pipeline completes and state returns to `idle`, not immediately after `AVAudioEngine.stop()`.

**Warning signs:**
- Very short transcriptions with garbled or empty output followed by music unexpectedly resuming.
- Log shows `recording → processing` transition firing within <200ms of `idle → recording`.
- Media briefly pauses and immediately resumes (out-of-order events).

**Phase to address:**
Implementation phase. Add an explicit ordering specification: pause before engine start, resume after pipeline idle. Add a minimum recording duration guard (e.g., 500ms minimum).

---

### Pitfall 5: CGEvent Media Key Fails Silently When Input Monitoring Permission Is Missing

**What goes wrong:**
Sending media key events via `CGEventPost` with `NX_KEYTYPE_PLAY` does not require Accessibility permission — it can be posted to `kCGHIDEventTap`. However, the CGEventTap that the app is already using for the global hotkey does require Accessibility permission. If Accessibility is granted but Input Monitoring is not (or vice versa), the app's existing tap works but media key events may be routed unexpectedly, or the entire event tap can be silently disabled by macOS.

There is a second silent failure mode: after code re-signing (e.g., a new build or DMG distribution), macOS may silently disable the CGEventTap. The tap appears installed (`tapIsEnabled()` returns true initially) but events stop firing. This affects both the existing hotkey tap and any new event posting.

**Why it happens:**
TCC permission state is tied to code identity. Re-signing creates a new identity. The existing app (v1.0) already handled this for the global hotkey tap — but adding a new capability (posting media events) to the same tap may require re-granting in some edge cases.

**How to avoid:**
- The media key send via `CGEventPost` to `kCGHIDEventTap` does not require additional permissions beyond what v1.0 already has (Accessibility).
- Verify this assumption explicitly during implementation by testing on a clean machine with only Accessibility granted.
- Re-use the existing health check infrastructure from v1.0 — if the `AXIsProcessTrusted()` check fails, the media pause feature should also be disabled (they share the same permission dependency).
- Add a periodic `CGEvent.tapIsEnabled(tap:)` check to the existing health monitor.

**Warning signs:**
- Hotkey works but media never pauses.
- After updating the app, permissions are revoked unexpectedly.
- No error logged from `CGEventPost` but media player does not respond.

**Phase to address:**
Implementation phase. Verify permission requirements before writing media key sending code.

---

### Pitfall 6: Browsers and Progressive Web Apps Do Not Respond to Media Key Pause

**What goes wrong:**
Safari, Chrome, and Firefox implement their own media session handling. In macOS 15+, browser media sessions compete aggressively for the "Now Playing" token. Specific behaviors:

- **YouTube in Safari**: Receives media key pause correctly in most cases. BUT if the user has multiple tabs with audio, the media key goes to the tab that most recently had audio activity — not necessarily the one currently playing.
- **YouTube in Chrome**: Uses the Web Media Session API. Pause via media key works, but resume may not: Chrome's Web Media Session implementation sometimes requires the user to be focused on the tab for resume to work.
- **Spotify Web Player in browser**: Has known issues where media keys work intermittently depending on whether the native Spotify app is also installed.
- **Netflix, Disney+, other DRM video**: These apps may not respond to media key pause at all due to their custom playback implementations.

**Why it happens:**
Browser media sessions are implemented at the browser level, not macOS system level. The browser acts as a proxy between the web page and the system Now Playing infrastructure. Each browser implements this proxy differently.

**How to avoid:**
- Accept that browser-based media has variable compatibility. Document this in Settings: "Works best with Spotify, Apple Music, and other native media players."
- Test the most common user scenarios: Spotify native app, Apple Music, YouTube in Safari, YouTube in Chrome.
- Do not attempt to solve DRM video (Netflix) — not feasible without per-app automation.
- For the Superwhisper comparison: Superwhisper offers "Mute" as an alternative to "Pause" — muting the system audio is a 100% reliable fallback when media key routing fails.

**Warning signs:**
- Pause works for Spotify native but not YouTube in browser.
- Resume works for Apple Music but not for a browser-based player.
- Users report the feature works on their machine but not a coworker's (different browser or setup).

**Phase to address:**
Integration testing phase. Build a compatibility matrix (Spotify, Apple Music, YouTube/Safari, YouTube/Chrome) as part of verification.

---

### Pitfall 7: Race Between AVAudioEngine Start and Media Player Pause Settling

**What goes wrong:**
The media player receives the pause command and begins its fade-out (Spotify uses a short fade, Apple Music uses an instant cut). Meanwhile, `AVAudioEngine.start()` captures this fade audio into the recording buffer. The Whisper transcription then receives 100–500ms of fading music audio at the start of every recording. For speech, this adds noise that degrades transcription accuracy, particularly for the first word.

**Why it happens:**
The order "send pause → start engine → wait → speak" is logical but the pause is not instantaneous. Spotify's pause fade takes ~100–200ms. The engine starts capturing immediately.

**How to avoid:**
- Send the media pause command before starting the engine, and add a 150–300ms delay between the pause command and `AVAudioEngine.start()`.
- This delay is the same as the minimum recording duration guard from Pitfall 4 — they can share a single `Task.sleep(.milliseconds(200))` call.
- The delay is imperceptible to the user and prevents music bleed into the recording.

**Warning signs:**
- First word of transcription is consistently garbled or missing.
- Adding a manual delay before speaking improves results significantly.
- Raw recording buffer shows audio signal at the start before speech begins.

**Phase to address:**
Implementation phase. Add the delay as part of the recording start sequence.

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Use `MediaRemote.framework` via dlopen | Access to rich now-playing state | Completely broken on macOS 15.4+; private API with no ABI stability | Never — use CGEvent media key instead |
| Toggle media without checking current state | Simpler code (no state query) | Resumes media the user had intentionally paused; frustrating UX | Acceptable in v1.1 with user-facing documentation of the limitation; fix in v1.2 |
| Send pause and resume synchronously with no delay | Fastest implementation | Music audio bleeds into recording; resume and pause may arrive out of order | Never — always add 150ms delay between pause and engine start |
| Hardcode list of supported media apps | Avoids complexity of per-app detection | Fails when user uses an unlisted app (e.g., VLC, Vox, Doppler) | Acceptable if the feature works for the 3 most common apps and gracefully does nothing for others |
| Use the Perl adapter workaround for now-playing state | Access to playback state on 15.4+ | External process spawn, fragile API, may break on future macOS updates | Only if per-app state detection is required (v1.2+), never in v1.1 |

---

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| CGEvent media key send | Use `kCGSessionEventTap` tap location for sending | Use `kCGHIDEventTap` for sending synthetic media key events — it routes correctly to the media handler |
| `NX_KEYTYPE_PLAY` event construction | Forget to send both key-down and key-up events | Construct two events: `data1 = (NX_KEYTYPE_PLAY << 16) | (0xa << 8)` (key-down) and `data1 = (NX_KEYTYPE_PLAY << 16) | (0xb << 8)` (key-up); post both via `CGEventPost` |
| AppCoordinator FSM integration | Add media pause as a side effect inside `handleHotkey()` | Encapsulate all media control in a `MediaController` object; inject it into the coordinator — keeps the FSM clean and makes media behavior testable independently |
| Settings toggle for Pause Playback | Read `UserDefaults` directly inside the media pause call | Gate the entire feature at the coordinator level: if `isMediaPauseEnabled == false`, skip the media pause step entirely — do not check inside the media controller |
| macOS Accessibility permission | Assume Accessibility covers media key sending | Verify independently: `CGEventPost` with `kCGHIDEventTap` does not require Accessibility for sending. Do not gate the media feature on `AXIsProcessTrusted()` — it will work even if Accessibility was revoked (the hotkey would break, but not the media key send) |

---

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| Spawning a process to query now-playing state | 50–200ms latency spike at hotkey press | Do not query state synchronously at hotkey time; use a background polling approach or accept the simpler toggle-only model | Every hotkey press if naive process spawn is used |
| Observing `MPNowPlayingInfoCenter` for state changes | Callback may not fire for third-party apps (post-15.4 restriction) | Do not depend on `MPNowPlayingInfoCenter` observation for the `mediaPausedByApp` flag — set the flag based on your own action, not observed external state | Any macOS 15.4+ system |
| Checking now-playing state via MediaRemote dlopen on 15.4+ | Returns empty data, takes ~200ms to timeout | Do not use — see Pitfall 1 | macOS 15.4+ (all current hardware) |

---

## UX Pitfalls

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| Feature silently does nothing when media key goes to wrong app | User disables the feature thinking it's broken, when it's just an edge case | Show a brief "Media paused" notification on successful pause, so user gets confirmation. If pause is sent but nothing visibly happened, the notification is still reassuring. |
| Feature always resumes even when user paused media intentionally | Unwanted media starts playing; user distrust | Implement `mediaPausedByApp` flag (Pitfall 2). At minimum, document the limitation prominently in Settings next to the toggle. |
| Toggle is buried in Settings — user can't find it | Feature can't be discovered or disabled | Put the Pause Playback toggle in the main Settings view (top-level), not a sub-page. It's a primary behavior that affects every recording. |
| No feedback when media key is sent but nothing was playing | User doesn't know if the feature is working | Silent success is fine — do not add a "Nothing was playing" alert. Only notify on positive pause confirmation. |
| Feature enables itself by default | Unexpected behavior on first launch | Default the toggle to `true` (on) — this is the expected behavior. But on first use, if the user is not playing anything, the toggle-approach harmlessly does nothing. |

---

## "Looks Done But Isn't" Checklist

- [ ] **Media pause:** Tested with Spotify native app playing — verify pause fires when recording starts, resumes when recording ends
- [ ] **Media pause:** Tested with Apple Music playing — verify same behavior
- [ ] **Media pause:** Tested with YouTube in Safari playing — verify pause works (resume may have caveats — document if so)
- [ ] **Media pause:** Tested with nothing playing — verify app does not crash or start playback unexpectedly
- [ ] **Media pause:** Tested with user-paused Spotify (no active playback) — verify recording start does not accidentally start playback
- [ ] **Media pause:** Tested with Settings toggle OFF — verify no media keys are sent during recording
- [ ] **Ordering:** Verified via logging that pause event is sent BEFORE `AVAudioEngine.start()`
- [ ] **Ordering:** Verified that resume is sent AFTER the pipeline completes (state = idle), not immediately after engine stop
- [ ] **Delay:** Verified 150–200ms gap between pause command and engine start (no music audio in recording buffer)
- [ ] **FSM guard:** Rapid double-tap hotkey does not send double-pause or double-resume
- [ ] **Error path:** Recording errors (mic permission revoked mid-recording) still send resume if `mediaPausedByApp == true`
- [ ] **Settings persistence:** Toggle state survives app restart (UserDefaults)

---

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| Built on MediaRemote, now broken on 15.4 | HIGH | Full rewrite of media control subsystem to CGEvent approach. Any shipped version is non-functional on 15.4+ for users. |
| Toggle-based pause resumes music user had paused | LOW | Add `mediaPausedByApp` flag in a patch release; no user action required. Can also add a "Only resume if we paused it" Settings option. |
| Media bleeds into recording (no delay) | LOW | Add 150–200ms delay in a patch. Users may not notice this is causing their issue — it manifests as first-word accuracy degradation. |
| Wrong app gets paused | MEDIUM | Ship per-app AppleScript targeting for Spotify and Apple Music as optional advanced mode. Requires maintaining app list. |
| CGEvent tap silently disabled after update | LOW | The existing v1.0 permission health check covers this. Ensure it covers the new feature in the same check. |

---

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| MediaRemote private API (broken on 15.4) | v1.1 Phase 1: Design | Confirm implementation uses CGEvent approach, not MediaRemote — no dlopen of MediaRemote.framework |
| Resuming user-paused media | v1.1 Phase 1: Implementation | Test: pause Spotify manually, start recording, stop recording — Spotify does not resume |
| Media key to wrong app | v1.1 Phase 2: Integration testing | Test matrix: Spotify + Safari open simultaneously — correct player pauses |
| FSM state corruption on rapid hotkey | v1.1 Phase 1: FSM extension | Rapid double-tap test: second tap during recording does not cause double-pause/resume |
| CGEvent permissions silent failure | v1.1 Phase 1: Implementation | Test on clean machine with only Accessibility granted — media key still fires |
| Browser media compat issues | v1.1 Phase 2: Integration testing | YouTube/Safari and YouTube/Chrome tested; behavior documented in Settings if limited |
| Audio engine start / pause race | v1.1 Phase 1: Implementation | Raw recording buffer inspection: no music audio in first 150ms of recording |
| Settings toggle not respected | v1.1 Phase 1: Implementation | Toggle OFF → record → confirm no media events sent (add log assertion) |

---

## Sources

- [FB17228659: Please add public API for now playing information — feedback-assistant/reports Issue #637](https://github.com/feedback-assistant/reports/issues/637)
- [mediaremote-adapter: Fully functional MediaRemote access for all macOS versions — ungive/mediaremote-adapter](https://github.com/ungive/mediaremote-adapter)
- [Dev:MediaRemote.framework — The Apple Wiki](https://theapplewiki.com/wiki/Dev:MediaRemote.framework)
- [media-remote Swift bindings — nohackjustnoobb/media-remote](https://github.com/nohackjustnoobb/media-remote)
- [Play/Pause now playing with MediaRemote framework — Apple Developer Forums thread/688433](https://developer.apple.com/forums/thread/688433)
- [Apple Keyboard Media Key Event Handling — Rogue Amoeba (2007, still accurate for CGEvent approach)](https://weblog.rogueamoeba.com/2007/09/29/apple-keyboard-media-key-event-handling/)
- [Mac Replication of Media Key Press — CopyProgramming](https://copyprogramming.com/howto/emulate-media-key-press-on-mac)
- [CGEvent Taps and Code Signing: The Silent Disable Race — Daniel Raffel (2026-02-19)](https://danielraffel.me/til/2026/02/19/cgevent-taps-and-code-signing-the-silent-disable-race/)
- [MPNowPlayingInfoCenter — Apple Developer Documentation](https://developer.apple.com/documentation/mediaplayer/mpnowplayinginfocenter)
- [Now Playing menu bar item not behaving properly — mpv-player/mpv Issue #11233](https://github.com/mpv-player/mpv/issues/11233)
- [Mac media keys don't work if another app takes lock — mpv-player/mpv Issue #4834](https://github.com/mpv-player/mpv/issues/4834)
- [MediaKeyTap — Access media key events from Swift — nhurden/MediaKeyTap](https://github.com/nhurden/MediaKeyTap)
- [superwhisper "pause music while recording" option — @superwhisperapp on X (2025)](https://x.com/superwhisperapp/status/1963687889193095282)
- [Accessibility Permission in macOS — jano.dev (2025)](https://jano.dev/apple/macos/swift/2025/01/08/Accessibility-Permission.html)
- [NowPlaying State Not Updating — Apple Developer Forums thread/728212](https://developer.apple.com/forums/thread/728212)

---

## Appendix: Pre-existing Pitfalls from v1.0 (Still Applicable)

The following pitfalls from v1.0 research remain valid for v1.1. They are documented in detail in the 2026-03-15 version of this file and not duplicated here:

- Pitfall: Ctrl+Space conflicts with macOS Input Source switching (Phase 1 — already addressed)
- Pitfall: CGEventPost blocked in sandboxed apps (Phase 1 — already addressed, still applicable)
- Pitfall: Accessibility permission lost on Xcode rebuild (Phase 1 — already addressed)
- Pitfall: Whisper hallucination on silence (Phase 2 — already addressed)
- Pitfall: Whisper CoreML first-load latency (Phase 2 — already addressed)
- Pitfall: LLM rewrites text meaning (Phase 3 — already addressed)
- Pitfall: macOS permission resets after major OS updates (Phase 1 — already addressed)
- Pitfall: AVAudioEngine sample rate mismatch (Phase 2 — already addressed)

---
*Pitfalls research for: v1.1 Pause Playback feature — macOS media control*
*Researched: 2026-03-16*
