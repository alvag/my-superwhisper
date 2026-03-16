# Architecture Research

**Domain:** Pause Playback integration into existing macOS menubar voice-to-text app
**Researched:** 2026-03-16
**Confidence:** HIGH (existing codebase read directly; media key approach cross-verified with multiple sources)

---

## Standard Architecture

### System Overview — v1.1 with Pause Playback

```
┌─────────────────────────────────────────────────────────────────┐
│                        AppDelegate (wiring)                      │
├─────────────────────────────────────────────────────────────────┤
│  ┌───────────────┐  ┌────────────────┐  ┌────────────────────┐  │
│  │ HotkeyMonitor │  │  EscapeMonitor │  │ MenubarController  │  │
│  └──────┬────────┘  └───────┬────────┘  └─────────┬──────────┘  │
│         │                  │                      │              │
├─────────▼──────────────────▼──────────────────────▼─────────────┤
│                      AppCoordinator (FSM)                        │
│              idle ↔ recording ↔ processing ↔ error               │
│                                                                  │
│   ON ENTER recording:  → MediaPlaybackService.pause()  [NEW]    │
│   ON EXIT  recording:  → MediaPlaybackService.resume() [NEW]    │
├─────────────────────────────────────────────────────────────────┤
│  ┌──────────────┐ ┌────────────┐ ┌───────────────────────────┐  │
│  │ AudioRecorder│ │ STTEngine  │ │  HaikuCleanupService      │  │
│  └──────────────┘ └────────────┘ └───────────────────────────┘  │
│  ┌──────────────┐ ┌────────────┐ ┌──────────────┐               │
│  │ TextInjector │ │VocabService│ │HistoryService│               │
│  └──────────────┘ └────────────┘ └──────────────┘               │
│  ┌──────────────────────────────────────────────────────────┐    │
│  │   MediaPlaybackService  [NEW]                            │    │
│  │   Wraps: CGEventPost — NX_KEYTYPE_PLAY media key sim     │    │
│  │   Setting: UserDefaults "pausePlaybackEnabled"           │    │
│  └──────────────────────────────────────────────────────────┘    │
├─────────────────────────────────────────────────────────────────┤
│  ┌────────────────────────────────────────────────────────────┐  │
│  │  SettingsWindowController  [MODIFIED — add toggle row]    │  │
│  └────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

### Component Responsibilities

| Component | Responsibility | Status |
|-----------|----------------|--------|
| `AppCoordinator` | FSM transitions; calls `MediaPlaybackService` at `idle→recording` and `recording→*` | Modified |
| `MediaPlaybackService` | Sends system-wide play/pause media key event via `CGEventPost`; reads enabled setting | New |
| `SettingsWindowController` | Renders Pause Playback toggle (`NSButton` checkbox); persists to `UserDefaults` | Modified |
| `AppDelegate` | Instantiates `MediaPlaybackService`; injects into `AppCoordinator` | Modified |
| `AppCoordinatorDependencies` | Declares `MediaPlaybackServiceProtocol` for testability | Modified |

---

## New vs Modified Components

### New: `MediaPlaybackService`

Single-responsibility service. All media-key logic lives here so `AppCoordinator` stays clean.

File location: `MyWhisper/System/MediaPlaybackService.swift`

Responsibilities:
- Read `UserDefaults.standard.bool(forKey: "pausePlaybackEnabled")` at call time (defaults `true`)
- Send `NX_KEYTYPE_PLAY` key-down + key-up via `CGEventPost(.cghidEventTap)` when `pause()` is called
- Send the same event when `resume()` is called (play/pause is a hardware toggle — same keycode for both directions)
- Guard: if `!isEnabled`, return immediately without posting any events

Protocol (for testability in unit tests):

```swift
protocol MediaPlaybackServiceProtocol: AnyObject {
    func pause()
    func resume()
    var isEnabled: Bool { get }
}
```

Implementation sketch:

```swift
final class MediaPlaybackService: MediaPlaybackServiceProtocol {
    var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: "pausePlaybackEnabled")
    }

    func pause()  { sendMediaKey() }
    func resume() { sendMediaKey() }

    private func sendMediaKey() {
        guard isEnabled else { return }
        let key = Int(NX_KEYTYPE_PLAY)
        postMediaKey(key, down: true)
        postMediaKey(key, down: false)
    }

    private func postMediaKey(_ key: Int, down: Bool) {
        let flags = NSEvent.ModifierFlags(rawValue: down ? 0xA00 : 0xB00)
        let event = NSEvent.otherEvent(
            with: .systemDefined,
            location: .zero,
            modifierFlags: flags,
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            subtype: 8,
            data1: (key << 16) | ((down ? 0xA : 0xB) << 8),
            data2: -1
        )
        event?.cgEvent?.post(tap: .cghidEventTap)
    }
}
```

### Modified: `AppCoordinatorDependencies.swift`

Add `MediaPlaybackServiceProtocol` declaration alongside the existing protocols (`AudioRecorderProtocol`, `TextInjectorProtocol`, etc.). No other change.

### Modified: `AppCoordinator.swift`

Add one stored property:

```swift
var mediaPlayback: (any MediaPlaybackServiceProtocol)?
```

Add three call sites within `handleHotkey()` and `handleEscape()`:

| Location | Call | Reason |
|----------|------|--------|
| `.idle` branch — before `audioRecorder?.start()` | `mediaPlayback?.pause()` | Pause before mic opens |
| `.recording` branch — after `escapeMonitor?.stopMonitoring()` | `mediaPlayback?.resume()` | Resume after normal stop |
| `handleEscape()` — after `audioRecorder?.cancel()` | `mediaPlayback?.resume()` | Resume after cancelled recording |

No other changes to coordinator logic.

### Modified: `AppDelegate.swift`

Add one stored property:

```swift
private var mediaPlaybackService: MediaPlaybackService?
```

In `applicationDidFinishLaunching`, after existing service instantiations:

```swift
let mediaPlaybackService = MediaPlaybackService()
coordinator.mediaPlayback = mediaPlaybackService
self.mediaPlaybackService = mediaPlaybackService
```

### Modified: `SettingsWindowController.swift`

Add Section 6 below the existing "Launch at Login" checkbox. The toggle writes directly to `UserDefaults` — no reference to `MediaPlaybackService` needed:

```swift
let pauseCheckbox = NSButton(
    checkboxWithTitle: "Pausar reproducción al grabar",
    target: self,
    action: #selector(pausePlaybackChanged(_:))
)
pauseCheckbox.state = UserDefaults.standard.bool(forKey: "pausePlaybackEnabled") ? .on : .off
```

```swift
@objc private func pausePlaybackChanged(_ sender: NSButton) {
    UserDefaults.standard.set(sender.state == .on, forKey: "pausePlaybackEnabled")
}
```

The `SettingsWindowController` init signature does not change — no new dependency injection required.

---

## Data Flow

### Pause Flow (hotkey pressed while idle)

```
User presses Option+Space
    ↓
HotkeyMonitor fires → AppCoordinator.handleHotkey()  [state: .idle]
    ↓  mic permission check passes, API-key check passes
MediaPlaybackService.pause()
    → reads UserDefaults["pausePlaybackEnabled"]
    → if true: CGEventPost NX_KEYTYPE_PLAY (down + up)
    → system media server routes event to Now Playing app → pauses
    ↓
audioRecorder?.start()
transitionTo(.recording)
overlay shows, waveform begins
```

### Resume Flow — Normal Stop (hotkey pressed while recording)

```
User presses Option+Space  [state: .recording]
    ↓
escapeMonitor?.stopMonitoring()
stopAudioLevelPolling()
MediaPlaybackService.resume()
    → reads UserDefaults["pausePlaybackEnabled"]
    → if true: CGEventPost NX_KEYTYPE_PLAY (down + up)
    → system media server routes event → resumes playback
    ↓
audioRecorder?.stop() → VAD check → transcription pipeline...
```

### Resume Flow — Escape Cancel

```
User presses Escape  [state: .recording]
    ↓
AppCoordinator.handleEscape()
escapeMonitor?.stopMonitoring()
stopAudioLevelPolling()
overlayController?.hide()
audioRecorder?.cancel()
MediaPlaybackService.resume()
    → CGEventPost NX_KEYTYPE_PLAY
NSSound.beep()
transitionTo(.idle)
```

### Settings Toggle Flow

```
User opens Preferences → checks/unchecks "Pausar reproducción al grabar"
    ↓
SettingsWindowController.pausePlaybackChanged(_:)
    ↓
UserDefaults.standard.set(Bool, forKey: "pausePlaybackEnabled")

MediaPlaybackService reads this key at each pause()/resume() call.
Change takes effect on the next recording session. No restart needed.
```

---

## Architectural Patterns

### Pattern 1: FSM Side-Effect Injection

**What:** `AppCoordinator` holds a protocol reference (`MediaPlaybackServiceProtocol`). It calls `pause()`/`resume()` as side effects at state transition boundaries. No media-control logic lives in the coordinator.

**When to use:** Any external system action that must happen at a state boundary but has no bearing on state itself.

**Trade-offs:** Keeps coordinator focused and testable. Adds one optional dependency. No meaningful downsides at this feature size.

### Pattern 2: CGEventPost Media Key (NX_KEYTYPE_PLAY)

**What:** Post a synthetic `NSSystemDefined` event (type 14, subtype 8) with `NX_KEYTYPE_PLAY` (keyCode 16) to `.cghidEventTap`. This mimics the hardware Play/Pause key. One post pauses, the next post resumes — identical to the physical key.

**When to use:** System-wide media control for any player (Spotify, Apple Music, YouTube in Safari, podcast apps, video players) without app-specific knowledge.

**Why this over alternatives:**
- The app is already non-sandboxed (Developer ID distribution) — `CGEventPost` is already in use by `TextInjector` for paste simulation. No new permissions required.
- Works with every app that responds to hardware media keys, which is essentially all media players.
- If nothing is playing, the key press is silently ignored — no crash, no error.
- macOS 15.4 entitlement restrictions apply to the private `MediaRemote.framework`. They do not affect `CGEventPost` media key simulation, which is an independent, lower-level mechanism.

**Confidence:** HIGH. The pattern is well-established and already in use in the same codebase for `TextInjector`.

### Pattern 3: UserDefaults Read at Call Time (No Subscription)

**What:** `MediaPlaybackService` reads `UserDefaults.standard.bool(forKey: "pausePlaybackEnabled")` at the moment `pause()` or `resume()` is called, rather than subscribing to changes.

**When to use:** Boolean feature flags that change only from a Settings panel interaction.

**Trade-offs:** Zero coupling between `SettingsWindowController` and `MediaPlaybackService`. No Combine/observation boilerplate. Toggle takes effect on the next recording session — expected UX for a settings panel.

---

## Integration Points

### Internal Boundaries

| Boundary | Communication | Notes |
|----------|---------------|-------|
| `AppCoordinator` → `MediaPlaybackService` | Protocol method call at state transitions | Injected by `AppDelegate` at startup |
| `SettingsWindowController` → `MediaPlaybackService` | None — decoupled via `UserDefaults` | No new init parameter needed |
| `MediaPlaybackService` → macOS media system | `CGEventPost(.cghidEventTap)` with `NSSystemDefined` event | Same entitlement scope as `TextInjector` |

### System-Level Boundary

The `NX_KEYTYPE_PLAY` event posted to `.cghidEventTap` is routed by the macOS media server to whichever app currently holds the Now Playing session. The app does not need to know what is playing or which app is playing it. This is the same routing that happens when the user presses the physical Play/Pause key on an Apple keyboard.

---

## Build Order (Implementation Sequence)

Dependencies determine order. Steps 4 and 5 are independent and can proceed in parallel.

```
Step 1: AppCoordinatorDependencies.swift
        → Add MediaPlaybackServiceProtocol
        → No other dependencies; do this first

Step 2: MediaPlaybackService.swift  (new file)
        → Implement service conforming to protocol
        → Depends on: Step 1 (protocol)

Step 3: AppCoordinator.swift
        → Add mediaPlayback property
        → Add 3 call sites (pause on idle→recording, resume on recording→*, resume on escape)
        → Depends on: Step 1 (protocol)

Step 4: AppDelegate.swift
        → Instantiate MediaPlaybackService
        → Wire into coordinator
        → Depends on: Steps 2 and 3

Step 5: SettingsWindowController.swift  (independent of Steps 2-4)
        → Add pausePlaybackEnabled checkbox
        → Persists to UserDefaults
        → No new dependency injection

Step 6: Unit tests
        → Mock MediaPlaybackServiceProtocol
        → Verify pause() called on .idle → .recording transition
        → Verify resume() called on .recording → * transition
        → Verify resume() called from handleEscape()
        → Verify no calls when isEnabled == false
```

---

## Anti-Patterns

### Anti-Pattern 1: Using Private MediaRemote Framework

**What people do:** `dlopen`/`dlsym` `MediaRemote.framework` and call `MRMediaRemoteSendCommand`.

**Why it's wrong:** Apple introduced entitlement verification in `mediaremoted` with macOS 15.4. Third-party apps without `com.apple.mediaremote` entitlement are denied. Cannot obtain this entitlement outside of Apple. Will silently fail or crash on current and future macOS versions.

**Do this instead:** `CGEventPost` with `NX_KEYTYPE_PLAY` — system-wide, stable, and already within the app's permission scope.

### Anti-Pattern 2: App-Specific AppleScript Targeting

**What people do:** Use `NSAppleScript` to target specific apps (`tell application "Spotify" to pause`).

**Why it's wrong:** Breaks for YouTube in browsers, podcast apps, video players, and any app not in a hardcoded list. Requires Automation permission per target app (TCC dialog). Fragile to app name changes and updates. Maintenance burden grows with the list.

**Do this instead:** The media key approach pauses whatever holds the current Now Playing session — universal, zero per-app configuration.

### Anti-Pattern 3: Tracking "Was Playing" State Before Pause

**What people do:** Check whether media is currently playing before pausing, then conditionally skip the resume call.

**Why it's wrong:** No public API provides reliable "is something currently playing" state to a non-entitled app on macOS 15.4+. The play/pause toggle is effectively idempotent in practice — if nothing is playing, pressing Play is a no-op or silently resumes from where the user last stopped (acceptable behavior). Attempting to track state requires the private MediaRemote framework.

**Trade-off to document:** If the user was already paused before starting a recording, the recording-stop event will resume their media. This is an edge case worth noting in PITFALLS.md. Accept the toggle semantics for v1.1; revisit only if user reports make it a priority.

**Do this instead:** Always send pause on recording start, always send resume on recording stop. Simpler, no private API required.

### Anti-Pattern 4: Pause Logic Inline in AppCoordinator

**What people do:** Put the `CGEventPost` call directly inside `AppCoordinator.handleHotkey()`.

**Why it's wrong:** Makes `AppCoordinator` unit tests dependent on actually posting system events. Mixes media system concern with recording FSM concern. Harder to disable in test environments.

**Do this instead:** Wrap in `MediaPlaybackService` with a protocol. Inject the protocol. The coordinator calls `mediaPlayback?.pause()` — testable with a mock that records calls.

---

## Scaling Considerations

This is a local single-user macOS app. Scalability is not a concern. The resource impact of this feature is two `CGEventPost` calls per recording session — effectively zero overhead.

---

## Sources

- Existing source code read directly from `/Users/max/Personal/repos/my-superwhisper/MyWhisper/` — HIGH confidence
- CGEventPost media key simulation pattern: [Qiita: macOS media key emulation in Swift](https://qiita.com/nak435/items/53d952147c3986afd7fc) — MEDIUM confidence (pattern independently confirmed by multiple forum sources)
- MediaRemote macOS 15.4 entitlement restriction: [GitHub: ungive/mediaremote-adapter](https://github.com/ungive/mediaremote-adapter) — MEDIUM confidence (multiple sources confirm the restriction)
- CGEventPost sandbox restriction (confirming non-sandboxed requirement is already met by this project): [Apple Developer Forums thread 103992](https://developer.apple.com/forums/thread/103992) — HIGH confidence

---

*Architecture research for: Pause Playback integration — my-superwhisper v1.1*
*Researched: 2026-03-16*
