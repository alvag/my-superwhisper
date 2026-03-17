# Architecture Research

**Domain:** v1.2 feature integration — Haiku prompt fix + mic input volume control
**Researched:** 2026-03-17
**Confidence:** HIGH (existing codebase read directly; CoreAudio volume API pattern confirmed via official Apple docs and existing MicrophoneDeviceService pattern in codebase)

---

## System Overview — v1.2 with New Features

```
┌──────────────────────────────────────────────────────────────────┐
│                       AppDelegate (wiring)                        │
├──────────────────────────────────────────────────────────────────┤
│  ┌───────────────┐  ┌────────────────┐  ┌────────────────────┐   │
│  │ HotkeyMonitor │  │  EscapeMonitor │  │  MenubarController │   │
│  └──────┬────────┘  └───────┬────────┘  └─────────┬──────────┘   │
│         │                  │                      │               │
├─────────▼──────────────────▼──────────────────────▼──────────────┤
│                      AppCoordinator (FSM)                         │
│              idle ↔ recording ↔ processing ↔ error                │
│                                                                   │
│   ON ENTER recording: mediaPlayback?.pause()                      │
│                       micVolumeService?.maximizeAndSave()  [NEW]  │
│   ON EXIT  recording: mediaPlayback?.resume()                     │
│                       micVolumeService?.restore()          [NEW]  │
│   ON ESCAPE cancel:   mediaPlayback?.resume()                     │
│                       micVolumeService?.restore()          [NEW]  │
├──────────────────────────────────────────────────────────────────┤
│  ┌────────────────┐ ┌────────────┐ ┌─────────────────────────┐   │
│  │  AudioRecorder │ │ STTEngine  │ │  HaikuCleanupService     │   │
│  │                │ │            │ │  [MODIFIED — prompt fix] │   │
│  └────────────────┘ └────────────┘ └─────────────────────────┘   │
│  ┌────────────────┐ ┌────────────┐ ┌────────────────────────┐    │
│  │  TextInjector  │ │VocabService│ │    HistoryService       │    │
│  └────────────────┘ └────────────┘ └────────────────────────┘    │
│  ┌────────────────────────────────┐                              │
│  │  MediaPlaybackService (v1.1)   │                              │
│  └────────────────────────────────┘                              │
│  ┌────────────────────────────────┐                              │
│  │  MicInputVolumeService  [NEW]  │                              │
│  │  CoreAudio: get/set volume on  │                              │
│  │  kAudioDevicePropertyScopeInput│                              │
│  └────────────────────────────────┘                              │
└──────────────────────────────────────────────────────────────────┘
```

---

## New vs Modified Components

### Feature 1: Haiku Prompt Fix ("gracias" phantom suffix)

**What changes:** `HaikuCleanupService.swift` only — the system prompt string.

**Root cause:** The current system prompt ends with rule 5 ("PROHIBIDO") but does not explicitly forbid appending closing phrases. Haiku occasionally adds a Spanish conversational sign-off ("gracias", "hasta luego", etc.) that mimics a well-formed dictation ending. A single explicit rule eliminates this.

**Change:** Add one rule to the `systemPrompt` string inside `HaikuCleanupService`:

```swift
// Add as Rule 6 in the existing numbered list:
"6. CIERRE: NO añadas palabras de despedida ni agradecimiento al final \
(\"gracias\", \"hasta luego\", etc.) salvo que estén en el texto original."
```

No protocol changes. No new types. No wiring changes. The `HaikuCleanupProtocol` signature is unaffected.

**File touched:** `MyWhisper/Cleanup/HaikuCleanupService.swift` (systemPrompt string only)

---

### Feature 2: Mic Input Volume — New Service

**What changes:**

| Change | File | Type |
|--------|------|------|
| New protocol `MicInputVolumeServiceProtocol` | `AppCoordinatorDependencies.swift` | Modified |
| New service `MicInputVolumeService` | `MyWhisper/Audio/MicInputVolumeService.swift` | New |
| New coordinator property + 3 call sites | `AppCoordinator.swift` | Modified |
| Wire service at startup | `AppDelegate.swift` | Modified |

#### Protocol (added to `AppCoordinatorDependencies.swift`)

```swift
protocol MicInputVolumeServiceProtocol: AnyObject {
    /// Read current input volume, store it, then set input volume to 1.0.
    func maximizeAndSave()
    /// Restore the input volume saved by the last maximizeAndSave() call.
    func restore()
}
```

Kept minimal — coordinator needs only these two operations. The saved volume is internal state of the service.

#### `MicInputVolumeService` implementation sketch

```swift
final class MicInputVolumeService: MicInputVolumeServiceProtocol {
    private var savedVolume: Float32? = nil
    private let microphoneService: MicrophoneDeviceService

    init(microphoneService: MicrophoneDeviceService) {
        self.microphoneService = microphoneService
    }

    func maximizeAndSave() {
        guard let deviceID = resolveActiveDeviceID() else { return }
        savedVolume = getVolume(deviceID: deviceID)
        setVolume(1.0, deviceID: deviceID)
    }

    func restore() {
        guard let volume = savedVolume,
              let deviceID = resolveActiveDeviceID() else { return }
        setVolume(volume, deviceID: deviceID)
        savedVolume = nil
    }

    private func resolveActiveDeviceID() -> AudioDeviceID? {
        // Prefer the user-selected device (mirrors AudioRecorder selection logic).
        // Fall back to system default input device if none selected.
        if let selected = microphoneService.selectedDeviceID {
            let available = microphoneService.availableInputDevices().map(\.id)
            if available.contains(selected) { return selected }
        }
        return systemDefaultInputDeviceID()
    }

    private func systemDefaultInputDeviceID() -> AudioDeviceID? {
        var deviceID = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        guard AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address, 0, nil, &size, &deviceID
        ) == noErr, deviceID != kAudioDeviceUnknown else { return nil }
        return deviceID
    }

    private func getVolume(deviceID: AudioDeviceID) -> Float32? {
        var volume = Float32(0)
        var size = UInt32(MemoryLayout<Float32>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
        guard AudioObjectGetPropertyData(
            deviceID, &address, 0, nil, &size, &volume
        ) == noErr else { return nil }
        return volume
    }

    private func setVolume(_ volume: Float32, deviceID: AudioDeviceID) {
        var vol = volume
        let size = UInt32(MemoryLayout<Float32>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectSetPropertyData(deviceID, &address, 0, nil, size, &vol)
    }
}
```

**Key design decisions:**

- Uses the same `MicrophoneDeviceService` that `AudioRecorder` already uses for device selection. No new device resolution logic; no duplicate code.
- `savedVolume` is instance state. If the app crashes after `maximizeAndSave()` but before `restore()`, the OS keeps the volume at 1.0 — acceptable risk for a desktop utility.
- `kAudioObjectPropertyElementMain` (element 0) targets the master channel. This is correct for consumer microphones. Multi-channel interfaces may require per-channel iteration — flag as a known edge case (see PITFALLS).
- No `isSettable` guard in the sketch; add `AudioObjectIsPropertySettable` check before `AudioObjectSetPropertyData` if some devices return errors. Silent failure on `setVolume` is acceptable — worst case: volume is not changed.
- No new entitlements required. `AudioObjectGetPropertyData` / `AudioObjectSetPropertyData` for device volume are available to non-sandboxed apps. (The app is already Developer ID signed and non-sandboxed.)

---

## Modified: `AppCoordinator.swift`

Add one stored property:

```swift
var micVolumeService: (any MicInputVolumeServiceProtocol)?
```

Add call sites within `handleHotkey()` and `handleEscape()`:

| Location | Call | Rationale |
|----------|------|-----------|
| `.idle` branch — after `mediaPlayback?.pause()`, before `audioRecorder?.start()` | `micVolumeService?.maximizeAndSave()` | Maximize before engine starts so volume takes effect during capture |
| `.recording` branch — after `mediaPlayback?.resume()`, before `audioRecorder?.stop()` | `micVolumeService?.restore()` | Restore as soon as recording ends, before processing begins |
| `handleEscape()` — after `mediaPlayback?.resume()` | `micVolumeService?.restore()` | Restore on cancel path as well |

---

## Modified: `AppDelegate.swift`

Add stored property:

```swift
private var micInputVolumeService: MicInputVolumeService?
```

In `applicationDidFinishLaunching`, after `microphoneService` is initialized:

```swift
let micInputVolumeService = MicInputVolumeService(microphoneService: microphoneService)
coordinator.micVolumeService = micInputVolumeService
self.micInputVolumeService = micInputVolumeService
```

`MicInputVolumeService` depends on `MicrophoneDeviceService` (already instantiated). No other dependency changes.

---

## Data Flow

### Recording Start (idle → recording)

```
User presses Option+Space  [state: .idle]
    ↓
AppCoordinator.handleHotkey()
    ↓  permission check + API key check pass
mediaPlayback?.pause()                     (v1.1 — pause media)
    ↓  150ms sleep (existing)
micVolumeService?.maximizeAndSave()        [NEW — read+save current volume, set to 1.0]
    → resolveActiveDeviceID()              (selected or system default)
    → getVolume() via AudioObjectGetPropertyData(kAudioDevicePropertyVolumeScalar)
    → save to savedVolume
    → setVolume(1.0) via AudioObjectSetPropertyData
    ↓
audioRecorder?.start()                     (engine starts, mic now at max volume)
transitionTo(.recording)
```

### Recording Stop (recording → processing)

```
User presses Option+Space  [state: .recording]
    ↓
AppCoordinator.handleHotkey()
escapeMonitor?.stopMonitoring()
stopAudioLevelPolling()
mediaPlayback?.resume()                    (v1.1 — resume media)
micVolumeService?.restore()               [NEW — restore saved volume]
    → getVolume: use savedVolume
    → setVolume(savedVolume) via AudioObjectSetPropertyData
    → savedVolume = nil
    ↓
audioRecorder?.stop() → VAD → transcription → Haiku cleanup → paste
```

### Escape Cancel

```
User presses Escape  [state: .recording]
    ↓
AppCoordinator.handleEscape()
escapeMonitor?.stopMonitoring()
stopAudioLevelPolling()
overlayController?.hide()
audioRecorder?.cancel()
mediaPlayback?.resume()                    (v1.1)
micVolumeService?.restore()               [NEW]
NSSound.beep()
transitionTo(.idle)
```

### Haiku Cleanup (unchanged flow, prompt only)

```
rawText (from WhisperKit)
    ↓
HaikuCleanupService.clean(rawText)
    → system prompt now includes Rule 6: no closing phrases
    → Haiku returns corrected text without phantom "gracias"
    ↓
vocabularyService.apply(to: cleanedText)
    ↓
textInjector?.inject(correctedText)
```

---

## Component Boundaries

| Component | Responsibility | Communicates With |
|-----------|----------------|-------------------|
| `MicInputVolumeService` | Read/save/restore CoreAudio input volume for the active device | `MicrophoneDeviceService` (device resolution), CoreAudio HAL |
| `MicrophoneDeviceService` | Device enumeration and selection persistence | `MicInputVolumeService`, `AudioRecorder`, Settings UI |
| `AppCoordinator` | FSM orchestration; calls `micVolumeService` at state boundaries | `MicInputVolumeService` (via protocol), all other services |
| `HaikuCleanupService` | Text cleanup via Anthropic API | Anthropic API, `KeychainService` |
| `AppDelegate` | Wiring; owns strong references to all services | All services |

---

## Architectural Patterns

### Pattern 1: FSM Side-Effect Injection (same as v1.1 MediaPlayback)

**What:** `AppCoordinator` holds a protocol reference injected by `AppDelegate`. Side effects at state boundaries are delegated to specialized services.

**When to use:** Any external system action at a state transition boundary that has no bearing on the FSM state itself.

**Trade-offs:** Coordinator stays focused and testable. Services are independently mockable.

### Pattern 2: Symmetric Save/Restore

**What:** `MicInputVolumeService.maximizeAndSave()` atomically reads the current value and saves it before mutating. `restore()` writes the saved value back and clears it. The pair is always called at the same FSM boundary (one on enter recording, one on exit recording).

**When to use:** Any resource that must be temporarily overridden and then returned to its original state.

**Trade-offs:** Saved state is instance-scoped, not persisted. Crash between save and restore leaves mic at 1.0. Acceptable for this use case — the OS resets mic volume to user preference after reboot; the volume setting persists in System Preferences, not in app state.

### Pattern 3: Prompt Rule Addition (Haiku)

**What:** Add an explicit numbered rule to the existing system prompt. Do not restructure the prompt or change other rules.

**When to use:** When Claude adds content that is not in the input and the system prompt does not explicitly forbid it. A direct prohibition in the same format as existing rules is the lowest-risk fix.

**Trade-offs:** Minimal prompt change reduces regression risk. No model version change. No API contract change. Easy to test by sending a known transcription through the cleaned pipeline.

---

## Build Order

Dependencies determine order. Feature 1 (Haiku fix) and Feature 2 (mic volume) are fully independent and can be built in parallel.

```
FEATURE 1 — Haiku Prompt Fix (no dependencies)

  Step 1: HaikuCleanupService.swift
          → Add Rule 6 to systemPrompt
          → No protocol changes, no wiring changes
          → Self-contained; testable by sending a transcription through clean()

FEATURE 2 — Mic Input Volume (has internal dependencies)

  Step 2: AppCoordinatorDependencies.swift
          → Add MicInputVolumeServiceProtocol
          → Must come first; both Service and Coordinator depend on this

  Step 3: MicInputVolumeService.swift  (new file in MyWhisper/Audio/)
          → Implement service conforming to MicInputVolumeServiceProtocol
          → Depends on: Step 2 (protocol) + MicrophoneDeviceService (already exists)

  Step 4: AppCoordinator.swift
          → Add micVolumeService property
          → Add 3 call sites (maximizeAndSave on idle→recording, restore on recording→*, restore on escape)
          → Depends on: Step 2 (protocol)

  Step 5: AppDelegate.swift
          → Instantiate MicInputVolumeService(microphoneService: microphoneService)
          → Wire: coordinator.micVolumeService = micInputVolumeService
          → Depends on: Steps 3 and 4

TESTING

  Step 6 (Feature 1): Unit test for HaikuCleanupService
          → Mock URLSession to return a Haiku-style response with "gracias" appended
          → Verify clean() strips it

  Step 7 (Feature 2): Unit tests for AppCoordinator
          → Mock MicInputVolumeServiceProtocol
          → Verify maximizeAndSave() called when transitioning idle→recording
          → Verify restore() called on recording→processing transition
          → Verify restore() called from handleEscape()
```

---

## Anti-Patterns

### Anti-Pattern 1: Using AVAudioSession for Volume (iOS API)

**What people do:** Call `AVAudioSession.sharedInstance().setInputGain()` to control mic volume.

**Why it's wrong:** `AVAudioSession` input gain is an iOS/iPadOS API. On macOS it is unavailable. The macOS equivalent is CoreAudio HAL via `AudioObjectSetPropertyData`.

**Do this instead:** `AudioObjectSetPropertyData` with `kAudioDevicePropertyVolumeScalar` and `kAudioDevicePropertyScopeInput`.

### Anti-Pattern 2: Re-resolving the Device ID in MicInputVolumeService Independently

**What people do:** Duplicate device-enumeration logic inside `MicInputVolumeService` instead of delegating to `MicrophoneDeviceService`.

**Why it's wrong:** Creates two sources of truth for which device is active. If the user changes the selected device in Settings, the AudioRecorder and MicInputVolumeService would target different devices.

**Do this instead:** Inject `MicrophoneDeviceService` and call `selectedDeviceID` / `availableInputDevices()` from there. Mirror the same fallback logic as `AudioRecorder.start()`.

### Anti-Pattern 3: Saving Volume in UserDefaults

**What people do:** Persist the saved mic volume to UserDefaults so it survives a crash.

**Why it's wrong:** Adds a stale-state risk: if the user changed mic volume between the crash and relaunch, restoring a stale value would be worse than doing nothing. The physical System Preferences value is the real source of truth. Let the OS own it.

**Do this instead:** Keep `savedVolume` as instance-scoped `Float32?`. On cold launch, `savedVolume` is `nil`, so `restore()` is a no-op. No stale state possible.

### Anti-Pattern 4: Addressing a Specific Element Channel for Consumer Mics

**What people do:** Iterate all channels (elements > 0) and set each individually, assuming element 0 (main) is always wrong.

**Why it's wrong:** `kAudioObjectPropertyElementMain` (value 0) is the master/main element and is the correct target for per-device volume on consumer microphones. Per-channel addressing is only necessary for professional multi-channel interfaces.

**Do this instead:** Start with element 0. Detect failure (non-noErr return) as the signal that per-channel addressing may be needed, and handle as an edge case.

### Anti-Pattern 5: Restructuring the Haiku System Prompt

**What people do:** Rewrite the entire system prompt to address the "gracias" issue.

**Why it's wrong:** The existing prompt was tuned over real dictation sessions. A full rewrite risks regressing on punctuation quality, filler-word removal accuracy, or paragraph-break behavior.

**Do this instead:** Append a single targeted rule (Rule 6) in the same style as existing rules. Surgical change, no regression surface.

---

## Integration Points

### Internal Boundaries

| Boundary | Communication | Notes |
|----------|---------------|-------|
| `AppCoordinator` → `MicInputVolumeService` | Protocol method calls at state transitions | Injected by `AppDelegate` at startup |
| `MicInputVolumeService` → `MicrophoneDeviceService` | Direct method calls for device resolution | Constructor injection; same instance used by `AudioRecorder` |
| `MicInputVolumeService` → CoreAudio HAL | `AudioObjectGetPropertyData` / `AudioObjectSetPropertyData` | Same API already used by `MicrophoneDeviceService` for device enumeration |
| `HaikuCleanupService` → Anthropic API | URLSession POST | Unchanged; only system prompt string changes |

### No New External Boundaries

Both features operate entirely within existing system boundaries: CoreAudio HAL (already used) and Anthropic API (already used). No new frameworks, no new entitlements, no new network endpoints.

---

## Scaling Considerations

Single-user local macOS app. Not applicable. The CoreAudio API calls in `MicInputVolumeService` complete synchronously in microseconds — no async overhead, no UI blocking.

---

## Sources

- Existing source code read directly from `/Users/max/Personal/repos/my-superwhisper/MyWhisper/` — HIGH confidence
- [CoreAudio AudioObjectSetPropertyData — Apple Developer Documentation](https://developer.apple.com/documentation/coreaudio/1422920-audioobjectsetpropertydata) — HIGH confidence (official API reference)
- [kAudioDevicePropertyVolumeScalar — CoreAudio HAL](https://developer.apple.com/documentation/coreaudio) — HIGH confidence (same property family already used in MicrophoneDeviceService for device enumeration)
- [SimplyCoreAudio — Swift framework confirming kAudioDevicePropertyVolumeScalar + ScopeInput pattern](https://github.com/rnine/SimplyCoreAudio) — MEDIUM confidence (community; confirms API usage pattern)
- [Anthropic: Minimizing Hallucinations](https://docs.anthropic.com/en/docs/minimizing-hallucinations) — MEDIUM confidence (confirms explicit prohibition in system prompt is correct approach)

---

*Architecture research for: v1.2 Dictation Quality — Haiku prompt fix + mic input volume control*
*Researched: 2026-03-17*
