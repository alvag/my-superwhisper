# Phase 5: Pause Playback Implementation - Research

**Researched:** 2026-03-17
**Domain:** macOS system-wide media playback control integrated into existing Swift/AppKit menubar app
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Media Control Mechanism**
- Use `NSEvent.otherEvent(with: .systemDefined, subtype: 8)` + `CGEventPost(.cghidEventTap)` with `NX_KEYTYPE_PLAY` (keyCode 16)
- Same CGEventPost mechanism already used in `TextInjector.swift` for Cmd+V simulation
- Do NOT use MediaRemote.framework — broken on macOS 15.4+ (Apple added entitlement verification)
- Do NOT use AppleScript per-app approach — too narrow, misses browsers

**Resume Timing**
- Resume media immediately when recording stops (transition from recording state), NOT after transcription/paste completes
- User prefers hearing audio resume while processing happens in background (~3-5s)
- This means resume happens at the `recording→processing` transition in AppCoordinator

**State Tracking**
- Track `pausedByApp: Bool` flag — only resume if the app was responsible for pausing
- Prevents double-toggle when user had media manually paused before recording
- Flag resets on resume or on cancel (Escape)

**Delay**
- 150ms delay between sending pause event and starting AVAudioEngine
- Spotify fade-out takes 100-200ms; without delay, fading audio bleeds into recording buffer

**Settings Toggle**
- Single checkbox/toggle: "Pausar reproduccion al grabar"
- Default: ENABLED (activado por defecto)
- Persist in UserDefaults — follows existing pattern from Phase 4
- Placement: in existing Settings panel (SettingsWindowController)

**Error Handling**
- Always resume media on any error (transcription failure, API failure, etc.)
- User should never be left without music because of an app error
- Resume on Escape cancel as well

**Edge Cases**
- Double-tap rapid hotkey: treat as normal pause/resume cycle, no minimum duration guard
- No attempt to detect if media is actually playing before sending pause — accept toggle semantics

### Claude's Discretion
- Exact protocol name and file organization for MediaPlaybackService
- Whether to use a protocol or concrete class (existing pattern uses protocols)
- Exact placement of toggle within Settings panel layout
- Label wording for the Settings toggle

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| MEDIA-01 | App pausa automáticamente la reproducción de medios al iniciar grabación | `MediaPlaybackService.pause()` called in AppCoordinator `.idle` branch before `audioRecorder?.start()` with 150ms Task.sleep before engine start |
| MEDIA-02 | App reanuda automáticamente la reproducción al terminar grabación (solo si fue pausada por la app) | `MediaPlaybackService.resume()` called in AppCoordinator `.recording` branch; `pausedByApp` flag ensures resume only happens if app caused the pause |
| MEDIA-03 | Delay de 150ms entre pausa de medios e inicio de captura de audio | `Task.sleep(.milliseconds(150))` inserted between `mediaPlayback?.pause()` and `audioRecorder?.start()` in the `.idle` case |
| MEDIA-04 | Control de medios funciona con apps del sistema y terceros (Spotify, Apple Music, VLC, navegadores) | `CGEventPost(.cghidEventTap)` with `NX_KEYTYPE_PLAY` is system-level routing — macOS sends to whichever app holds the Now Playing session; works for all compliant players |
| SETT-01 | Toggle en panel de Settings para activar/desactivar Pause Playback | `NSButton(checkboxWithTitle:)` added as Section 6 in `SettingsWindowController.show()` below the existing Launch at Login checkbox |
| SETT-02 | Preferencia persiste en UserDefaults entre sesiones | `UserDefaults.standard.set(Bool, forKey: "pausePlaybackEnabled")` written on checkbox toggle; read by MediaPlaybackService at call time |
</phase_requirements>

---

## Summary

Phase 5 adds a single well-scoped feature to an already-shipped app: automatically pause system media when recording starts, resume when recording ends. All necessary APIs are already used in the project. The core mechanism — `NSEvent.otherEvent(with: .systemDefined, subtype: 8)` + `CGEventPost(.cghidEventTap)` with `NX_KEYTYPE_PLAY` — is structurally identical to the Cmd+V simulation in `TextInjector.swift`. No new SPM packages, no new entitlements, no new permissions are required.

The implementation surface is minimal: one new file (`MediaPlaybackService.swift`, ~60 lines), three modified files (`AppCoordinator.swift`, `AppDelegate.swift`, `SettingsWindowController.swift`), one modified protocol file (`AppCoordinatorDependencies.swift`). The feature follows the FSM side-effect injection pattern already established by every other service in the codebase. The Settings toggle writes directly to `UserDefaults` with no coupling to the service, following the same pattern as `VocabularyService` and `TranscriptionHistoryService`.

The key correctness concern is the `pausedByApp` flag: the app must track whether it was responsible for pausing so it does not erroneously resume media the user had already paused before recording. This flag is tracked in `MediaPlaybackService` (set on `pause()`, cleared on `resume()`). Additionally, a 150ms delay between the pause command and `AVAudioEngine.start()` is required to prevent Spotify's fade audio from bleeding into the recording buffer. Both concerns are fully specified in the CONTEXT.md decisions.

**Primary recommendation:** Build `MediaPlaybackService` following the `VocabularyService` protocol pattern, inject it into `AppCoordinator` as an optional weak-or-strong property, call `pause()`/`resume()` at the three FSM transition points, add the UserDefaults-backed checkbox to `SettingsWindowController`.

---

## Standard Stack

### Core

| Technology | Version | Purpose | Why Standard |
|------------|---------|---------|--------------|
| AppKit (NSEvent) | macOS 13+ | Construct synthetic HID media key event | Only public mechanism for system-wide play/pause simulation. Stable since macOS 10.6. Already imported. |
| CoreGraphics (CGEvent) | macOS 13+ | Post synthetic event to HID tap | Already used in `TextInjector.swift` for Cmd+V. Same `CGEventPost` call, different tap constant. No new import. |
| IOKit.hidsystem | macOS SDK | Provides `NX_KEYTYPE_PLAY = 16` constant | Header-only import, no linker change. Defines the stable keycode constant. |
| UserDefaults | macOS SDK | Persist toggle state | Already used by VocabularyService and HistoryService via `init(defaults:)` injectable pattern. |

### Supporting

No new SPM packages. All APIs are in existing imported frameworks.

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| CGEventPost + NX_KEYTYPE_PLAY | MediaRemote.framework | MediaRemote is broken for third parties on macOS 15.4+; Apple-only entitlement required. Never use. |
| CGEventPost + NX_KEYTYPE_PLAY | NSAppleScript per-app | Requires per-app user approval; doesn't work for browsers; too narrow. Out of scope. |
| CGEventPost + NX_KEYTYPE_PLAY | MPRemoteCommandCenter | Controls only the calling app's own audio session — wrong problem entirely. |

**Installation:**
```bash
# No new packages — IOKit.hidsystem is a header-only import in Swift
import IOKit.hidsystem   // add to MediaPlaybackService.swift only
```

---

## Architecture Patterns

### Recommended Project Structure

New file location matches the `System/` folder pattern for OS-level services:

```
MyWhisper/
├── Coordinator/
│   ├── AppCoordinator.swift         # MODIFIED — add mediaPlayback property + 3 call sites
│   ├── AppCoordinatorDependencies.swift  # MODIFIED — add MediaPlaybackServiceProtocol
│   └── AppState.swift               # unchanged
├── System/
│   ├── MediaPlaybackService.swift   # NEW — all HID media key logic
│   ├── TextInjector.swift           # unchanged (reference for CGEventPost pattern)
│   └── ...
├── Settings/
│   └── SettingsWindowController.swift  # MODIFIED — add Section 6 toggle
└── App/
    └── AppDelegate.swift            # MODIFIED — instantiate + wire service
```

### Pattern 1: FSM Side-Effect Injection

**What:** `AppCoordinator` holds `var mediaPlayback: (any MediaPlaybackServiceProtocol)?` and calls `pause()`/`resume()` at state transition boundaries. All media logic lives in `MediaPlaybackService`; the coordinator only calls two methods.

**When to use:** Any external system action that must happen at a state boundary but has no bearing on state itself. Already used for `audioRecorder`, `textInjector`, `overlayController`, `haikuCleanup`.

**Exact call sites in `AppCoordinator.handleHotkey()` and `handleEscape()`:**

```swift
// Source: .planning/phases/05-pause-playback-implementation/05-CONTEXT.md

// Site 1: .idle branch — pause BEFORE audioRecorder.start(), WITH 150ms delay
case .idle:
    // ... permission checks ...
    mediaPlayback?.pause()                           // NEW
    try? await Task.sleep(for: .milliseconds(150))  // NEW — MEDIA-03
    do {
        try audioRecorder?.start()
    } catch {
        transitionTo(.error("microphone"))
        return
    }
    transitionTo(.recording)
    // ...

// Site 2: .recording branch — resume BEFORE audioRecorder.stop() (at recording→processing transition)
case .recording:
    escapeMonitor?.stopMonitoring()
    stopAudioLevelPolling()
    mediaPlayback?.resume()                          // NEW — MEDIA-02
    let buffer = audioRecorder?.stop() ?? []
    // ... rest of pipeline ...

// Site 3: handleEscape() — resume on cancel
func handleEscape() {
    guard state == .recording else { return }
    escapeMonitor?.stopMonitoring()
    stopAudioLevelPolling()
    overlayController?.hide()
    audioRecorder?.cancel()
    mediaPlayback?.resume()                          // NEW
    NSSound.beep()
    transitionTo(.idle)
}
```

### Pattern 2: Protocol-Based Dependency Injection

**What:** Add `MediaPlaybackServiceProtocol` to `AppCoordinatorDependencies.swift` following the existing protocol pattern. `MediaPlaybackService` conforms. Unit tests use `MockMediaPlaybackService`.

```swift
// Source: AppCoordinatorDependencies.swift pattern + ARCHITECTURE.md

protocol MediaPlaybackServiceProtocol: AnyObject {
    func pause()
    func resume()
    var isEnabled: Bool { get }
}
```

### Pattern 3: HID Media Key Event Construction

**What:** Construct an `NSEvent` of type `.systemDefined` with subtype 8, encoding `NX_KEYTYPE_PLAY` in the data1 field. Post key-down then key-up via `CGEvent.post(tap: .cghidEventTap)`. Identical call structure to `TextInjector.swift` but using `.cghidEventTap` instead of `.cgSessionEventTap`.

```swift
// Source: .planning/research/STACK.md (verified against Rogue Amoeba 2007 canonical reference)
import AppKit
import CoreGraphics
import IOKit.hidsystem

private func postMediaKey(down: Bool) {
    let flags = NSEvent.ModifierFlags(rawValue: down ? 0xA00 : 0xB00)
    let data1 = (Int(NX_KEYTYPE_PLAY) << 16) | (down ? 0xA00 : 0xB00)
    guard let event = NSEvent.otherEvent(
        with: .systemDefined,
        location: .zero,
        modifierFlags: flags,
        timestamp: ProcessInfo.processInfo.systemUptime,
        windowNumber: 0,
        context: nil,
        subtype: 8,
        data1: data1,
        data2: -1
    ) else { return }
    event.cgEvent?.post(tap: .cghidEventTap)
}

// Call pair for one play/pause toggle:
postMediaKey(down: true)
postMediaKey(down: false)
```

### Pattern 4: UserDefaults at Call Time (No Subscription)

**What:** `MediaPlaybackService` reads `UserDefaults.standard.bool(forKey: "pausePlaybackEnabled")` at the moment `pause()` or `resume()` is called. Default is `true` (`bool(forKey:)` returns `false` for unset keys, so the key must be registered or the isEnabled logic must treat missing as `true`).

**Implementation note:** Since `UserDefaults.standard.bool(forKey:)` returns `false` for an unset key, and the default should be `true`, the service must handle this:

```swift
// Option A: Register default at app launch in AppDelegate
UserDefaults.standard.register(defaults: ["pausePlaybackEnabled": true])

// Option B: Read with explicit default
var isEnabled: Bool {
    UserDefaults.standard.object(forKey: "pausePlaybackEnabled") == nil
        ? true
        : UserDefaults.standard.bool(forKey: "pausePlaybackEnabled")
}
```

Option A (register defaults) is the standard macOS pattern and keeps `isEnabled` simple.

### Pattern 5: pausedByApp Flag

**What:** `MediaPlaybackService` tracks `private var pausedByApp = false`. Set to `true` in `pause()`, reset in `resume()`. The `resume()` method only sends the media key if `pausedByApp == true`.

```swift
// Source: .planning/research/ARCHITECTURE.md

final class MediaPlaybackService: MediaPlaybackServiceProtocol {
    private var pausedByApp = false

    func pause() {
        guard isEnabled else { return }
        sendMediaKey()
        pausedByApp = true
    }

    func resume() {
        guard isEnabled, pausedByApp else { return }
        sendMediaKey()
        pausedByApp = false
    }
}
```

### Pattern 6: Settings Toggle (NSButton checkbox, Section 6)

**What:** Add a checkbox below the existing "Iniciar al arranque" checkbox in `SettingsWindowController`. Writes directly to UserDefaults. No reference to `MediaPlaybackService` required.

```swift
// Source: .planning/research/ARCHITECTURE.md
// Pattern follows launchAtLoginCheckbox (line 140 in SettingsWindowController.swift)

let pauseCheckbox = NSButton(
    checkboxWithTitle: "Pausar reproducción al grabar",
    target: self,
    action: #selector(pausePlaybackChanged(_:))
)
pauseCheckbox.translatesAutoresizingMaskIntoConstraints = false
pauseCheckbox.state = UserDefaults.standard.object(forKey: "pausePlaybackEnabled") == nil
    ? .on
    : UserDefaults.standard.bool(forKey: "pausePlaybackEnabled") ? .on : .off
contentView.addSubview(pauseCheckbox)

// Auto layout: pin below launchAtLoginCheckbox, same leading, add bottom constraint
pauseCheckbox.topAnchor.constraint(equalTo: launchAtLoginCheckbox.bottomAnchor, constant: 10)
pauseCheckbox.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20)
pauseCheckbox.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -20)

@objc private func pausePlaybackChanged(_ sender: NSButton) {
    UserDefaults.standard.set(sender.state == .on, forKey: "pausePlaybackEnabled")
}
```

**Note:** The current panel height is 520. Adding one checkbox row (~28px) plus padding requires increasing panel height to ~560. Update `NSRect(x: 0, y: 0, width: 480, height: 520)` to `height: 560`.

### Anti-Patterns to Avoid

- **MediaRemote via dlopen:** Broken on macOS 15.4+. Silent failures. Never introduce.
- **Inline CGEventPost in AppCoordinator:** Makes coordinator untestable with real system events. Wrap in service.
- **Checking playback state before pause:** No reliable public API on macOS 15.4+. Use the `pausedByApp` flag approach instead.
- **Reading UserDefaults in AppCoordinator:** The service owns this logic. Coordinator calls `pause()`/`resume()` unconditionally — the guard lives inside the service.
- **Using `.cgSessionEventTap` for media keys:** Use `.cghidEventTap` for media keys. `.cgSessionEventTap` is correct for paste simulation (TextInjector). Different tap for different purpose.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| System-wide play/pause | Custom AudioSession or process injection | `CGEventPost(.cghidEventTap)` + `NX_KEYTYPE_PLAY` | macOS routes HID events to Now Playing owner automatically; no app-specific logic needed |
| Detecting if media is playing | MediaRemote dlopen | `pausedByApp` flag (track own actions) | No reliable public API post-macOS 15.4; flag is simpler and correct for the defined requirement |
| Per-app media targeting | AppleScript list or process enumeration | Out of scope for v1.1 | Toggle semantics + Settings toggle cover the requirement; per-app is v1.2 |

**Key insight:** The play/pause hardware key toggle is idempotent at the user level — if nothing is playing, most apps silently ignore the play event. The `pausedByApp` flag prevents the double-resume edge case without requiring any playback state detection.

---

## Common Pitfalls

### Pitfall 1: Wrong CGEvent Tap Constant

**What goes wrong:** Using `.cgSessionEventTap` (from TextInjector) for media keys. Media key events must use `.cghidEventTap` or they do not route correctly to the Now Playing application.

**Why it happens:** TextInjector uses `.cgSessionEventTap` for Cmd+V — developer copies the pattern without noticing the tap difference.

**How to avoid:** Media keys → `.cghidEventTap`. Keyboard/mouse events → `.cgSessionEventTap`. This is not negotiable.

**Warning signs:** Media key posts succeed (no crash) but the player does not respond.

### Pitfall 2: Missing 150ms Delay (Audio Bleed)

**What goes wrong:** Sending pause and immediately calling `audioRecorder?.start()` causes Spotify's 100-200ms fade audio to enter the recording buffer. The STT model receives music noise instead of silence at the start of every recording, degrading first-word accuracy.

**Why it happens:** The CGEventPost is synchronous from the app's perspective, but the media player's response is asynchronous. The engine starts capturing before the fade completes.

**How to avoid:** `try? await Task.sleep(for: .milliseconds(150))` between `mediaPlayback?.pause()` and `audioRecorder?.start()` in the `.idle` branch. This is a locked decision — do not skip.

**Warning signs:** First word of transcription is consistently garbled or missing; raw recording buffer shows non-silent signal before speech.

### Pitfall 3: Double-Toggle When Nothing Was Playing

**What goes wrong:** If the user had no media playing, sending pause is a no-op (most apps). But `pausedByApp` flag is set to `true`. On recording stop, a resume is sent — this could resume whatever was last played (behavior varies by player). Some players do nothing; Apple Music may start playing.

**Why it happens:** The app cannot detect whether media was playing without the broken MediaRemote API. The toggle semantics accept this trade-off.

**How to avoid:** The locked decision is to accept toggle semantics. The Settings toggle gives users an escape hatch. If Apple Music launching unexpectedly becomes a user complaint, the v1.2 mitigation is an AppleScript check specifically for Music.app state.

**Warning signs:** Apple Music starts playing when no music was on before recording.

### Pitfall 4: UserDefaults Default Value Trap

**What goes wrong:** `UserDefaults.standard.bool(forKey: "pausePlaybackEnabled")` returns `false` for a key that was never set. The feature is ON by default per the locked decision, but without `register(defaults:)`, first-launch behavior is OFF.

**Why it happens:** `bool(forKey:)` returns `false` for missing keys, not `nil`. Developers assume the feature defaults to on without registering the default.

**How to avoid:** Call `UserDefaults.standard.register(defaults: ["pausePlaybackEnabled": true])` in `AppDelegate.applicationDidFinishLaunching` before any service reads this key.

**Warning signs:** Feature appears disabled on first launch even though Settings shows "on" after user opens it; behavior changes after first Settings open.

### Pitfall 5: Resume Not Called on Error Paths

**What goes wrong:** Transcription fails or API errors out. Music stays paused because the error path exits without calling `mediaPlayback?.resume()`.

**Why it happens:** The catch block in `AppCoordinator.handleHotkey()` transitions to `.idle` without resuming media.

**How to avoid:** Per the locked decision: always resume on any error. The resume call must be added to BOTH the transcription error catch (line 141-147 in current AppCoordinator) and the general error path. Since resume is now called at the `recording→processing` transition (before the `audioRecorder?.stop()` call), this is already handled for normal stop. Verify the VAD gate path also resumes (currently it returns to `.idle` without a `processing` transition — if user presses hotkey and VAD detects silence, the recording started, so music was paused; it must resume).

**Warning signs:** After a failed transcription or silent recording, music stays paused; user has to manually resume.

### Pitfall 6: VAD-Silent Path Does Not Resume

**What goes wrong:** The current `.recording` branch in AppCoordinator has a VAD gate that returns early (line 72-77) if no speech is detected. If `mediaPlayback?.resume()` is called before `audioRecorder?.stop()`, this path is covered. But if the order is different, the VAD early-return path exits to `.idle` without resuming.

**How to avoid:** Place `mediaPlayback?.resume()` BEFORE the `audioRecorder?.stop()` call — not after. This means ALL exit paths from the `.recording` branch (VAD fail, transcription error, success) will have already resumed media before reaching their respective returns.

**Current code location:** `.recording` case, line 64 — the resume call must be the FIRST statement after `stopAudioLevelPolling()`.

---

## Code Examples

### Complete MediaPlaybackService

```swift
// Source: .planning/research/ARCHITECTURE.md + STACK.md
import AppKit
import CoreGraphics
import IOKit.hidsystem

final class MediaPlaybackService: MediaPlaybackServiceProtocol {
    private var pausedByApp = false

    var isEnabled: Bool {
        // register(defaults:) ensures this returns true when unset
        UserDefaults.standard.bool(forKey: "pausePlaybackEnabled")
    }

    func pause() {
        guard isEnabled else { return }
        postMediaKeyToggle()
        pausedByApp = true
    }

    func resume() {
        guard pausedByApp else { return }
        pausedByApp = false
        guard isEnabled else { return }
        postMediaKeyToggle()
    }

    private func postMediaKeyToggle() {
        postKey(down: true)
        postKey(down: false)
    }

    private func postKey(down: Bool) {
        let flags = NSEvent.ModifierFlags(rawValue: down ? 0xA00 : 0xB00)
        let data1 = (Int(NX_KEYTYPE_PLAY) << 16) | (down ? 0xA00 : 0xB00)
        guard let event = NSEvent.otherEvent(
            with: .systemDefined,
            location: .zero,
            modifierFlags: flags,
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: 0,
            context: nil,
            subtype: 8,
            data1: data1,
            data2: -1
        ) else { return }
        event.cgEvent?.post(tap: .cghidEventTap)
    }
}
```

### AppCoordinator .idle Branch (with media pause)

```swift
// Source: existing AppCoordinator.swift line 52-62 + 05-CONTEXT.md integration points
case .idle:
    // ... permission and API key checks ...

    // Pause media BEFORE starting audio engine (MEDIA-01, MEDIA-03)
    mediaPlayback?.pause()
    try? await Task.sleep(for: .milliseconds(150))

    do {
        try audioRecorder?.start()
    } catch {
        transitionTo(.error("microphone"))
        return
    }
    transitionTo(.recording)
    escapeMonitor?.startMonitoring()
    overlayController?.show()
    startAudioLevelPolling()
```

### AppCoordinator .recording Branch (with media resume)

```swift
// Source: existing AppCoordinator.swift line 64-81 + 05-CONTEXT.md integration points
case .recording:
    escapeMonitor?.stopMonitoring()
    stopAudioLevelPolling()
    mediaPlayback?.resume()   // MEDIA-02 — resume BEFORE stop/VAD so all exit paths covered

    let buffer = audioRecorder?.stop() ?? []
    guard VAD.hasSpeech(in: buffer) else {
        overlayController?.hide()
        NotificationHelper.show(title: "No se detecto voz")
        transitionTo(.idle)
        return  // media already resumed above
    }
    // ... rest of pipeline ...
```

### Mock for Unit Tests

```swift
// Follows existing Mock pattern in AppCoordinatorTests.swift
final class MockMediaPlaybackService: MediaPlaybackServiceProtocol {
    var pauseCallCount = 0
    var resumeCallCount = 0
    var isEnabled: Bool = true

    func pause()  { pauseCallCount += 1 }
    func resume() { resumeCallCount += 1 }
}
```

### AppDelegate Wiring

```swift
// Source: existing AppDelegate.swift pattern, after line 70
UserDefaults.standard.register(defaults: ["pausePlaybackEnabled": true])
let mediaPlaybackService = MediaPlaybackService()
coordinator.mediaPlayback = mediaPlaybackService
self.mediaPlaybackService = mediaPlaybackService
```

---

## Build Order

```
Step 1: AppCoordinatorDependencies.swift
        → Add MediaPlaybackServiceProtocol (pause, resume, isEnabled)
        → No other file depends on this yet; do first

Step 2: MediaPlaybackService.swift  (new file in MyWhisper/System/)
        → Implements MediaPlaybackServiceProtocol
        → Depends on Step 1

Step 3: AppCoordinator.swift
        → Add `var mediaPlayback: (any MediaPlaybackServiceProtocol)?` property
        → Add pause call in .idle branch (with 150ms delay)
        → Add resume call in .recording branch (before audioRecorder?.stop())
        → Add resume call in handleEscape()
        → Depends on Step 1

Step 4: AppDelegate.swift
        → register UserDefaults default for "pausePlaybackEnabled"
        → Instantiate MediaPlaybackService
        → Assign to coordinator.mediaPlayback
        → Store strong reference
        → Depends on Steps 2 and 3

Step 5: SettingsWindowController.swift  (independent of Steps 2-4)
        → Add pauseCheckbox NSButton after launchAtLoginCheckbox
        → Add pausePlaybackChanged @objc action
        → Update panel height 520 → 560
        → Update bottom anchor from addButton to pauseCheckbox
        → No new init parameter or dependency injection

Step 6: Unit tests
        → MockMediaPlaybackService in AppCoordinatorTests.swift
        → Test: pause called once when idle→recording
        → Test: resume called once when recording stops normally
        → Test: resume called once when handleEscape fires
        → Test: pause NOT called when isEnabled = false
        → Test: resume NOT called when isEnabled = false (but pausedByApp flag resets)
        → Test: resume NOT called when pausedByApp = false (no double-resume)
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| MediaRemote.framework (dlopen) | CGEventPost + NX_KEYTYPE_PLAY | macOS 15.4 (2024) | MediaRemote broken for 3rd parties; CGEvent is now the only reliable public mechanism |
| Always send resume on stop | Track pausedByApp flag, conditional resume | v1.1 design decision | Prevents double-toggle UX issue when user had media paused before recording |

**Deprecated/outdated:**
- `MediaRemote.framework` via dlopen: silently broken for non-Apple apps on macOS 15.4+. Apps like LyricsX broke overnight. Do not use.
- `MPNowPlayingInfoCenter` / `MPRemoteCommandCenter`: for registering YOUR app as a Now Playing participant, not for controlling other apps.

---

## Open Questions

1. **Apple Music spontaneous launch on first pause when nothing playing**
   - What we know: Sending play/pause when nothing plays is a no-op for most apps. Apple Music may start playing.
   - What's unclear: Behavior is environment-specific. Cannot verify without manual testing.
   - Recommendation: Validate empirically during integration testing. If Music.app launches unexpectedly, add an AppleScript guard: `tell application "Music" to player state` before the first pause. Document in Settings tooltip as known limitation regardless.

2. **Browser media resume reliability (Chrome)**
   - What we know: Chrome's Web Media Session implementation may require tab focus for resume to work via media keys.
   - What's unclear: Confirmed problematic in some configurations, fine in others.
   - Recommendation: Test YouTube/Chrome during verification. If unreliable, add Settings hint: "Funciona mejor con apps nativas como Spotify y Apple Music."

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | XCTest (existing, no config file needed) |
| Config file | None — Xcode scheme `MyWhisperTests` |
| Quick run command | `xcodebuild test -scheme MyWhisper -only-testing:MyWhisperTests/AppCoordinatorTests -destination 'platform=macOS' 2>&1 \| tail -20` |
| Full suite command | `xcodebuild test -scheme MyWhisper -destination 'platform=macOS' 2>&1 \| tail -30` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| MEDIA-01 | `pause()` called once when idle→recording | unit | `xcodebuild test -scheme MyWhisper -only-testing:MyWhisperTests/AppCoordinatorTests/testMediaPausedOnRecordingStart` | ❌ Wave 0 |
| MEDIA-02 | `resume()` called only if `pausedByApp == true` | unit | `xcodebuild test -scheme MyWhisper -only-testing:MyWhisperTests/AppCoordinatorTests/testMediaResumedOnRecordingStop` | ❌ Wave 0 |
| MEDIA-02 | `resume()` NOT called if nothing was paused | unit | `xcodebuild test -scheme MyWhisper -only-testing:MyWhisperTests/AppCoordinatorTests/testMediaNotResumedIfNotPaused` | ❌ Wave 0 |
| MEDIA-03 | 150ms delay present before audioRecorder.start() | unit | Manual timing verification + log assertion | manual-only |
| MEDIA-04 | CGEventPost uses `.cghidEventTap` not `.cgSessionEventTap` | unit | Code review (tap constant correctness) | manual-only |
| SETT-01 | Toggle OFF → no pause/resume calls during recording | unit | `xcodebuild test -scheme MyWhisper -only-testing:MyWhisperTests/AppCoordinatorTests/testMediaToggleOffSkipsPauseResume` | ❌ Wave 0 |
| SETT-02 | UserDefaults key persists across MediaPlaybackService instances | unit | `xcodebuild test -scheme MyWhisper -only-testing:MyWhisperTests/MediaPlaybackServiceTests/testTogglePersistedInUserDefaults` | ❌ Wave 0 |
| (escape) | `resume()` called on Escape cancel | unit | `xcodebuild test -scheme MyWhisper -only-testing:MyWhisperTests/AppCoordinatorTests/testMediaResumedOnEscapeCancel` | ❌ Wave 0 |
| (error) | `resume()` called on transcription error | unit | `xcodebuild test -scheme MyWhisper -only-testing:MyWhisperTests/AppCoordinatorTests/testMediaResumedOnTranscriptionError` | ❌ Wave 0 |

### Sampling Rate

- **Per task commit:** `xcodebuild test -scheme MyWhisper -only-testing:MyWhisperTests/AppCoordinatorTests -destination 'platform=macOS' 2>&1 | tail -20`
- **Per wave merge:** `xcodebuild test -scheme MyWhisper -destination 'platform=macOS' 2>&1 | tail -30`
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps

- [ ] `MyWhisperTests/MediaPlaybackServiceTests.swift` — covers SETT-02, pausedByApp flag unit tests, isEnabled UserDefaults default
- [ ] `MockMediaPlaybackService` in `MyWhisperTests/AppCoordinatorTests.swift` — covers MEDIA-01, MEDIA-02, SETT-01, escape, error path tests

*(Existing `AppCoordinatorTests.swift` will be extended; new `MediaPlaybackServiceTests.swift` will be created)*

---

## Sources

### Primary (HIGH confidence)
- Existing codebase (`AppCoordinator.swift`, `TextInjector.swift`, `AppCoordinatorDependencies.swift`, `AppDelegate.swift`, `SettingsWindowController.swift`) — read directly from `/Users/max/Personal/repos/my-superwhisper/MyWhisper/`
- `.planning/research/STACK.md` — HID media key pattern with full verified Swift code
- `.planning/research/ARCHITECTURE.md` — Component design, data flow, all integration points with exact line numbers
- `.planning/research/PITFALLS.md` — 7 pitfalls with warning signs and recovery strategies
- `.planning/research/SUMMARY.md` — Executive synthesis of all v1.1 research
- `.planning/phases/05-pause-playback-implementation/05-CONTEXT.md` — All locked decisions

### Secondary (MEDIUM confidence)
- [Rogue Amoeba: Apple Keyboard Media Key Event Handling (2007)](https://weblog.rogueamoeba.com/2007/09/29/apple-keyboard-media-key-event-handling/) — canonical NSEvent systemDefined subtype 8 reference, still accurate
- [MediaRemote breakage on macOS 15.4 — feedback-assistant/reports #637](https://github.com/feedback-assistant/reports/issues/637) — community tracking with multiple confirmations
- [BackgroundMusic source (kyleneideck)](https://github.com/kyleneideck/BackgroundMusic) — open source reference confirming HID media key approach
- [SuperWhisper changelog](https://superwhisper.com/changelog) — feature added v1.44.0 Jan 2025, default in v2.7.0 Nov 2025

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all APIs are existing imports; `TextInjector.swift` confirms CGEventPost works without new entitlements in this exact codebase
- Architecture: HIGH — existing source code read directly; all integration points identified with line numbers; component boundaries follow established codebase patterns
- Pitfalls: HIGH (MediaRemote, delay, flag, tap constant) / MEDIUM (browser compat specifics, Apple Music launch edge case) — implementation pitfalls verified via production code; browser behavior requires empirical validation

**Research date:** 2026-03-17
**Valid until:** 2026-04-17 (stable APIs; macOS system behavior unlikely to change in 30 days)
