# Pitfalls Research

**Domain:** Local voice-to-text macOS menubar app — v1.2 Dictation Quality features
**Researched:** 2026-03-17
**Confidence:** HIGH (CoreAudio limitations verified via Apple Developer Forums, framework headers, and CoreAudio documentation), HIGH (Haiku/LLM prompt hallucination patterns verified via official Anthropic docs and prompt engineering literature)

---

## Critical Pitfalls

### Pitfall 1: CoreAudio Volume Property May Not Be Settable on All Devices

**What goes wrong:**
`AudioObjectSetPropertyData` with `kAudioDevicePropertyVolumeScalar` and `kAudioObjectPropertyScopeInput` returns `noErr` on some devices but silently does nothing. On others, it returns an error code. The built-in MacBook microphone is a known case where input volume is not software-settable via this API — Apple controls gain at hardware/driver level. Aggregate devices (a common macOS construct) explicitly do not expose volume controls at all.

The failure mode is silent on some hardware: the call returns `noErr`, the get confirms the value changed, but the system ignores it and records at the same level.

**Why it happens:**
CoreAudio property settability is per-device and per-property. The API exposes `AudioObjectIsPropertySettable()` specifically for this reason, but many developers skip this check and call the setter directly. The property is settable on external USB microphones, some headsets, and interface-connected mics — but NOT reliably on built-in Apple Silicon mic hardware.

**How to avoid:**
1. Always call `AudioObjectIsPropertySettable()` before any volume property set. If it returns false, skip the set operation entirely — do not attempt it.
2. Capture the original volume via `AudioObjectGetPropertyData` before setting. If the get fails, abort the feature for that device.
3. Treat the entire volume control feature as best-effort: if the property is not settable, record at the current system level and proceed silently (no error shown to user).
4. On `stop()`, only call the restore if the initial `set()` succeeded.

**Warning signs:**
- `AudioObjectIsPropertySettable()` returns false for the selected device.
- The get/set cycle shows the value "changed" but audio levels are identical before and after.
- OSStatus error `-66749` (`kAudioHardwareUnknownPropertyError`) or `-66716` (`kAudioHardwareBadPropertySizeError`) returned from the setter.
- Works on external USB mic but silently fails on built-in mic.

**Phase to address:**
Implementation phase (Phase 1 of v1.2). Implement settability check before write. Treat non-settable as a no-op, not an error.

---

### Pitfall 2: Volume Not Restored on Abnormal Exit Paths

**What goes wrong:**
The recording pipeline has multiple exit paths: normal stop, escape cancel, VAD silence gate (no speech detected), transcription error, Haiku API error, and app crash. If `restoreVolume()` is only called on the normal stop path, every other exit path permanently leaves the microphone at 100% volume until the user manually adjusts it or reboots.

The user experiences this as: after dictating and getting an API error or pressing Escape, their mic is now pegged at 100% for all other apps (Zoom, FaceTime, Voice Memos), which is disruptive and invisible.

**Why it happens:**
The save/restore pattern requires a symmetric cleanup. In the existing `AppCoordinator`, there are currently 6 distinct paths that exit recording state: `handleHotkey()` normal stop, `handleEscape()`, VAD gate, STT error, Haiku cleanup error, and auth error. Developers typically handle the happy path first and add cleanup to the obvious exit, missing the error branches.

**How to avoid:**
The correct pattern mirrors the existing `mediaPlayback?.resume()` placement in `AppCoordinator`:

- `mediaPlayback?.resume()` is already called at the TOP of the `.recording` → processing transition (line 73 in AppCoordinator), before any early returns — this ensures all paths resume media.
- Apply the same "restore before the fork" discipline to volume: restore immediately when leaving `.recording` state, regardless of why.
- Concretely: restore volume in `handleEscape()`, and at the start of the `.recording` case in `handleHotkey()` before any conditional returns.
- Do NOT restore in a `defer` block inside `handleHotkey()` — `defer` lifetime is scoped to the function, and the function returns to await async operations, so it fires at the wrong time.

**Warning signs:**
- After pressing Escape, mic is louder in other apps.
- After a network error on Haiku cleanup, mic stays at 100%.
- `deinit` of the volume service is never called (app keeps running as a menubar app).

**Phase to address:**
Implementation phase (Phase 1 of v1.2). Design restore placement before writing any volume code — map all 6 exit paths and ensure each calls restore.

---

### Pitfall 3: Haiku Prompt Changes May Introduce New Hallucination Modes

**What goes wrong:**
The current system prompt bans adding words (rule 5: "NO agregues palabras que no estaban"). Despite this, Haiku adds "gracias" as a courteous closing phrase — a behavior rooted in RLHF training that makes the model "helpful" by adding polite endings to speech. Fixing this by adding "no termines con 'gracias'" to the rule list creates a whack-a-mole problem: fixing one hallucinated phrase does not prevent others ("de nada", "hasta luego", "que tengas un buen día").

The prompt fix approach works only if the constraint is general and absolute, not enumerating specific forbidden words.

**Why it happens:**
Claude Haiku is trained to be helpful and polite. When processing Spanish text, its RLHF training interprets a transcription ending mid-sentence (without closing punctuation or a natural ending) as incomplete, and "helpfully" completes it with a socially appropriate closing. This is an extrinsic hallucination: the model generates content not present in the input based on its training-derived expectation of how Spanish conversations end.

The existing rule 5 says "NO agregues palabras" but this is too abstract — the model's training signal for politeness overrides the abstract rule because the model's internal representation of "a complete, helpful response to spoken Spanish" includes courteous endings.

**How to avoid:**
Replace the abstract prohibition with a concrete, verifiable constraint that appeals to the model's understanding of the task, not just a rule:

1. Make the constraint structural and testable: "Si el texto de entrada termina con una frase incompleta, devuélvela incompleta. Si termina en medio de una oración, termina en medio de esa misma oración."
2. Add an explicit anti-example (few-shot negative): show input "...me parece muy bien" → correct output "...me parece muy bien" (not "...me parece muy bien. ¡Gracias!").
3. Add a meta-instruction about the source of the text: "El texto proviene de reconocimiento de voz automático y puede terminar abruptamente. Esto es normal. No lo corrijas ni lo completes."

The Anthropic prompt engineering docs confirm that providing context/motivation for a constraint ("because the text comes from STT and may end mid-sentence") is more effective than stating the rule without justification.

**Warning signs:**
- Output contains any word not found verbatim in the input.
- Output ends with punctuation or words that were not in the raw Whisper output.
- The hallucination changes after a prompt update (different word added).
- The issue reproduces consistently with specific input patterns (transcriptions that end without punctuation).

**Phase to address:**
Prompt engineering phase (Phase 1 of v1.2). Test the updated prompt against at least 10 real transcription samples before shipping. Add a regression check: output word count should never exceed input word count by more than 3 (punctuation tokens).

---

### Pitfall 4: Volume Control Coupled to the Wrong Device ID

**What goes wrong:**
`MicrophoneDeviceService.selectedDeviceID` stores the user's preferred device. But at recording time, `AVAudioEngine` may be using the system default if the stored ID is stale or invalid (the existing `AudioRecorder` already handles this by clearing stale IDs). If the volume setter uses `selectedDeviceID` but the engine is actually recording from the system default, the volume is set on the wrong device.

The user gets 100% volume set on their (disconnected) Blue Yeti while the built-in mic records at whatever level it was already at.

**Why it happens:**
The device used for recording (`AVAudioEngine`'s current input device) and the device the user configured in Settings can diverge. The existing code already handles this divergence for engine setup (clearing stale device IDs) but a new volume service that reads `selectedDeviceID` independently will not see this cleared value until after `AudioRecorder.start()` has already resolved the effective device.

**How to avoid:**
Query the effective device ID from the running `AVAudioEngine` after `start()`, not from `selectedDeviceID`. The effective device is retrievable via:
```swift
var deviceID: AudioDeviceID = 0
var propertySize = UInt32(MemoryLayout<AudioDeviceID>.size)
AudioUnitGetProperty(
    engine.inputNode.audioUnit!,
    kAudioOutputUnitProperty_CurrentDevice,
    kAudioUnitScope_Global,
    0,
    &deviceID,
    &propertySize
)
```
Use this `deviceID` — not `selectedDeviceID` — as the target for volume get/set.

**Warning signs:**
- Volume set succeeds, but the recording level does not change.
- The issue appears when user has a USB mic that was disconnected: engine falls back to built-in, volume service targets the non-existent USB device.
- Debug log shows different device IDs between "volume target" and "engine input device."

**Phase to address:**
Implementation phase (Phase 1 of v1.2). The volume service must derive device ID from the running engine, not from UserDefaults.

---

### Pitfall 5: Prompt Constraint Causes Over-Truncation of Valid Endings

**What goes wrong:**
Overcorrecting the "gracias" problem by instructing Haiku to strip closing courtesies results in removing valid dictated content. If the user actually says "muchas gracias" to the person they are talking to as part of their dictation, Haiku strips the word and corrupts the text.

The user dictates: "Por favor envíame el documento. Muchas gracias." — Haiku outputs: "Por favor envíame el documento." — The user's actual words are deleted.

**Why it happens:**
A word-level blacklist ("never output 'gracias'") treats the word as forbidden regardless of whether the user said it. The issue is not the word "gracias" — it is Haiku adding words that were NOT in the transcription. The correct constraint targets the behavior (addition), not the token.

**How to avoid:**
Never instruct the model to remove specific words from the output. The constraint must target addition, not content. The correct framing is: "every word in the output must have been present in the input" — not "do not use the word X."

The fix for Pitfall 3 (making addition the forbidden behavior) automatically handles this correctly. A word-level blacklist is the wrong approach.

**Warning signs:**
- User reports that real "gracias" in their transcriptions is being deleted.
- Output is shorter than input in cases where Whisper correctly transcribed courtesy phrases the user said.

**Phase to address:**
Prompt engineering phase (Phase 1 of v1.2). The test suite for the updated prompt must include cases where the user actually says "gracias" and "de nada" — verify these are preserved.

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Skip `AudioObjectIsPropertySettable()` check | Shorter code | Silent failure on built-in mics; hard to debug | Never — always check settability before setting |
| Restore volume only on happy path | Simpler code | Mic stays at 100% after every error, cancel, or Escape | Never — restore must cover all exit paths |
| Word-level blacklist in prompt ("never output 'gracias'") | Immediately stops the "gracias" hallucination | Deletes real user-dictated courtesy phrases | Never — fix the addition behavior, not the specific token |
| Set volume on `selectedDeviceID` without verifying it matches running engine | Consistent with how mic selection works elsewhere | Wrong device targeted when stored device is stale | Never — derive device from running engine |
| Treat volume feature failure as a hard error | Simpler control flow | Feature is non-functional on built-in mic; unnecessarily blocks recording | Never — volume boost is best-effort; degrade silently |

---

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| CoreAudio volume scope | Use `kAudioObjectPropertyScopeGlobal` for input volume | Input volume requires `kAudioObjectPropertyScopeInput`; using Global scope silently reads/writes the wrong property channel |
| CoreAudio channel for master volume | Use channel `0` (main) directly | Channel `0` is `kAudioObjectPropertyElementMain` (master); some devices expose per-channel volume only — read both and use whichever is settable |
| `AudioObjectIsPropertySettable` | Call it once at app start and cache the result | Device can be changed by user at any time; re-check settability each time recording starts against the current effective device |
| Haiku system prompt | Add "no agregues 'gracias'" as a specific rule | Enumerate the forbidden behavior (adding words absent from input), not the forbidden token — use context about STT source to motivate the constraint |
| Volume restore on AppCoordinator | Place restore in `defer` block inside `handleHotkey()` | Swift `defer` fires at scope exit; `handleHotkey()` is `async` and returns to the run loop mid-execution — use explicit restore at each exit path instead |
| AVAudioEngine device ID query | Read device ID before `engine.start()` | The effective input device is only set after `start()`; query it immediately after the `try engine.start()` call succeeds |

---

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| Calling `AudioObjectGetPropertyData` on every audio buffer callback | CPU spike every 20ms during recording | Volume read/write happens only at recording start and stop — never during the tap callback | Always — this is unnecessary; the tap callback runs at audio thread priority |
| Testing volume change by playing back audio | Inaccurate — playback volume is separate from input gain on most devices | Use a VU meter or recording level indicator; don't infer input volume from playback | Every test run — misleads the developer |
| Re-sending the full system prompt on every Haiku call when iterating on prompt | No performance issue per se, but slow iteration cycle | Use a dedicated test harness (script with 10 sample inputs) to validate prompt changes before updating app code | Every prompt iteration cycle |

---

## UX Pitfalls

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| Show an error when mic volume is not settable | User is alarmed by an error they cannot fix and did not cause | Silent no-op — the recording still works at current mic level; the feature just doesn't boost it |
| Set volume to exactly 1.0 (100%) | May overdrive some microphone inputs causing clipping | Target 0.85–0.90 as the "maximize" level; this avoids clipping headroom issues on sensitive mics |
| Restore volume to 1.0 instead of the original captured value | Permanently changes the user's mic level if they had it set lower | Always restore to the exact value captured before the set — never restore to a hardcoded value |
| No feedback that volume was boosted | User doesn't know the feature is active | Silent operation is correct — this is invisible infrastructure, not a visible mode the user switches |
| "Gracias" fix changes other transcription behavior | Prompt tightening that stops hallucinations may also affect punctuation or filler removal | Test the full prompt against 10+ real samples after any system prompt change — regression on all existing behaviors, not just the target fix |

---

## "Looks Done But Isn't" Checklist

- [ ] **Volume settability:** `AudioObjectIsPropertySettable()` called before every set — verify on built-in mic (expected: not settable) and external USB mic (expected: settable)
- [ ] **Volume restore on Escape:** User presses Escape during recording — mic level is restored to pre-recording value
- [ ] **Volume restore on VAD silence:** Recording stops because no speech was detected — mic level is restored
- [ ] **Volume restore on Haiku error:** Network error or auth failure during cleanup — mic level is restored
- [ ] **Volume restore on transcription error:** WhisperKit throws during transcription — mic level is restored
- [ ] **Stale device ID:** USB mic was selected, then unplugged — recording works (falls back to built-in), volume is set on the correct effective device (not the disconnected USB)
- [ ] **Hallucination fix — gracias present:** User dictates "muchas gracias" — output preserves "gracias" verbatim
- [ ] **Hallucination fix — gracias absent:** Haiku output does not end with "gracias" when Whisper output did not contain it
- [ ] **Hallucination fix — other courtesy phrases:** Output does not add "de nada", "hasta luego", or similar phrases not in Whisper output
- [ ] **Hallucination fix — mid-sentence ending:** Transcription that ends mid-sentence is returned mid-sentence, not "helpfully" completed
- [ ] **Existing behavior preserved:** Punctuation, filler removal, and paragraph breaks still work after prompt change (run full regression against v1.1 test cases)
- [ ] **Volume level after restore:** Volume in System Preferences > Sound > Input matches the value it had before the first recording of the session

---

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| Volume not restored on error paths | LOW | Add restore call to each missing exit path in AppCoordinator; patch release |
| Wrong device targeted for volume | LOW | Change volume service to read device ID from running engine; 1-line fix |
| Prompt fix causes over-truncation | LOW | Revert to previous prompt as immediate rollback; redesign constraint to target addition behavior not specific tokens |
| Prompt fix stops working on new Haiku model version | MEDIUM | Add a prompt version/model version check; monitor Anthropic changelog for model updates; test prompt on each model update |
| Volume set causes mic clipping | LOW | Reduce target to 0.85 instead of 1.0; patch release |

---

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| Volume not settable on built-in mic | v1.2 Phase 1: Implementation | Test `AudioObjectIsPropertySettable()` on built-in mic before writing any set logic |
| Volume not restored on error paths | v1.2 Phase 1: Implementation | Map all 6 exit paths from recording; each must call restore if volume was set |
| Haiku adds "gracias" and similar phrases | v1.2 Phase 1: Prompt engineering | Run 10 sample transcriptions; zero outputs should contain words absent from the Whisper input |
| Prompt fix over-truncates valid "gracias" | v1.2 Phase 1: Prompt engineering | Include test case where user said "gracias" — output must preserve it |
| Volume set on wrong device (stale ID) | v1.2 Phase 1: Implementation | Test with USB mic selected, then unplugged — verify volume targets correct fallback device |
| Prompt change breaks existing punctuation/filler behavior | v1.2 Phase 2: Verification | Run full regression of v1.1 Haiku behavior after any system prompt change |
| Other RLHF courtesy phrases added (not "gracias") | v1.2 Phase 2: Verification | Expand test suite to include transcriptions ending mid-sentence and without closing punctuation |

---

## Sources

- [Core Audio Essentials — Apple Developer Documentation (archive)](https://developer.apple.com/library/archive/documentation/MusicAudio/Conceptual/CoreAudioOverview/CoreAudioEssentials/CoreAudioEssentials.html)
- [Audio APIs, Part 1: Core Audio / macOS — bastibe.de (2017, silent failure section still accurate)](https://bastibe.de/2017-06-17-audio-apis-coreaudio.html)
- [AudioObjectSetPropertyData with Bluetooth device — Apple Developer Forums thread/693516](https://developer.apple.com/forums/thread/693516)
- [Core Audio App with mic input — Apple Developer Forums thread/133283](https://developer.apple.com/forums/thread/133283)
- [SimplyCoreAudio — Swift CoreAudio wrapper (rnine/SimplyCoreAudio)](https://github.com/rnine/SimplyCoreAudio)
- [setInputGain — Apple Developer Documentation (AVAudioSession, iOS only — no macOS equivalent)](https://developer.apple.com/documentation/avfaudio/avaudiosession/1616546-setinputgain)
- [Reduce hallucinations — Anthropic Claude API Docs](https://platform.claude.com/docs/en/test-and-evaluate/strengthen-guardrails/reduce-hallucinations)
- [Prompting best practices — Anthropic Claude API Docs](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/claude-prompting-best-practices)
- [Avoiding Hallucinations — Anthropic Courses (prompt engineering tutorial)](https://github.com/anthropics/courses/blob/master/prompt_engineering_interactive_tutorial/Anthropic%201P/08_Avoiding_Hallucinations.ipynb)
- [Extrinsic Hallucinations in LLMs — Lil'Log (Lilian Weng, 2024)](https://lilianweng.github.io/posts/2024-07-07-hallucination/)
- [Technical Note TN2091: Device input using the HAL Output Audio Unit — Apple Developer](https://developer.apple.com/library/archive/technotes/tn2091/_index.html)

---

## Appendix: Pre-existing Pitfalls (Still Applicable)

The following pitfalls from prior milestones remain valid. They are documented in the 2026-03-16 version of this file (v1.1 Pause Playback) and not duplicated here:

- MediaRemote private API broken on macOS 15.4+ (v1.1 addressed)
- Resuming user-paused media (v1.1 addressed with toggle semantics)
- AVAudioEngine sample rate mismatch (v1.0 addressed)
- Whisper hallucination on silence / VAD gate (v1.0 addressed)
- CGEventPost blocked in sandboxed apps (v1.0 addressed — non-sandboxed distribution)
- Accessibility permission lost on Xcode rebuild (v1.0 addressed)
- LLM rewrites text meaning (v1.0 addressed — existing rule 5 in system prompt)
- Stale microphone device ID from UserDefaults (v1.0 addressed in AudioRecorder.start())

---
*Pitfalls research for: v1.2 Dictation Quality — CoreAudio mic volume control + Haiku hallucination fix*
*Researched: 2026-03-17*
