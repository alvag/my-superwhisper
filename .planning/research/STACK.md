# Stack Research

**Domain:** v1.2 Dictation Quality — mic input volume auto-maximize + Haiku hallucination fix
**Researched:** 2026-03-17
**Confidence:** HIGH (CoreAudio volume API), HIGH (Haiku prompt patterns)

> **Scope note:** This file covers only the NEW capabilities needed for v1.2.
> The existing validated stack (Swift/SwiftUI, WhisperKit, Haiku API, KeyboardShortcuts,
> CoreAudio device selection, CGEventPost, NSWorkspace media guard) is unchanged and
> is not re-researched here.

---

## Recommended Stack

### Core Technologies

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| CoreAudio HAL (AudioObjectGetPropertyData / AudioObjectSetPropertyData) | macOS 13+ | Read current mic input volume, write max volume on record start, restore on stop | Already imported in `MicrophoneDeviceService.swift`. The `AudioObjectPropertyAddress` + C function pattern is identical to what the project uses for device enumeration — zero new dependency, same paradigm. |
| AudioObjectIsPropertySettable | macOS 13+ | Check before writing whether a given device supports volume control on its input scope | Some devices (most USB/Bluetooth mics, aggregate devices) report `kAudioDevicePropertyVolumeScalar` as read-only or absent on the input scope. Must check before attempting write to avoid silent failure or crash. |
| Haiku system prompt update (no new library) | API version 2023-06-01 | Prevent "gracias" and similar hallucinated closings | Prompt engineering only — no new API call, no new SDK, no new dependency. The fix is a single sentence added to the existing `systemPrompt` in `HaikuCleanupService.swift`. |

### Supporting Libraries

None required. All needed capabilities exist in frameworks already imported by the project.

---

## Installation

No new SPM packages. No new frameworks. No Info.plist or entitlement changes.

The only new import needed is already present in `MicrophoneDeviceService.swift`:

```swift
import CoreAudio   // already imported
```

---

## CoreAudio Input Volume API — Exact Pattern

### Property Address

```swift
var address = AudioObjectPropertyAddress(
    mSelector: kAudioDevicePropertyVolumeScalar,
    mScope:    kAudioDevicePropertyScopeInput,
    mElement:  kAudioObjectPropertyElementMain   // element 0 = master/main channel
)
```

`kAudioObjectPropertyElementMain` (= 0) addresses the master/main channel. This is what
System Preferences and Audio MIDI Setup use for the input level slider.

### Step 1 — Check settability before reading or writing

Not all devices support input volume control at the driver level. Built-in MacBook mics may
or may not expose a settable volume property (hardware-dependent; Apple Silicon MBPs
generally do, some models do not). USB mics typically expose no settable input volume at all.
Always call `AudioObjectIsPropertySettable` first:

```swift
var isSettable: DarwinBoolean = false
let settableStatus = AudioObjectIsPropertySettable(deviceID, &address, &isSettable)
guard settableStatus == noErr, isSettable.boolValue else {
    // Property not settable on this device — skip silently, do not attempt write
    return
}
```

### Step 2 — Read current value (to restore later)

```swift
var currentVolume: Float32 = 0.0
var dataSize = UInt32(MemoryLayout<Float32>.size)
let getStatus = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &dataSize, &currentVolume)
guard getStatus == noErr else { return }
```

### Step 3 — Write maximum value

```swift
var maxVolume: Float32 = 1.0
let setStatus = AudioObjectSetPropertyData(deviceID, &address, 0, nil,
                                           UInt32(MemoryLayout<Float32>.size), &maxVolume)
// setStatus == noErr on success
```

### Step 4 — Restore on recording stop

```swift
var savedVolume: Float32 = currentVolume  // from Step 2
AudioObjectSetPropertyData(deviceID, &address, 0, nil,
                           UInt32(MemoryLayout<Float32>.size), &savedVolume)
```

### Which device ID to use

Use the same `AudioDeviceID` that `MicrophoneDeviceService.selectedDeviceID` resolves to,
falling back to the system default input device via `kAudioHardwarePropertyDefaultInputDevice`
if no device is explicitly selected — exactly how `AudioRecorder.start()` already selects
the recording device.

```swift
// Resolve actual device ID used for recording (mirrors AudioRecorder.start() logic)
func resolveInputDeviceID() -> AudioDeviceID? {
    if let saved = microphoneService?.selectedDeviceID,
       microphoneService?.availableInputDevices().map(\.id).contains(saved) == true {
        return saved
    }
    // Fall back to system default
    var defaultID: AudioDeviceID = 0
    var defaultAddress = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDefaultInputDevice,
        mScope:    kAudioObjectPropertyScopeGlobal,
        mElement:  kAudioObjectPropertyElementMain
    )
    var size = UInt32(MemoryLayout<AudioDeviceID>.size)
    guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject),
                                     &defaultAddress, 0, nil, &size, &defaultID) == noErr,
          defaultID != kAudioObjectUnknown else { return nil }
    return defaultID
}
```

---

## Haiku Prompt Fix — Exact Pattern

### Root cause

Haiku (and Claude models generally) are trained on text that commonly ends with polite
closings ("Gracias", "Thank you", "De nada", etc.). When transcribed dictation is short
or ends ambiguously, the model occasionally completes what it perceives as an interrupted
sentence or adds a social convention. This is hallucination by completion, not hallucination
by invention.

### Anthropic-recommended technique for this class of problem

Official guidance ([Anthropic: Reduce hallucinations](https://platform.claude.com/docs/en/test-and-evaluate/strengthen-guardrails/reduce-hallucinations)) calls for:

- **Explicit constraint on additions** — tell the model not to add content not present in input.
- **External knowledge restriction** — explicitly block the model from using knowledge outside the input.
- **"Tell Claude what to do, not what not to do"** but for strict prohibition the negative form is acceptable as a standalone rule with a REASON (the reason increases compliance).

Anthropic's own prompting docs note that adding context/reason behind an instruction
significantly improves following:

> "Your response will be read aloud by a TTS engine, so never use ellipses since TTS won't
> know how to pronounce them." (principle: explain WHY so Claude generalises correctly)

### Fix: one sentence addition to the existing systemPrompt

Current rule 5 in `HaikuCleanupService.swift`:

```
5. PROHIBIDO: NO parafrasees, NO agregues palabras que no estaban, NO reestructures oraciones, NO cambies el registro ni el tono.
```

Replace with:

```
5. PROHIBIDO: NO parafrasees, NO agregues palabras que no estaban en el audio (esto incluye despedidas, saludos o frases de cortesía como "gracias", "de nada", "hasta luego" a menos que el usuario las haya dicho explícitamente), NO reestructures oraciones, NO cambies el registro ni el tono. Tu entrada es transcripción de voz cruda; si la oración termina abruptamente, termínala igual de abrupt amente.
```

**Why this formulation works:**
1. Explicitly names the offending pattern ("gracias", "de nada", "hasta luego") so the model has a concrete anchor.
2. Adds a conditional exception ("a menos que el usuario las haya dicho explícitamente") that prevents over-blocking legitimate use of these words.
3. Provides the reasoning ("transcripción de voz cruda") so the model understands the task frame correctly — it is transforming, not composing.
4. "si la oración termina abruptamente, termínala igual" directly counters completion hallucination by normalising abrupt endings as valid output.

### Alternative approach: few-shot examples

The official Anthropic prompting guide recommends 3–5 examples wrapped in `<example>` tags
for the strongest steerability. For this specific case, a single explicit rule (above) is
preferred over few-shot because:
- The existing prompt uses a numbered-rules format; examples would change the structure.
- The token overhead of examples is undesirable given the 5-second pipeline budget.
- The rule formulation is precise enough to constrain the model without examples.

If the rule alone proves insufficient across edge cases, add to the `messages` array a
few-shot example via a prefilled exchange pattern (Haiku 4.5 still supports this):

```swift
"messages": [
    ["role": "user",    "content": "y eso fue todo lo que pasó este"],
    ["role": "assistant","content": "Y eso fue todo lo que pasó."],
    ["role": "user",    "content": rawText]
]
```

This shows the model that ending after removing a filler is the correct behaviour, not
adding "gracias" or similar.

---

## Alternatives Considered

| Recommended | Alternative | When to Use Alternative |
|-------------|-------------|-------------------------|
| CoreAudio HAL direct (AudioObjectSetPropertyData) | SimplyCoreAudio Swift package | Only if the project had zero existing CoreAudio code and needed a high-level wrapper. SimplyCoreAudio was archived (read-only) in March 2024, making it a dead dependency. The project already speaks the HAL API directly — adding a dead package for two function calls is not justified. |
| CoreAudio HAL direct | AVAudioSession.setInputGain() | AVAudioSession is the iOS/macOS Catalyst input gain API. It is NOT available in a standard macOS app (it is available on macOS 14.0+ in Mac Catalyst only). Do not use in a non-Catalyst macOS app — the API exists but the `inputGain` property throws at runtime outside Catalyst context. |
| System-level volume via CoreAudio HAL | Applescript / osascript `set volume input volume` | osascript can set system input volume but only for the default input device, has ~200ms latency, and introduces a subprocess dependency. The CoreAudio HAL call is synchronous, in-process, and already targets the correct device. |
| Prompt rule for "gracias" | Post-processing text filter (regex/string match) | A regex that strips "gracias" at end would also strip it when legitimately dictated ("...dile gracias de mi parte"). The prompt rule includes the conditional exception. Post-processing cannot distinguish dictated from hallucinated text. |

---

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| AVAudioSession.inputGain (macOS) | Available only in Mac Catalyst builds. Crashes or silently fails in standard AppKit/SwiftUI macOS apps. | CoreAudio HAL `kAudioDevicePropertyVolumeScalar` on `kAudioDevicePropertyScopeInput` |
| SimplyCoreAudio (Swift package) | Archived and read-only since March 2024. No future maintenance. For this use case (get/set input volume) it wraps the same 10-line CoreAudio HAL pattern the project already uses. | Inline CoreAudio HAL calls |
| Writing input volume without calling AudioObjectIsPropertySettable first | Most USB mics (Blue Yeti, Shure MV7, etc.) and Bluetooth devices expose no settable input volume at the CoreAudio HAL layer. Attempting `AudioObjectSetPropertyData` on an unsettable property returns `kAudioHardwareUnsupportedOperationError` and leaves state inconsistent. | Check settability first; skip gracefully if not settable |
| Stripping "gracias" via post-processing regex | Removes the word even when the user legitimately dictated it. | Prompt rule with explicit conditional exception |
| Increasing Haiku `max_tokens` budget for the prompt fix | The fix is one rule addition (~25 tokens). No token budget change needed. | Keep existing `estimateMaxTokens()` logic unchanged |

---

## Stack Patterns by Variant

**If the selected mic supports input volume control (most built-in mics, some USB interfaces):**
- `AudioObjectIsPropertySettable` returns `true`
- Read → maximize → restore flow executes normally
- Save/restore happens in `MicInputVolumeService` (new file) or extended `MicrophoneDeviceService`

**If the selected mic does NOT support input volume control (most USB mics, Bluetooth, aggregate devices):**
- `AudioObjectIsPropertySettable` returns `false` or the property is absent
- Skip the feature silently — do not log an error to the user
- Whisper still transcribes from whatever level the device provides

**If no device is explicitly selected (user uses system default):**
- Resolve `kAudioHardwarePropertyDefaultInputDevice` at recording start
- Apply volume maximization to that device ID
- Restore to that same device ID at stop

---

## Version Compatibility

| API | macOS Support | Notes |
|-----|--------------|-------|
| `AudioObjectIsPropertySettable` | macOS 10.6+ | Stable HAL API, unchanged through macOS 15.x (Sequoia) |
| `AudioObjectGetPropertyData` with `kAudioDevicePropertyVolumeScalar` + `kAudioDevicePropertyScopeInput` | macOS 10.6+ | Same API already used for device enumeration in the project |
| `AudioObjectSetPropertyData` with `kAudioDevicePropertyVolumeScalar` | macOS 10.6+ | Standard HAL write; works in non-sandboxed apps without special entitlements |
| `kAudioObjectPropertyElementMain` (= 0) | macOS 12+ (renamed from `kAudioObjectPropertyElementMaster`) | The old constant `kAudioObjectPropertyElementMaster` still compiles but generates a deprecation warning. Use `kAudioObjectPropertyElementMain` to keep the codebase warning-free. |
| Haiku API `claude-haiku-4-5-20251001` | Current as of research date | The model identifier in the codebase is correct. No model change needed for the prompt fix. |

**macOS deployment target:** No change. Existing target is macOS 14+ (WhisperKit). All
CoreAudio HAL APIs used here are available on macOS 13+, well within target.

**Non-sandboxed requirement:** `AudioObjectSetPropertyData` for device input volume does
NOT require entitlements or special permissions — it is a HAL call scoped to the hardware
device, not a process-level permission like microphone access (which the app already has).

---

## Sources

- CoreAudio `AudioObjectPropertyAddress` + `kAudioDevicePropertyVolumeScalar` pattern — verified via gist.github.com/kimsungwhee (Swift 4 output device example showing same pattern); adapted to input scope; MEDIUM confidence (pattern confirmed, input scope variant inferred from identical structure)
- `AudioObjectIsPropertySettable` signature — confirmed via Apple Developer Forums search result showing exact Swift signature; HIGH confidence
- `kAudioObjectPropertyElementMaster` deprecation / `kAudioObjectPropertyElementMain` rename — confirmed via CoreAudio release notes for macOS 12 SDK; HIGH confidence (Swift compiler warnings confirm)
- Built-in mic volume settability variability — confirmed via [Apple Community: How to adjust built-in mic gain](https://discussions.apple.com/thread/253852973) and [RØDE: Why Can't I Change the Input Volume in Mac Sound Settings](https://help.rode.com/hc/en-us/articles/9312496788239-Why-Can-t-I-Change-the-Input-Volume-in-Mac-Sound-Settings) showing USB mics have no settable input volume via macOS; HIGH confidence (multiple sources)
- Haiku hallucination by completion pattern — confirmed via [Anthropic: Reduce hallucinations](https://platform.claude.com/docs/en/test-and-evaluate/strengthen-guardrails/reduce-hallucinations) and [Anthropic: Prompting best practices](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/claude-prompting-best-practices); HIGH confidence (official Anthropic documentation)
- Prompt fix formulation — "explain WHY" principle from Anthropic prompting best practices; "negative examples + exception" pattern from hallucination guide; HIGH confidence
- `AVAudioSession.inputGain` not available in non-Catalyst macOS — inferred from AVAudioSession documentation scope (UIKit/Mac Catalyst only); MEDIUM confidence (negative claim from SDK scope, not explicit API docs confirming failure mode)

---

*Stack research for: v1.2 Dictation Quality — mic input volume auto-maximize + Haiku hallucination fix*
*Researched: 2026-03-17*
