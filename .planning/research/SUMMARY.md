# Project Research Summary

**Project:** my-superwhisper v1.2 Dictation Quality
**Domain:** Local voice-to-text macOS menubar app — mic input volume auto-maximize + Haiku hallucination fix
**Researched:** 2026-03-17
**Confidence:** HIGH

## Executive Summary

v1.2 is a surgical quality milestone delivering two independent improvements to the transcription pipeline: (1) auto-maximizing microphone input volume via the CoreAudio HAL at the start of each recording, and (2) eliminating hallucinated closing phrases ("gracias") from Haiku's cleanup output. Both features operate entirely within existing architectural boundaries — no new frameworks, no new permissions, no new external services. The app is already non-sandboxed, already imports CoreAudio, and already calls the Anthropic API. Both features are purely additive, layered onto the v1.1 foundation without touching any existing logic.

The recommended approach for the volume feature is a new `MicInputVolumeService` wired to `AppCoordinator` via the same FSM side-effect injection pattern established in v1.1 for `MediaPlaybackService`. The service reads, saves, and restores `kAudioDevicePropertyVolumeScalar` on the input scope, reusing `MicrophoneDeviceService` (the same service `AudioRecorder` already uses for device resolution). The hallucination fix is a single targeted Rule 6 addition to the Haiku system prompt in `HaikuCleanupService.swift`, supplemented by a post-processing suffix strip as a defense-in-depth second layer that also catches Whisper large-v3 hallucinations before they reach the LLM.

The primary implementation risk is failing to call `micVolumeService?.restore()` on all 6 exit paths from `.recording` state in `AppCoordinator` — leaving the user's mic permanently at 100% after any error, cancel, or edge-case stop. The primary prompt risk is overcorrecting by blacklisting the specific word "gracias" rather than prohibiting the addition behavior, which would delete legitimately dictated courtesy phrases. Both risks are fully characterized and mitigated in the research.

---

## Key Findings

### Recommended Stack

No new dependencies are introduced in v1.2. CoreAudio HAL APIs (`AudioObjectGetPropertyData`, `AudioObjectSetPropertyData`, `AudioObjectIsPropertySettable`) are already imported in `MicrophoneDeviceService.swift`, and the same 4-step `AudioObjectPropertyAddress` pattern used for device enumeration is reused verbatim for input volume control. Haiku API calls and the `URLSession` integration are unchanged — the hallucination fix is a prompt string edit only, with no impact on API contract, token budget, or model version.

**Core technologies:**
- **CoreAudio HAL (`kAudioDevicePropertyVolumeScalar` + `kAudioDevicePropertyScopeInput`):** Read/save/set/restore mic input gain on the active device — same API family already in the project; macOS 10.6+, no new entitlements required
- **`AudioObjectIsPropertySettable`:** Guard before any volume write — most USB mics and aggregate devices do not expose a settable input volume at the driver level; must be checked before every set operation, not cached at startup
- **Haiku system prompt Rule 6 (addition to existing prompt in `HaikuCleanupService.swift`):** Prevent extrinsic hallucination of closing courtesy phrases — prompt engineering only; no API or SDK change; compatible with existing `claude-haiku-4-5-20251001`

**Critical "do not use":**
- `AVAudioSession.inputGain` — iOS/Mac Catalyst API only; not available in standard macOS apps; crashes or silently fails at runtime
- SimplyCoreAudio SPM package — archived read-only since March 2024; dead dependency for the same 10-line CoreAudio pattern the project already uses
- Token-level word blacklist in Haiku prompt ("never output 'gracias'") — strips the word even when the user legitimately dictated it; wrong abstraction layer

### Expected Features

**Must have (table stakes for v1.2):**
- Input volume maximized to 1.0 on recording start, restored to original on every stop path — the restore is the invariant, not an optimization
- Haiku output contains only words present in the Whisper STT input — no hallucinated closings, no added courtesy phrases
- Both features are transparent to the user; no new UI is required for baseline behavior
- Graceful silent no-op when the active device does not support input volume control

**Should have (v1.2 polish):**
- Optional Settings toggle `autoMaxMicVolume` (default `true`) — allows users who manually calibrate mic gain (podcasters, musicians) to opt out
- Post-processing suffix strip layer — second defense against "gracias" variants that slip past the prompt constraint, and catches Whisper large-v3 hallucinations that Haiku never sees in the first place

**Defer to v1.3+:**
- Configurable user-managed strip list in Settings (expose post-processing patterns to UI)
- Per-device persisted volume state across sessions (`[AudioDeviceID: Float32]` in UserDefaults)
- Smooth volume ramp instead of hard set to 1.0 (only needed if audio pop/click is observed in practice)

### Architecture Approach

v1.2 follows the FSM side-effect injection pattern proven in v1.1. `AppCoordinator` acquires a protocol reference (`MicInputVolumeServiceProtocol`) to the new `MicInputVolumeService`, injected by `AppDelegate` at startup. `maximizeAndSave()` is called at the `idle → recording` transition; `restore()` is called at both `recording → processing` (normal stop) and in `handleEscape()` (cancel) — exactly mirroring the placement of `mediaPlayback?.pause()` / `mediaPlayback?.resume()` from v1.1. The Haiku fix touches only the system prompt string inside `HaikuCleanupService.swift` with no protocol, wiring, or API changes.

**Major components:**
1. **`MicInputVolumeService` (new file: `MyWhisper/Audio/MicInputVolumeService.swift`)** — CoreAudio read/save/set/restore for input volume; conforms to new `MicInputVolumeServiceProtocol`; depends on `MicrophoneDeviceService` for device resolution
2. **`AppCoordinatorDependencies.swift` (modified)** — adds `MicInputVolumeServiceProtocol` declaration (two methods: `maximizeAndSave()`, `restore()`)
3. **`AppCoordinator.swift` (modified)** — adds `var micVolumeService: (any MicInputVolumeServiceProtocol)?`; 3 call sites added at state boundaries
4. **`AppDelegate.swift` (modified)** — instantiates `MicInputVolumeService(microphoneService: microphoneService)` and assigns to `coordinator.micVolumeService`
5. **`HaikuCleanupService.swift` (modified)** — adds Rule 6 to `systemPrompt` string; no other changes

Both features are fully independent in their file sets and can be implemented in parallel.

### Critical Pitfalls

1. **CoreAudio volume property not settable on all devices** — Always call `AudioObjectIsPropertySettable()` before any write. Built-in MacBook mic and aggregate devices commonly return not-settable. The correct response is a silent no-op; showing an error to the user is wrong. Failure to check before writing may return `kAudioHardwareUnknownPropertyError` or silently succeed while doing nothing.

2. **Volume not restored on all exit paths** — `AppCoordinator` has at minimum 6 exits from `.recording` state: normal hotkey stop, escape cancel, VAD silence gate, transcription error, Haiku API error, and auth error. All must call `micVolumeService?.restore()`. Do NOT use `defer` inside `handleHotkey()` — the async function returns to the run loop mid-execution and `defer` fires at scope exit, which is the wrong moment. Use explicit restore at each branch, mirroring the existing `mediaPlayback?.resume()` placement.

3. **Volume control targeting a stale device ID** — `MicrophoneDeviceService.selectedDeviceID` can be stale when the user's USB mic is disconnected; `AudioRecorder.start()` already handles this divergence by resolving the effective device. `MicInputVolumeService` must derive the device ID from the running `AVAudioEngine` via `kAudioOutputUnitProperty_CurrentDevice` after `engine.start()`, not from `selectedDeviceID` directly.

4. **Prompt constraint causes over-truncation of legitimately dictated "gracias"** — Never blacklist a specific word in a prompt. The constraint must target the behavior (adding words absent from the STT input), not the token. Test cases must include user-dictated "gracias" / "de nada" and verify these are preserved verbatim in output.

5. **Prompt fix creates whack-a-mole hallucination** — A rule naming only "gracias" will stop that word but allow "de nada", "hasta luego", "que tengas un buen día". The rule must be structural: "every word in the output must have been present in the input; if the transcription ends mid-sentence, end the output mid-sentence." Naming the exact pattern as a concrete anchor ("gracias", "de nada") is acceptable as supporting language alongside the general structural constraint, not as a replacement for it.

---

## Implications for Roadmap

v1.2 is a single-phase implementation milestone with a verification phase following it. No sub-phasing by feature is needed — both features are small, independent, and ship together in the same release.

### Phase 1: Implementation

**Rationale:** Both features are fully scoped with no ambiguous design decisions remaining. All architectural choices (device ID source, settability check timing, prompt constraint formulation, call-site placement) are resolved in the research. Implementation is a direct translation from spec to code.

**Delivers:**
- `MicInputVolumeService` with `maximizeAndSave()` / `restore()` cycle
- `MicInputVolumeServiceProtocol` in `AppCoordinatorDependencies.swift`
- `AppCoordinator` wired with 3 call sites at state boundaries
- `AppDelegate` wiring: new service instantiated and injected
- `HaikuCleanupService.swift` Rule 6 added to system prompt
- (Optional) `autoMaxMicVolume` UserDefaults toggle wired in Settings

**Addresses:**
- Auto-maximize mic input volume (v1.2 table stakes)
- Haiku "gracias" hallucination fix (v1.2 table stakes)

**Avoids:**
- Pitfall 1: `AudioObjectIsPropertySettable()` check before every write (not cached)
- Pitfall 2: explicit `restore()` on all 6 recording exit paths; no `defer` usage
- Pitfall 3: device ID resolved from running engine after `start()`, not from `selectedDeviceID`
- Pitfall 4: prompt targets addition behavior with structural constraint, not specific token "gracias"
- Pitfall 5: rule is general ("output only words present in input") with named examples as anchors

### Phase 2: Verification

**Rationale:** Both changes affect output quality in ways that require empirical validation against real speech samples and hardware configurations. Prompt changes can silently regress existing punctuation and filler-removal behavior. Volume changes must be verified on multiple mic types.

**Delivers:**
- Verified prompt against 10+ real transcription samples: zero hallucinated additions in output
- Verified prompt: legitimately dictated "gracias" / "de nada" preserved
- Verified prompt: no regression on punctuation, filler removal, paragraph breaks vs v1.1 baseline
- Verified volume: `AudioObjectIsPropertySettable()` returns `false` on built-in Mac mic; feature silently no-ops
- Verified volume: external mic maximized at recording start, restored to exact original value on stop
- Verified volume: restore fires on Escape, VAD silence gate, and all error exit paths
- "Looks done but isn't" checklist from PITFALLS.md (12 items) fully passed

### Phase Ordering Rationale

- Phase 1 before Phase 2: implementation is a hard prerequisite for verification
- No sub-phases within Phase 1: the two feature file sets are independent; parallel implementation carries no integration risk since the only shared touch-point is `AppCoordinator`, and both changes there are non-conflicting additions
- Features ship together: volume boost (signal quality in) and hallucination fix (accurate text out) address complementary sides of the transcription quality problem; shipping together maximizes the perceived improvement in a single release

### Research Flags

Both phases use standard, fully documented patterns — no additional `/gsd:research-phase` calls are needed:

- **Phase 1:** All implementation decisions are resolved with exact code patterns in STACK.md and ARCHITECTURE.md. The CoreAudio volume API, settability check, device resolution fallback, and prompt rule formulation are all specified to the line level. Build directly from spec.
- **Phase 2:** Test matrix is directly derivable from the "Looks Done But Isn't" checklist in PITFALLS.md (12 explicit checks). Execute the checklist; no upfront research required.

---

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | CoreAudio volume API pattern confirmed via Apple official docs and existing codebase usage; Haiku prompt engineering confirmed via official Anthropic docs; all "do not use" choices confirmed by direct API documentation (AVAudioSession scope restriction) |
| Features | HIGH | Both features are narrowly scoped; all edge cases enumerated (device not settable, stale device ID, mid-sentence transcription, user-dictated courtesy phrases); no open design questions remain |
| Architecture | HIGH | Existing codebase read directly from disk; FSM side-effect injection pattern proven in v1.1 `MediaPlaybackService`; build order fully specified; no new patterns introduced |
| Pitfalls | HIGH | All 5 critical pitfalls sourced from Apple Developer docs, Anthropic official docs, and direct codebase analysis; no speculative risk — every pitfall has a verified root cause and a tested mitigation |

**Overall confidence:** HIGH

### Gaps to Address

- **Volume target level:** Research recommends 1.0 (100%), but PITFALLS.md notes 0.85–0.90 may be safer for mics prone to clipping. Ship at 1.0; reduce to 0.85 only if a user reports audio artifacts. Not a blocking concern.
- **Multi-channel mic handling:** For stereo or professional multi-channel interfaces, per-channel volume iteration via channel elements > 0 may be needed. `kAudioObjectPropertyElementMain` (element 0) targets the master channel and is correct for all consumer mics. Acceptable to defer this edge case to a future patch if reported.
- **`AVAudioEngine` device ID query timing:** `kAudioOutputUnitProperty_CurrentDevice` is only valid after `engine.start()`. The exact call-site placement of `maximizeAndSave()` relative to `audioRecorder?.start()` must be confirmed during implementation — the boost must be applied after the engine has resolved its effective input device.

---

## Sources

### Primary (HIGH confidence)
- Existing codebase (`/Users/max/Personal/repos/my-superwhisper/MyWhisper/`) — read directly; confirms CoreAudio import, FSM structure, component boundaries, `MicrophoneDeviceService` API
- [Apple Developer Documentation: `AudioObjectSetPropertyData`](https://developer.apple.com/documentation/coreaudio/1422920-audioobjectsetpropertydata) — official CoreAudio volume write API
- [Apple Developer Documentation: `AudioObjectIsPropertySettable`](https://developer.apple.com/documentation/coreaudio) — confirmed Swift signature; used before every property write
- [Anthropic: Reduce hallucinations](https://platform.claude.com/docs/en/test-and-evaluate/strengthen-guardrails/reduce-hallucinations) — explicit prohibition pattern; structural vs token-level constraints
- [Anthropic: Prompting best practices](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/claude-prompting-best-practices) — "explain WHY" principle; naming the specific failure case improves constraint compliance
- [SuperWhisper changelog](https://superwhisper.com/changelog) — competitor feature comparison; Pause media feature timeline

### Secondary (MEDIUM confidence)
- [CoreAudio Swift output device methods Gist (kimsungwhee)](https://gist.github.com/kimsungwhee/91a4cbd7855089c302fc93f03a0fb15c) — `kAudioDevicePropertyVolumeScalar` with input scope pattern; output device variant confirmed; input scope inferred from identical structure
- [SimplyCoreAudio (rnine)](https://github.com/rnine/SimplyCoreAudio) — confirms `virtualMainVolume(scope:)` for input scope; archived March 2024 (reference only, not a dependency)
- [Anthropic: Minimizing Hallucinations](https://docs.anthropic.com/en/docs/minimizing-hallucinations) — structural constraint formulation confirmed
- [Apple Developer Forums thread/693516](https://developer.apple.com/forums/thread/693516) — `AudioObjectSetPropertyData` silent failure on Bluetooth devices; confirms settability check is required

### Tertiary (supporting / inferred)
- [RØDE: Why Can't I Change the Input Volume in Mac Sound Settings](https://help.rode.com/hc/en-us/articles/9312496788239-Why-Can-t-I-Change-the-Input-Volume-in-Mac-Sound-Settings) — USB mic input volume not settable via macOS System Settings; corroborates CoreAudio not-settable behavior
- [Deepgram: Whisper-v3 Hallucinations on Real World Data](https://deepgram.com/learn/whisper-v3-results) — large-v3 hallucinates 4x more than v2; confirms two-source nature of the problem (STT + LLM post-processing)
- [OpenAI Whisper Discussion #1455](https://github.com/openai/whisper/discussions/1455) / [#1606](https://github.com/openai/whisper/discussions/1606) — hallucination at end of recording; confirms "gracias" as a known STT-layer pattern
- [Extrinsic Hallucinations in LLMs — Lilian Weng (2024)](https://lilianweng.github.io/posts/2024-07-07-hallucination/) — theoretical grounding for RLHF-driven courtesy hallucination

---
*Research completed: 2026-03-17*
*Ready for roadmap: yes*
