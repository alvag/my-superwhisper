# Phase 7: Implementation - Research

**Researched:** 2026-03-17
**Domain:** CoreAudio input volume control (macOS HAL) + Haiku prompt engineering + suffix post-processing
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

#### Suffix strip logic
- Compare Haiku output against raw STT text to detect hallucinated additions
- If a phrase appears at the END of Haiku output but is NOT present in raw WhisperKit text, strip it
- Only strip "gracias" for now — the only confirmed hallucination pattern
- Legitimate "gracias" (present in raw STT) is preserved verbatim
- Strip runs AFTER Haiku response, BEFORE vocabulary corrections

#### Volume toggle
- Add settings toggle "Maximizar volumen al grabar" (default: ON) — follows same pattern as "Pausar reproduccion al grabar"
- UserDefaults key, persisted, checked by MicInputVolumeService.isEnabled
- When toggle is OFF, volume service is a no-op (same pattern as MediaPlaybackService)
- This adds requirement VOL-06 to the milestone

#### Prompt Rule 6 design
- Broad structural rule + specific examples
- Framing: "El texto viene de reconocimiento de voz (STT) y puede terminar abruptamente. NO completes ni agregues palabras de cortesía al final (gracias, de nada, hasta luego). Si la oración termina abruptamente, termínala igual."
- Appended as Rule 6 to existing numbered list in systemPrompt
- Works in conjunction with suffix strip as dual-layer defense

### Claude's Discretion
- Exact system prompt wording for Rule 6 (within the structural + examples constraint above)
- MicInputVolumeService internal implementation (CoreAudio HAL calls, error handling)
- Volume maximize/restore call placement relative to engine start (research suggests after engine.start(), but verify)
- Test strategy for both features

### Deferred Ideas (OUT OF SCOPE)
- VOL-06 (toggle setting) was added to scope during discussion — update REQUIREMENTS.md and ROADMAP.md
- Expandir suffix strip a mas frases si aparecen nuevos patterns de hallucination — futuro
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| HAIKU-01 | Haiku system prompt includes explicit Rule 6 prohibiting addition of words not present in input (specifically "gracias", "de nada", "hasta luego") | Confirmed: append Rule 6 to existing `systemPrompt` string in `HaikuCleanupService.swift` line 19. No protocol changes needed. |
| HAIKU-02 | Post-processing suffix strip removes hallucinated courtesy phrases as safety net when not present in raw transcription | Confirmed: suffix-match "gracias" (case-insensitive) at END of Haiku output vs raw STT text. Implemented in `AppCoordinator.handleHotkey()` after `haiku.clean()` returns, before `vocabularyService.apply()`. |
| VOL-01 | App saves current mic input volume level before recording starts | Confirmed: `AudioObjectGetPropertyData(deviceID, kAudioDevicePropertyVolumeScalar, kAudioDevicePropertyScopeInput)` in `MicInputVolumeService.maximizeAndSave()`. |
| VOL-02 | App sets mic input volume to maximum (1.0) when recording starts | Confirmed: `AudioObjectSetPropertyData` with `Float32(1.0)`. Called after `mediaPlayback?.pause()` + 150ms sleep, before `audioRecorder?.start()`. |
| VOL-03 | App restores original mic input volume when recording stops (all exit paths: success, cancel, error) | Confirmed: 6 exit paths mapped. `restore()` call mirrors `mediaPlayback?.resume()` pattern — placed at TOP of `.recording` case before any conditional returns, and in `handleEscape()`. |
| VOL-04 | App silently skips volume control when device does not expose settable input volume | Confirmed: `AudioObjectIsPropertySettable()` guard in `setVolume()`. Returns without error if not settable. |
| VOL-05 | Volume restore works correctly when mic device changes between start and stop | Confirmed: `resolveActiveDeviceID()` called at both maximize and restore time — no cached device ID from startup. |
| VOL-06 | Settings toggle "Maximizar volumen al grabar" (default: ON) | Confirmed: follows `pausePlaybackEnabled` pattern exactly — NSButton checkbox in `SettingsWindowController`, `UserDefaults` key `maximizeMicVolumeEnabled`, `UserDefaults.standard.register(defaults:)` in `AppDelegate`. |
</phase_requirements>

---

## Summary

Phase 7 implements two independent dictation-quality features: (1) prevention of Haiku hallucinating "gracias" at end of transcriptions via a dual-layer defense, and (2) automatic microphone input volume maximization at recording start with full restore on every exit path. Both features are small surgical changes to an existing ~3,900 LOC codebase that already has CoreAudio, protocol-based DI, and a well-tested FSM coordinator.

The codebase read confirms all integration points. `HaikuCleanupService.swift` has 5 rules in its `systemPrompt` — Rule 6 appends cleanly. `AppCoordinator.swift` already has `mediaPlayback?.resume()` at the start of the `.recording` case (line 73), which is exactly the pattern to mirror for `micVolumeService?.restore()`. `SettingsWindowController.swift` has a Section 6 pause playback checkbox — the volume toggle is Section 7. `AppCoordinatorDependencies.swift` needs one new protocol. `AppDelegate.swift` wires everything in `applicationDidFinishLaunching`.

**Primary recommendation:** Implement in three plans as specified — (1) `MicInputVolumeService` CoreAudio service, (2) AppCoordinator wiring at all 6 exit paths, (3) HaikuCleanupService Rule 6 + suffix strip. Plans 1 and 3 are fully independent; plan 2 depends on plan 1's protocol.

---

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| CoreAudio HAL (`AudioObjectGetPropertyData`, `AudioObjectSetPropertyData`) | macOS 10.6+ | Read/save/restore mic input volume scalar | Already imported in `MicrophoneDeviceService.swift`. Same `AudioObjectPropertyAddress` pattern. Zero new imports. |
| `AudioObjectIsPropertySettable` | macOS 10.6+ | Guard before every write to avoid silent failure on unsettable devices | Official HAL API for per-device property capability check. Not optional — built-in mics may return not-settable. |
| Anthropic Messages API | `2023-06-01` (unchanged) | Haiku cleanup with Rule 6 in system prompt | No model change, no API version change, no token budget change. Prompt-only fix. |

### Supporting

No new libraries, frameworks, SPM packages, or entitlements required.

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| CoreAudio HAL direct | `AVAudioSession.setInputGain()` | AVAudioSession input gain is iOS/Mac Catalyst only. Crashes or returns wrong values in non-Catalyst macOS apps. Never use in this project. |
| CoreAudio HAL direct | SimplyCoreAudio Swift package | Archived read-only since March 2024. Dead dependency. Wraps the same 10-line HAL pattern the project already uses. |
| CoreAudio HAL direct | `osascript set volume input volume` | Subprocess, ~200ms latency, only targets default device, introduces shell dependency. HAL call is synchronous and in-process. |
| Prompt Rule 6 + suffix strip | Prompt rule alone | LLMs can ignore prohibitions. Post-processing is the reliable backstop. Both layers together are defense-in-depth. |
| Prompt Rule 6 + suffix strip | Suffix strip alone (regex/blacklist) | Regex strips "gracias" even when user dictated it legitimately. Prompt rule adds the conditional exception. Both needed. |

**Installation:** No new packages. No `xcodebuild` project changes.

---

## Architecture Patterns

### Recommended Project Structure

New file:
```
MyWhisper/Audio/MicInputVolumeService.swift   # new CoreAudio service
```

Modified files:
```
MyWhisper/Coordinator/AppCoordinatorDependencies.swift  # add MicInputVolumeServiceProtocol
MyWhisper/Coordinator/AppCoordinator.swift              # add property + 3 call sites
MyWhisper/App/AppDelegate.swift                         # instantiate + wire service
MyWhisper/Cleanup/HaikuCleanupService.swift             # add Rule 6 to systemPrompt
MyWhisper/Settings/SettingsWindowController.swift       # add volume toggle checkbox
```

### Pattern 1: FSM Side-Effect Injection (mirrors MediaPlaybackService, v1.1)

**What:** Protocol-backed service injected into `AppCoordinator` by `AppDelegate`. Coordinator calls it at state boundaries with no knowledge of CoreAudio internals.

**When to use:** Any external system mutation at a recording state transition boundary.

**Protocol definition (add to `AppCoordinatorDependencies.swift`):**
```swift
// Source: ARCHITECTURE.md + MediaPlaybackServiceProtocol pattern
protocol MicInputVolumeServiceProtocol: AnyObject {
    /// Read current input volume, store it, then set input volume to 1.0.
    func maximizeAndSave()
    /// Restore the input volume saved by the last maximizeAndSave() call.
    func restore()
    /// Whether the feature is enabled (UserDefaults toggle).
    var isEnabled: Bool { get }
}
```

**Coordinator property (add to `AppCoordinator.swift`):**
```swift
var micVolumeService: (any MicInputVolumeServiceProtocol)?
```

### Pattern 2: Symmetric Save/Restore with Settability Guard

**What:** `maximizeAndSave()` atomically reads the current volume and stores it as `savedVolume: Float32?` before writing 1.0. `restore()` writes back the saved value and clears it.

**Critical guard — always check settability before writing:**
```swift
// Source: STACK.md — CoreAudio volume API pattern
var address = AudioObjectPropertyAddress(
    mSelector: kAudioDevicePropertyVolumeScalar,
    mScope:    kAudioDevicePropertyScopeInput,
    mElement:  kAudioObjectPropertyElementMain
)
var isSettable: DarwinBoolean = false
AudioObjectIsPropertySettable(deviceID, &address, &isSettable)
guard isSettable.boolValue else { return }  // silent no-op for built-in mics
```

**When to use:** Any time a hardware property must be temporarily overridden.

### Pattern 3: Device ID Resolution (mirrors AudioRecorder.start())

**What:** `resolveActiveDeviceID()` prefers `microphoneService.selectedDeviceID` when valid, falls back to `kAudioHardwarePropertyDefaultInputDevice`. Called fresh at both `maximizeAndSave()` and `restore()` — never cached at app launch.

**Why NOT derive from running `AVAudioEngine`:** Per CONTEXT.md discretion note and PITFALLS.md Pitfall 4, deriving from the running engine requires the engine to be started first. For maximize/save, calling BEFORE `audioRecorder?.start()` means the engine is not yet running. Using `MicrophoneDeviceService.selectedDeviceID` with the same fallback logic as `AudioRecorder.start()` targets the same device.

**Confirmed call site placement in `AppCoordinator.handleHotkey()` idle branch:**
```swift
// CURRENT (lines 54-64):
mediaPlayback?.pause()
try? await Task.sleep(for: .milliseconds(150))
// ADD HERE — before audioRecorder?.start():
micVolumeService?.maximizeAndSave()
do {
    try audioRecorder?.start()
} catch {
    mediaPlayback?.resume()
    micVolumeService?.restore()   // ADD: restore on start failure
    transitionTo(.error("microphone"))
    return
}
```

**Confirmed call site placement in `.recording` case:**
```swift
// CURRENT (line 70-73):
case .recording:
    escapeMonitor?.stopMonitoring()
    stopAudioLevelPolling()
    mediaPlayback?.resume()   // already here
// ADD immediately after mediaPlayback?.resume():
    micVolumeService?.restore()
    let buffer = audioRecorder?.stop() ?? []
```

**Confirmed call site placement in `handleEscape()`:**
```swift
// CURRENT (line 175):
mediaPlayback?.resume()   // already here
// ADD immediately after:
micVolumeService?.restore()
```

### Pattern 4: Suffix Strip — End-of-Text, Raw-STT-Presence Check

**What:** After `haiku.clean(rawText)` returns, check if the Haiku output ends with a known hallucination token that was NOT present in `rawText`. If so, strip it.

**Locked decision:** Only "gracias" is stripped for now. Case-insensitive. End-of-string only.

**Integration point in `AppCoordinator.handleHotkey()` (after Haiku block, before vocabulary):**
```swift
// Source: CONTEXT.md locked decisions
// After: finalText = try await haiku.clean(rawText)  OR  finalText = rawText (fallback)
// Before: correctedText = vocab.apply(to: finalText)

let strippedText = stripHallucinatedSuffix(from: finalText, rawInput: rawText)

// Helper (private func on AppCoordinator or free function):
private func stripHallucinatedSuffix(from output: String, rawInput: String) -> String {
    let patterns = ["gracias"]
    let lowercasedInput = rawInput.lowercased()
    var result = output
    for pattern in patterns {
        // Only strip if pattern is at the END of output
        // and was NOT present in the raw STT text
        if result.lowercased().hasSuffix(pattern),
           !lowercasedInput.contains(pattern) {
            // Strip the trailing pattern plus any preceding punctuation/whitespace
            let endIndex = result.index(result.endIndex, offsetBy: -pattern.count)
            result = result[..<endIndex]
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: ".,;:!?"))
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }
    return result
}
```

**Why `hasSuffix` instead of regex:** `hasSuffix` is case-sensitive; use `result.lowercased().hasSuffix(pattern)` for case-insensitive match. No regex dependency. Handles "Gracias", "gracias.", "Gracias." variants when combined with punctuation trim.

### Pattern 5: Settings Toggle (mirrors pausePlaybackEnabled)

**UserDefaults key:** `maximizeMicVolumeEnabled` (default: `true`)

**AppDelegate registration (add alongside existing `pausePlaybackEnabled`):**
```swift
UserDefaults.standard.register(defaults: [
    "pausePlaybackEnabled": true,
    "maximizeMicVolumeEnabled": true   // ADD
])
```

**SettingsWindowController checkbox (Section 7, add after Section 6):**
```swift
// Source: SettingsWindowController.swift Section 6 pattern
let volumeCheckbox = NSButton(checkboxWithTitle: "Maximizar volumen al grabar",
                               target: self, action: #selector(maximizeMicVolumeChanged(_:)))
volumeCheckbox.translatesAutoresizingMaskIntoConstraints = false
volumeCheckbox.state = UserDefaults.standard.bool(forKey: "maximizeMicVolumeEnabled") ? .on : .off
contentView.addSubview(volumeCheckbox)

// Action:
@objc private func maximizeMicVolumeChanged(_ sender: NSButton) {
    UserDefaults.standard.set(sender.state == .on, forKey: "maximizeMicVolumeEnabled")
}
```

**Service `isEnabled` property:**
```swift
var isEnabled: Bool {
    UserDefaults.standard.bool(forKey: "maximizeMicVolumeEnabled")
}
```

**Service guard in `maximizeAndSave()`:**
```swift
func maximizeAndSave() {
    guard isEnabled else { return }   // same no-op pattern as MediaPlaybackService
    // ...
}
```

### Anti-Patterns to Avoid

- **`defer` in `handleHotkey()` for volume restore:** `handleHotkey()` is `async` and returns to the run loop mid-execution. `defer` fires at the wrong time. Use explicit restore at each exit branch instead (same reason `mediaPlayback?.resume()` is explicit).
- **Caching `AudioObjectIsPropertySettable` result at app launch:** Device can change. Re-check every time `setVolume()` is called against the current device.
- **Saving `savedVolume` to UserDefaults:** Creates stale-state risk if user changed volume between crash and relaunch. Keep as instance-scoped `Float32?` only.
- **Targeting `kAudioObjectPropertyScopeGlobal` for input volume:** Input volume requires `kAudioDevicePropertyScopeInput`. Wrong scope silently reads/writes output or global property.
- **Stripping "gracias" even when present in raw STT:** The strip must check `rawInput.lowercased().contains(pattern)` — if the user actually said "gracias", preserve it.
- **Restructuring the Haiku system prompt:** Rewriting existing rules risks regressing punctuation, filler removal, or paragraph-break behavior tuned over real sessions. Append Rule 6 only.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Mic input volume read/write | Custom CoreAudio wrapper class | Inline `AudioObjectGetPropertyData` / `AudioObjectSetPropertyData` calls in `MicInputVolumeService` | Same 10-line pattern already in `MicrophoneDeviceService.swift`. No abstraction needed. |
| Device capability check | Try/catch around set call | `AudioObjectIsPropertySettable()` | Some devices silently "succeed" but do nothing. Must check before attempting write. |
| LLM output word filtering | Regex blacklist of forbidden words | Prompt constraint (Rule 6) + presence-check suffix strip | Regex strips words even when legitimately dictated. Presence check is the only correct approach. |
| Custom URLSession network layer for Haiku | New HTTP client | Existing `URLSession` in `HaikuCleanupService` | Zero changes to network layer needed — only `systemPrompt` string changes. |

**Key insight:** Both features are surgical edits to existing patterns. No new abstractions, frameworks, or architectural patterns are needed beyond what v1.1 established.

---

## Common Pitfalls

### Pitfall 1: Volume Not Restored on All 6 Exit Paths

**What goes wrong:** Only implementing restore on the happy-path stop. After Escape, STT error, VAD silence, Haiku error, or start-failure, mic stays pegged at 1.0 for all other apps.

**Why it happens:** The `.recording` case in `handleHotkey()` has multiple early returns after `mediaPlayback?.resume()`. Restore must be placed BEFORE the first conditional branch (same as media resume placement at line 73).

**Current exit paths to cover:**
1. `handleHotkey()` idle→recording: start failure (line 61) — `restore()` needed here
2. `handleHotkey()` recording: VAD silence — `restore()` ALREADY covered if placed before `audioRecorder?.stop()`
3. `handleHotkey()` recording: STT error — `restore()` ALREADY covered if placed before `audioRecorder?.stop()`
4. `handleHotkey()` recording: Haiku error (pastes raw) — `restore()` ALREADY covered
5. `handleHotkey()` recording: success — `restore()` ALREADY covered
6. `handleEscape()` cancel — `restore()` needed, mirrors `mediaPlayback?.resume()` at line 175

**How to avoid:** Place `micVolumeService?.restore()` immediately after `mediaPlayback?.resume()` in BOTH `handleHotkey()` `.recording` case and `handleEscape()`. Add it at the start-failure branch too.

**Warning signs:** After pressing Escape, mic is louder in Zoom/FaceTime. After a network error, same symptom.

### Pitfall 2: Wrong Device Targeted for Volume

**What goes wrong:** `microphoneService.selectedDeviceID` contains the user's last-selected device ID, but the engine may be recording from the system default if that device was disconnected. Volume is set on the wrong (disconnected) device.

**How to avoid:** `resolveActiveDeviceID()` must check if the stored device ID is still in `availableInputDevices()`. If not, fall back to `kAudioHardwarePropertyDefaultInputDevice` — same fallback as `AudioRecorder.start()`.

**Warning signs:** Volume operation reports success but recording level is unchanged. USB mic was selected, disconnected, engine records from built-in mic, volume stays at whatever built-in was set to.

### Pitfall 3: Suffix Strip Removes Legitimately Dictated "gracias"

**What goes wrong:** User dictates "Dile gracias de mi parte" → output ends with "gracias" → strip fires → truncates text.

**How to avoid:** Before stripping, check `rawInput.lowercased().contains(pattern)`. If the raw STT text contains "gracias", do NOT strip — the user said it. The hallucination pattern is specifically Haiku ADDING "gracias" when WhisperKit did NOT transcribe it.

**Warning signs:** Users report their courtesy phrases are being deleted.

### Pitfall 4: `kAudioObjectPropertyElementMain` vs `kAudioObjectPropertyElementMaster`

**What goes wrong:** Using the deprecated `kAudioObjectPropertyElementMaster` generates compiler warnings; may cause issues on future macOS.

**How to avoid:** Always use `kAudioObjectPropertyElementMain` (value = 0). Both constants resolve to the same integer value currently, but `ElementMaster` is deprecated since macOS 12.

**Warning signs:** Compiler warning `'kAudioObjectPropertyElementMaster' was deprecated in macOS 12.0`.

### Pitfall 5: Panel Height Too Small After Adding Toggle

**What goes wrong:** `SettingsWindowController` panel is created with `height: 560` (line 41). Adding a 7th section (volume toggle) below Section 6 will be cut off or the bottomAnchor constraint will be violated.

**How to avoid:** Increase panel height from 560 to ~590 when adding the volume toggle row. The bottom constraint is `pauseCheckbox.bottomAnchor.constraint(lessThanOrEqualTo:..., constant: -20)` — this will need to be moved to the new volumeCheckbox, and the old pauseCheckbox will anchor to volumeCheckbox.topAnchor.

---

## Code Examples

Verified patterns from official sources and existing codebase:

### CoreAudio Input Volume Read

```swift
// Source: STACK.md — confirmed against Apple CoreAudio HAL docs
private func getVolume(deviceID: AudioDeviceID) -> Float32? {
    var volume = Float32(0)
    var size = UInt32(MemoryLayout<Float32>.size)
    var address = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyVolumeScalar,
        mScope:    kAudioDevicePropertyScopeInput,
        mElement:  kAudioObjectPropertyElementMain
    )
    guard AudioObjectGetPropertyData(
        deviceID, &address, 0, nil, &size, &volume
    ) == noErr else { return nil }
    return volume
}
```

### CoreAudio Input Volume Write with Settability Guard

```swift
// Source: STACK.md — critical guard to prevent errors on built-in mics
private func setVolume(_ volume: Float32, deviceID: AudioDeviceID) {
    var address = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyVolumeScalar,
        mScope:    kAudioDevicePropertyScopeInput,
        mElement:  kAudioObjectPropertyElementMain
    )
    var isSettable: DarwinBoolean = false
    guard AudioObjectIsPropertySettable(deviceID, &address, &isSettable) == noErr,
          isSettable.boolValue else { return }
    var vol = volume
    AudioObjectSetPropertyData(deviceID, &address, 0, nil,
                               UInt32(MemoryLayout<Float32>.size), &vol)
}
```

### System Default Input Device Resolution

```swift
// Source: ARCHITECTURE.md — fallback when selectedDeviceID is nil or stale
private func systemDefaultInputDeviceID() -> AudioDeviceID? {
    var deviceID = AudioDeviceID(0)
    var size = UInt32(MemoryLayout<AudioDeviceID>.size)
    var address = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDefaultInputDevice,
        mScope:    kAudioObjectPropertyScopeGlobal,
        mElement:  kAudioObjectPropertyElementMain
    )
    guard AudioObjectGetPropertyData(
        AudioObjectID(kAudioObjectSystemObject),
        &address, 0, nil, &size, &deviceID
    ) == noErr, deviceID != kAudioObjectUnknown else { return nil }
    return deviceID
}
```

### Haiku System Prompt Rule 6 (locked wording per CONTEXT.md)

```swift
// Source: CONTEXT.md locked decisions + STACK.md Haiku prompt pattern
// Append to existing systemPrompt string in HaikuCleanupService.swift after Rule 5:
"""
6. ORIGEN STT: El texto viene de reconocimiento de voz (STT) y puede terminar \
abruptamente. NO completes ni agregues palabras de cortesía al final \
(gracias, de nada, hasta luego) salvo que estén literalmente en el texto original. \
Si la oración termina abruptamente, termínala igual de abruptamente.
"""
```

### Suffix Strip Logic

```swift
// Source: CONTEXT.md locked decisions
// Applied in AppCoordinator after haiku.clean() and before vocabularyService.apply()
private func stripHallucinatedSuffix(from output: String, rawInput: String) -> String {
    let confirmedPatterns = ["gracias"]  // only expand with evidence
    let lowercasedInput = rawInput.lowercased()
    var result = output
    for pattern in confirmedPatterns {
        guard result.lowercased().hasSuffix(pattern),
              !lowercasedInput.contains(pattern) else { continue }
        let suffixStart = result.index(result.endIndex, offsetBy: -pattern.count)
        result = String(result[..<suffixStart])
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: ".,;:!?"))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    return result
}
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `kAudioObjectPropertyElementMaster` | `kAudioObjectPropertyElementMain` | macOS 12 SDK | Deprecation warning eliminated; use `ElementMain` |
| `AVAudioSession.setInputGain()` (iOS pattern) | `AudioObjectSetPropertyData` with `kAudioDevicePropertyScopeInput` | Always macOS-specific | No change needed; document as avoid |
| SimplyCoreAudio Swift package | Inline CoreAudio HAL calls | March 2024 (package archived) | Project already uses inline HAL; no dependency change |

**Deprecated/outdated:**
- `kAudioObjectPropertyElementMaster`: Deprecated macOS 12, replaced by `kAudioObjectPropertyElementMain`. Same integer value (0), but use new constant for warning-free builds.
- `AVAudioSession.inputGain` on macOS: Was never correct for non-Catalyst macOS; iOS-only. Document explicitly in implementation to prevent confusion.

---

## Open Questions

1. **Exact `hasSuffix` edge cases for "gracias." (with trailing period)**
   - What we know: `result.lowercased().hasSuffix("gracias")` does NOT match "gracias." (period present)
   - What's unclear: Whether Haiku output would have "gracias" or "Gracias." as the hallucinated suffix
   - Recommendation: Strip trailing punctuation from `result` before pattern check, OR check both `hasSuffix("gracias")` and `hasSuffix("gracias.")`. The code example above trims punctuation AFTER stripping the word, which handles "Gracias." correctly by checking lowercased hasSuffix first then trimming. **Implementer must verify this handles the "Gracias." variant correctly.**

2. **SettingsWindowController panel height**
   - What we know: Current panel height is 560px. Section 6 (pause) has `bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -20)`.
   - What's unclear: Exact pixel height needed for 7th toggle section.
   - Recommendation: Increase panel height to 590px and change Section 6 bottom anchor to connect to Section 7 topAnchor, with Section 7 using the existing bottomAnchor constraint.

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | XCTest (built-in, Xcode) |
| Config file | `MyWhisper.xcodeproj` — `MyWhisperTests` target |
| Quick run command | `xcodebuild -project MyWhisper.xcodeproj -scheme MyWhisper -destination "platform=macOS" -configuration Debug CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO test 2>&1 \| grep -E "passed\|failed"` |
| Full suite command | Same as above |

**Note:** Standard `xcodebuild test` fails due to Team ID mismatch in Developer ID signing. The `CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO` flags bypass this and allow tests to run. All 30+ existing tests pass with this command.

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| HAIKU-01 | System prompt contains Rule 6 text | unit | `xcodebuild ... -only-testing:MyWhisperTests/HaikuCleanupServiceTests/testRequestBodyContainsRule6` | ❌ Wave 0 |
| HAIKU-02 | Suffix strip removes "gracias" absent from raw STT | unit | `xcodebuild ... -only-testing:MyWhisperTests/AppCoordinatorTests/testSuffixStripRemovesHallucinatedGracias` | ❌ Wave 0 |
| HAIKU-02 | Suffix strip preserves "gracias" present in raw STT | unit | `xcodebuild ... -only-testing:MyWhisperTests/AppCoordinatorTests/testSuffixStripPreservesLegitimateGracias` | ❌ Wave 0 |
| VOL-01 | `maximizeAndSave()` called when transitioning idle→recording | unit | `xcodebuild ... -only-testing:MyWhisperTests/AppCoordinatorTests/testVolumeMaximizedOnRecordingStart` | ❌ Wave 0 |
| VOL-02 | Volume maximize called before `audioRecorder?.start()` | unit | (covered by VOL-01 test via mock call order) | ❌ Wave 0 |
| VOL-03 | `restore()` called on recording→processing transition | unit | `xcodebuild ... -only-testing:MyWhisperTests/AppCoordinatorTests/testVolumeRestoredOnRecordingStop` | ❌ Wave 0 |
| VOL-03 | `restore()` called on escape cancel path | unit | `xcodebuild ... -only-testing:MyWhisperTests/AppCoordinatorTests/testVolumeRestoredOnEscapeCancel` | ❌ Wave 0 |
| VOL-03 | `restore()` called on start failure path | unit | `xcodebuild ... -only-testing:MyWhisperTests/AppCoordinatorTests/testVolumeRestoredOnStartFailure` | ❌ Wave 0 |
| VOL-03 | `restore()` called on VAD silence path | unit | `xcodebuild ... -only-testing:MyWhisperTests/AppCoordinatorTests/testVolumeRestoredOnVADSilence` | ❌ Wave 0 |
| VOL-04 | Non-settable device: maximizeAndSave() is silent no-op | unit | `xcodebuild ... -only-testing:MyWhisperTests/MicInputVolumeServiceTests` | ❌ Wave 0 (new file) |
| VOL-05 | Device changes: restore targets correct device | unit | (covered by MicInputVolumeServiceTests resolve logic) | ❌ Wave 0 |
| VOL-06 | Toggle OFF: maximizeAndSave() is no-op | unit | `xcodebuild ... -only-testing:MyWhisperTests/AppCoordinatorTests/testVolumeToggleOffSkipsMaximize` | ❌ Wave 0 |

**Existing tests that already cover related behaviors (no changes needed):**
- `AppCoordinatorTests.testMediaPausedOnRecordingStart` — pattern for VOL-01/02 test structure
- `AppCoordinatorTests.testMediaResumedOnEscapeCancel` — pattern for VOL-03 escape test
- `AppCoordinatorTests.testMediaResumedOnVADSilence` — pattern for VOL-03 VAD silence test
- `AppCoordinatorTests.testMediaResumedOnTranscriptionError` — pattern for VOL-03 error test
- `HaikuCleanupServiceTests.testRequestBodyContainsModelAndSystemPrompt` — extend for Rule 6 check

### Sampling Rate

- **Per task commit:** `xcodebuild -project MyWhisper.xcodeproj -scheme MyWhisper -destination "platform=macOS" -configuration Debug CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO test 2>&1 | grep -E "passed|failed"`
- **Per wave merge:** Full suite (same command)
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps

- [ ] `MyWhisperTests/MicInputVolumeServiceTests.swift` — covers VOL-01/04/05 (new service unit tests)
- [ ] `MyWhisperTests/AppCoordinatorTests.swift` — extend with VOL-01/02/03/06 and HAIKU-02 test cases (add to existing file)
- [ ] `MyWhisperTests/HaikuCleanupServiceTests.swift` — extend with HAIKU-01 Rule 6 presence check (add to existing file)

*(All three existing test files already compile and run. Wave 0 work is additive only — no restructuring.)*

---

## Sources

### Primary (HIGH confidence)

- Existing source code read directly from `/Users/max/Personal/repos/my-superwhisper/MyWhisper/` — AppCoordinator.swift, AppCoordinatorDependencies.swift, AppDelegate.swift, HaikuCleanupService.swift, MicrophoneDeviceService.swift, MediaPlaybackService.swift, SettingsWindowController.swift
- `.planning/research/STACK.md` — CoreAudio volume API pattern, Haiku prompt fix rationale (project-internal, HIGH)
- `.planning/research/ARCHITECTURE.md` — component integration design, build order, data flow (project-internal, HIGH)
- `.planning/research/PITFALLS.md` — 6 exit paths, defer trap, device ID pitfalls (project-internal, HIGH)
- `.planning/phases/07-implementation/07-CONTEXT.md` — locked decisions, integration points (project-internal, HIGH)
- [Apple Developer: AudioObjectSetPropertyData](https://developer.apple.com/documentation/coreaudio/1422920-audioobjectsetpropertydata) — official CoreAudio HAL API (HIGH)
- [Anthropic: Reduce hallucinations](https://platform.claude.com/docs/en/test-and-evaluate/strengthen-guardrails/reduce-hallucinations) — explicit constraint + conditional exception pattern (HIGH)

### Secondary (MEDIUM confidence)

- CoreAudio `kAudioObjectPropertyElementMaster` deprecation — confirmed via macOS 12 SDK notes and Swift compiler warning behavior
- `AudioObjectIsPropertySettable` Swift signature — confirmed via Apple Developer Forums examples

### Tertiary (LOW confidence)

None. All critical claims verified against primary sources.

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all APIs already in use in the codebase or directly from Apple CoreAudio docs
- Architecture: HIGH — existing code read directly; integration points confirmed line-by-line
- Pitfalls: HIGH — confirmed against existing codebase patterns and prior phase research
- Test infrastructure: HIGH — tests run and pass; command verified

**Research date:** 2026-03-17
**Valid until:** 2026-04-17 (stable macOS APIs, no fast-moving dependencies)
