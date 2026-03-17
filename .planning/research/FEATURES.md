# Feature Research

**Domain:** Local voice-to-text macOS menubar application
**Researched:** 2026-03-15 (v1.0) / Updated 2026-03-16 (v1.1 Pause Playback milestone) / Updated 2026-03-17 (v1.2 Dictation Quality milestone)
**Confidence:** HIGH (primary sources: SuperWhisper official docs, Sotto, WhisperFlow, Wispr Flow, macOS Dictation official docs, multiple competitor analyses, OpenAI Whisper GitHub discussions, Anthropic prompt engineering docs, CoreAudio documentation)

---

## Feature Landscape

### Table Stakes (Users Expect These)

Features users assume exist. Missing these = product feels incomplete.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Global hotkey to toggle recording | Every competitor has it; users expect one-key activation from any app | LOW | Requires Accessibility permission. Default is toggle mode (press to start, press to stop). SuperWhisper uses ⌥+Space, Sotto and WhisperFlow use hold-to-talk |
| Push-to-talk alternative | SuperWhisper, Sotto, WhisperFlow all offer it; power users prefer hold-and-release for short bursts | LOW | Same hotkey, dual behavior: quick press = toggle, hold = push-to-talk |
| Auto-paste at cursor position | Eliminated the manual copy-paste step is the core value proposition across all tools | MEDIUM | Requires Accessibility permission (simulate Cmd+V or type keystrokes). Most apps use pbcopy + Cmd+V simulation. Some apps offer clipboard-only fallback |
| Menubar status icon with recording states | Users need to know if the app is listening. Menubar is the macOS convention for background apps | LOW | Minimum: idle / recording / processing states. SuperWhisper uses color-coded dots (yellow=loading, blue=processing, green=done) |
| Visual feedback during recording (waveform) | Without waveform/animation, users don't know if the mic is capturing. Every mature tool shows this | LOW | Animated waveform during active recording is the standard. macOS Tahoe native dictation introduced Liquid Glass waveform overlay in 2025 |
| Filler word removal | Users hate seeing "eh", "um", "like" in output. All major tools advertise this | MEDIUM | Requires LLM post-processing step. Simple rules-based removal is not enough for natural speech — needs context to avoid removing meaningful repetition |
| Punctuation and capitalization | Raw Whisper output has no punctuation. Users expect clean sentences | MEDIUM | Either Whisper's built-in punctuation (unreliable) or LLM post-processing pass. LLM produces significantly better results |
| Works in any app (system-wide) | Users dictate into Slack, email, code editors, notes — it must work everywhere | LOW | Requires Accessibility permission for keystroke simulation. Some apps use clipboard approach as fallback for apps that block direct input |
| Configurable hotkey | Different users have different shortcuts. Ctrl+Space conflicts with some apps (e.g. Spotlight-adjacent shortcuts) | LOW | Settings UI to remap. Persist to user defaults. Validate for conflicts |
| Reasonable latency (under 5s for typical dictation) | Users break flow if they wait too long. 3-5s is the accepted ceiling for 30-60s recordings | HIGH | Apple Silicon Neural Engine makes local Whisper viable. Whisper.cpp with MLX achieves 2-4x realtime on M1/M2 |
| Microphone selection | Users may have multiple audio inputs (USB mic, headset, built-in). Must be able to choose | LOW | Use macOS AVAudioSession/CoreAudio device enumeration |
| **LLM output must not hallucinate new words** | Users expect the cleaned text to be their words only — any added word breaks trust | MEDIUM | Whisper-to-Haiku pipeline: both the STT model and LLM can add words not spoken. Requires explicit prompt constraints. Documented issue: Whisper large-v3 hallucinates 4x more than v2 |

### Differentiators (Competitive Advantage)

Features that set the product apart. Not required, but valued.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| 100% local processing (no network calls) | Privacy-first users won't use cloud tools. Wispr Flow and most competitors send audio to cloud. SuperWhisper is the only major local competitor | HIGH | Requires bundling or managing local model weights. 2-4GB for Whisper large-v3, 1-8GB for LLM. Offline operation is a hard guarantee |
| Spanish-optimized transcription | Spanish speakers are underserved. Most tools default to English model selection and English filler word lists | MEDIUM | Choose Whisper model variant best for Spanish. Customize LLM cleanup prompt for Spanish filler words: "eh", "este", "o sea", "bueno", repetition patterns |
| Spanish-aware filler word removal | "O sea", "este", "bueno", "pues" are Spanish-specific fillers not handled by generic English-trained cleanup | MEDIUM | LLM prompt must be language-specific. Generic English prompts miss these entirely |
| Accurate processing state display | Users want to know what's happening: recording / transcribing / cleaning / pasting. Most apps show one "processing" state | LOW | 4-state indicator: idle → recording → transcribing → cleaning → done. Reduces perceived wait time |
| Graceful cancel during recording | Users make mistakes and need to abort without pasting garbage text | LOW | Cancel button in recording UI + keyboard shortcut (Escape). SuperWhisper shows cancel option on hover |
| Lightweight idle resource usage | Wispr Flow uses ~800MB RAM idle — users complain loudly. A lean background app is a competitive advantage | MEDIUM | Unload models when idle. Lazy-load on first hotkey press. Target <50MB idle RAM |
| Custom vocabulary / corrections | Names, technical terms, brand names that Whisper consistently mishears. Users expect to teach the app | MEDIUM | Post-processing correction dictionary: map "Miguel" → correct spelling, "Kubernetes" → exact casing. Applied after LLM cleanup |
| Transaction history / recent transcriptions | Users need to recover accidentally dismissed text, or re-read what they said | LOW | In-memory list of last N transcriptions. Copy from history. No persistent disk storage required for v1 |
| Configurable LLM cleanup aggressiveness | Some users want light touch (just punctuation), others want heavy cleanup (restructure sentences) | MEDIUM | Two modes: "Light" (punctuation + capitalization only) and "Full" (filler removal + light restructuring). Single LLM call with different prompts |
| **Auto-maximize microphone input volume during recording** | Low mic gain is the most common cause of poor transcription quality. Users don't know to check System Settings. Auto-maxing on record start silently solves it | MEDIUM | CoreAudio: read `kAudioDevicePropertyVolumeScalar` with input scope before recording, set to 1.0, restore on stop. Not all devices expose this property — graceful fallback required |

### Anti-Features (Commonly Requested, Often Problematic)

Features that seem good but create problems.

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| Real-time streaming transcription | Feels more responsive, shows words as spoken | Doubles complexity: requires streaming Whisper (harder with local models), creates partial-text paste races, degrades accuracy vs batch. Most local tools don't offer it | Show waveform animation during recording to signal activity. Batch transcribe is fine with 3-5s latency |
| Multiple language support | Users switch between Spanish and English | Requires separate model configs or multilingual model (larger, slower). V1 scope must stay focused to ship | Spanish-only v1, design the language config so a second language can be added later without refactoring |
| Cloud fallback for accuracy | When local fails, use cloud | Breaks the privacy guarantee, adds network dependency, requires API key management, creates inconsistent UX | Invest in model selection upfront. Use best available local model. Accept slight accuracy tradeoff for privacy guarantee |
| Voice commands (navigation, macros) | "Delete last word", "new paragraph", "open Slack" | Voice command parsing requires a separate always-listening model. Massively increases scope and Accessibility permission complexity | Out of scope v1. Auto-paste at cursor handles the core use case without navigation commands |
| Audio file import / transcription | Transcribe existing recordings | Different UX entirely (file picker, no hotkey), different pipeline (no LLM cleanup needed), different output target (file vs clipboard). Doubles surface area | Not v1. Keep app focused on live dictation |
| Meeting recording & summarization | Record entire meetings and get notes | Background recording raises serious consent and privacy concerns on macOS, requires much larger storage, completely different product mode | Separate product concern. Scope dictation app for active dictation only |
| AI reformulation / professional rewriting modes | Rewrite casual speech as formal email or JIRA ticket | Requires powerful LLM and significantly longer processing time. Quality degrades heavily with small local models. Creates uncertain output users can't predict | V1: punctuation + filler removal only, output is recognizably what the user said. Add reformulation modes after validating local LLM quality |
| Continuous/always-on dictation | App stays in listening mode permanently | Massively increases CPU/memory usage, creates accidental transcription risk, complicates "when does it paste?" logic | Explicit toggle/push-to-talk is superior UX for intentional dictation |
| **Aggressive VAD (voice activity detection) filtering before STT** | Prevent Whisper from hallucinating on silence | Cutting audio aggressively can clip the start/end of speech. False positives cause missed words | Use Whisper's built-in no-speech probability. Only hard-discard if no speech detected at all. Do not aggressively trim silence |
| **Prompt-level wordlist blacklist as sole defense** | Block "gracias" by telling Haiku "never output this word" | LLM word blacklists are unreliable — model may rephrase the forbidden word into synonyms, or ignore the prohibition. Brittle maintenance as hallucinations evolve | Post-processing string detection is the reliable final defense. Prompt constraints are supporting layer only |
| **Always set mic volume to max (no restore)** | Simplest implementation | Leaves user's system audio input at 100% permanently. User has carefully calibrated their mic gain — overwriting without restoring is hostile | Read current value before set; restore exactly on stop. Never change without restoring. Skip the set if device does not support it |

---

## Feature Dependencies

```
[Global Hotkey Capture]
    └──requires──> [Accessibility Permission]
                       └──enables──> [Auto-Paste (Cmd+V simulation)]

[Auto-Paste]
    └──requires──> [Accessibility Permission]
    └──requires──> [Transcription Pipeline complete]

[Transcription Pipeline]
    └──requires──> [Audio Capture]
                       └──requires──> [Microphone Permission]
    └──requires──> [Local STT Model loaded]
    └──produces──> [Raw transcript]

[LLM Cleanup]
    └──requires──> [Raw transcript from STT]
    └──requires──> [Local LLM loaded/running]
    └──produces──> [Clean text]

[Clean text]
    └──feeds──> [Auto-Paste]
    └──feeds──> [History Log]

[Visual Feedback / Waveform]
    └──requires──> [Audio Capture running]
    └──enhances──> [Recording state display]

[Menubar Status Icon]
    └──enhances──> [Recording states] (idle/recording/processing/done)
    └──requires──> [App running as NSStatusItem]

[Custom Vocabulary]
    └──enhances──> [LLM Cleanup] (post-processing corrections)
    └──optionally replaces──> [manual re-editing by user]

[Configurable Hotkey]
    └──enhances──> [Global Hotkey Capture]

[Push-to-Talk mode]
    └──alternative-to──> [Toggle mode]
    └──shares implementation with──> [Global Hotkey Capture]

[History Log]
    └──requires──> [Clean text output]
    └──depends-on──> [in-memory storage]

[Pause Playback]
    └──triggered-by──> [Recording starts (hotkey pressed)]
    └──reverses-on──> [Recording ends (hotkey pressed again / recording complete)]
    └──requires──> [Settings toggle enabled]
    └──uses──> [Media key simulation via CGEvent/NSEvent]
    └──no new permissions required (non-sandboxed app)

[Prevent "gracias" hallucination]
    └──addresses──> [Whisper large-v3 known end-of-phrase hallucination bug]
    └──addresses──> [Haiku LLM adding courtesy words not in STT output]
    └──layer-1──> [Haiku system prompt: explicit PROHIBIDO rule for adding words]
    └──layer-2──> [Post-processing: strip known hallucination strings after LLM output]
    └──no new permissions required]

[Auto-maximize mic input volume]
    └──triggered-by──> [Recording starts]
    └──reverses-on──> [Recording stops (any path: complete, cancel, error)]
    └──uses──> [CoreAudio: AudioObjectGetPropertyData / AudioObjectSetPropertyData]
    └──uses──> [kAudioDevicePropertyVolumeScalar with kAudioDevicePropertyScopeInput]
    └──reads──> [AudioObjectHasProperty — must check support before set]
    └──depends-on──> [MicrophoneDeviceService.selectedDeviceID (existing)]
    └──no new permissions required]
```

### Dependency Notes

- **Auto-Paste requires Accessibility Permission:** macOS requires the app be granted Accessibility access in System Settings to simulate Cmd+V keystrokes or type into other applications. This is a hard gate — app must prompt for this on first launch.
- **Transcription requires Microphone Permission:** Separate from Accessibility. Two distinct permission prompts are required on first use.
- **LLM Cleanup requires STT output:** The pipeline is sequential: record → transcribe → clean → paste. LLM cannot run until STT finishes. No parallelism is possible in the core pipeline.
- **Waveform enhances Recording State:** Waveform animation is the most important visual signal during recording. Menubar icon state alone is not sufficient feedback.
- **Custom Vocabulary post-processes LLM output:** Correction dictionary applies after LLM cleanup to fix persistent misrecognitions. Applying before LLM would allow LLM to "fix" the corrections.
- **Pause Playback requires no new permissions:** The app is non-sandboxed (Developer ID). Simulating media key events via CGEventPost is already used for paste simulation. No Accessibility or Input Monitoring entitlements beyond what v1.0 already has.
- **"Gracias" fix is a two-layer defense:** Prompt engineering alone is not reliable — LLMs can ignore prohibitions or rephrase. Post-processing string detection is the safe last line. Both layers together provide defense-in-depth.
- **Mic volume auto-max requires graceful fallback:** Not all microphone devices expose `kAudioDevicePropertyVolumeScalar` on input scope. Built-in mic on many Macs does not support software volume control at the driver level. Must check `AudioObjectHasProperty` before attempting set/restore. Feature silently no-ops if device does not support it.
- **Mic volume restore must run on every stop path:** Recording can end via: (a) hotkey stop, (b) Escape cancel, (c) error/timeout. All three paths must restore the saved volume level to avoid leaving user's mic permanently at max.

---

## MVP Definition

### Launch With (v1)

Minimum viable product — what's needed to validate the concept.

- [x] Global hotkey (Option+Space) toggles recording from anywhere — core interaction model — **SHIPPED v1.0**
- [x] Audio capture from selected microphone while recording is active — **SHIPPED v1.0**
- [x] Menubar status icon: 3 states minimum (idle / recording / processing) — **SHIPPED v1.0**
- [x] Waveform animation during recording — essential feedback — **SHIPPED v1.0**
- [x] Local STT transcription (WhisperKit large-v3) optimized for Spanish — **SHIPPED v1.0**
- [x] LLM post-processing: punctuation, capitalization, filler word removal (Spanish-aware) — **SHIPPED v1.0**
- [x] Auto-paste clean text at cursor position — **SHIPPED v1.0**
- [x] Permission prompts on first launch (Accessibility + Microphone) — **SHIPPED v1.0**
- [x] Configurable hotkey in settings — **SHIPPED v1.0**
- [x] Microphone selection in settings — **SHIPPED v1.0**

### Add After Validation (v1.x)

Features to add once core is working.

- [x] **Pause Playback (v1.1):** Auto-pause media when recording starts, resume when recording ends, with Settings toggle — **SHIPPED v1.1**
- [ ] **Prevent "gracias" hallucination (v1.2):** Dual-layer fix — Haiku prompt constraint + post-processing strip
- [ ] **Auto-maximize mic input volume (v1.2):** CoreAudio read/set/restore on recording start/stop, with graceful fallback
- [ ] Push-to-talk mode (hold hotkey vs toggle) — many users prefer this, low complexity to add
- [ ] Configurable LLM cleanup aggressiveness (light/full modes) — nice to have, not blocking

### Future Consideration (v2+)

Features to defer until product-market fit is established.

- [ ] Reformulation modes (formal email, structured notes) — needs powerful local LLM; validate accuracy first
- [ ] Second language support — add Spanish+English after v1 proves the architecture
- [ ] Keyboard-driven history navigation — power user feature only

---

## v1.2 Milestone: Dictation Quality — Feature Detail

### Feature 1: Prevent "gracias" Hallucination

#### What the Problem Is

Two distinct sources can add words the user never said:

1. **Whisper large-v3 hallucinations:** Whisper is known to hallucinate end-of-phrase words from its training data (YouTube subtitles: "thanks for watching", "gracias", "thank you"). This affects large-v3 more than v2 — large-v3 hallucinates ~4x more. Occurs especially at the end of recordings where silence or low-energy audio precedes the model's final token prediction. Spanish language model output commonly adds "gracias" as a polite closing.

2. **Haiku LLM adding courtesy words:** Even if Whisper transcribes cleanly, the Haiku cleanup model may "helpfully" add closing phrases to what it perceives as complete conversational text. The current system prompt (rule 5: "NO agregues palabras que no estaban") is good but does not specifically call out the "gracias" pattern as a known failure mode.

#### Mechanism: Two-Layer Defense

**Layer 1 — Prompt reinforcement (Haiku system prompt):**
Add explicit language to the existing system prompt rule 5 that names the specific failure: "NO agregues palabras de cortesía ni cierres como 'gracias', 'de nada', 'hasta luego' ni equivalentes." The pattern of naming the exact forbidden output (rather than only describing the category) is the most effective prompt constraint technique per Anthropic's own prompting best practices.

**Layer 2 — Post-processing string strip:**
After Haiku returns cleaned text, scan the end of the string for known hallucination patterns using case-insensitive suffix matching. Strip matches before passing to auto-paste. Known patterns for Spanish Whisper large-v3: "gracias", "gracias.", "gracias!", "muchas gracias", "de nada". This layer catches both Whisper hallucinations and any Haiku additions that slip past the prompt.

**Why both layers are needed:**
Prompt constraints alone are not reliable — LLMs can ignore prohibitions or produce semantically equivalent output. Post-processing string detection alone would miss novel variants. Defense-in-depth is the standard pattern for LLM output control.

#### Table Stakes for "gracias" Fix

| Behavior | Why Expected | Complexity | Notes |
|----------|--------------|------------|-------|
| Text output contains only what was dictated | Core product promise: voice in = same text out, just cleaned | LOW | Prompt constraint — modify existing `systemPrompt` in `HaikuCleanupService.swift` |
| Known hallucinated patterns stripped | Defense against both STT and LLM hallucination sources | LOW | Post-processing after `HaikuCleanupService.clean()` returns, before paste |
| Vocabulary corrections still apply after strip | Existing correction pipeline must not be disrupted | LOW | Strip happens in coordinator after Haiku, before vocabulary correction step |
| No false positives on legitimate "gracias" | If user dictated "gracias" intentionally, it must survive | MEDIUM | Post-processing must only match isolated trailing "gracias" — not "te doy las gracias porque..." in the middle of text. Use suffix match with word boundary. |

#### Differentiators for "gracias" Fix

| Behavior | Value | Complexity | Notes |
|----------|-------|------------|-------|
| Configurable strip list in Settings | Power users may want to add their own known-bad patterns | MEDIUM | UserDefaults array of strings. UI would be a small text field list in Settings. Probably v1.3 scope |
| Logging hallucinationed strips for debugging | User can see that something was stripped (e.g., "cleaned: removed trailing 'gracias'") in History entry | LOW | Flag in TranscriptionHistoryService that a strip occurred — visible in History as indicator |

#### Anti-Features for "gracias" Fix

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| Wordlist-only approach (no prompt change) | Simpler than modifying prompt | Prompt is the first line of defense; skipping it means post-processing does all the work. Post-processing is fragile for novel variants | Use both layers |
| Aggressive sentence-end stripping | "Remove all Whisper hallucination patterns we know about" | Broadening the strip list without testing creates false positives on legitimate speech | Narrow initial list to confirmed patterns. Expand with evidence |
| Suppress tokens in WhisperKit transcription | Block "gracias" at STT level | WhisperKit exposes limited suppress_tokens control; suppressing a common Spanish word can degrade transcription for dictated "gracias" | Layer approach preserves dictated "gracias" |

---

### Feature 2: Auto-Maximize Microphone Input Volume

#### What the Feature Does

When recording starts, the app reads the current system-level input volume for the active microphone device, saves it, then sets the input volume to 1.0 (maximum). When recording ends (any path: complete, cancel, error), the app restores the saved original volume. The feature is transparent to the user — no new UI toggle unless they ask for it.

#### Why This Matters

Low microphone input gain is the single most common cause of poor transcription quality with local Whisper models. WhisperKit's large-v3 needs a clean, loud-enough signal to produce accurate Spanish transcription. Users who have their mic at 50-70% (common for video calls where auto-gain is used) will experience degraded transcription. Auto-maximizing on each recording ensures the model gets the best signal without requiring the user to manually adjust System Settings before each session.

#### Mechanism: CoreAudio kAudioDevicePropertyVolumeScalar

**API:**
```
AudioObjectGetPropertyData(deviceID, &propertyAddress, 0, nil, &dataSize, &volume)
AudioObjectSetPropertyData(deviceID, &propertyAddress, 0, nil, dataSize, &volume)
```
Where `propertyAddress` uses:
- `mSelector: kAudioDevicePropertyVolumeScalar`
- `mScope: kAudioDevicePropertyScopeInput`
- `mElement: kAudioObjectPropertyElementMain` (for master/global channel) or per-channel

**Critical limitation:** Not all audio input devices expose `kAudioDevicePropertyVolumeScalar` on the input scope. Many built-in microphones on Macs do not support software input volume control at the driver level. The app must call `AudioObjectHasProperty` first. If the property is not available, the feature silently no-ops — recording proceeds at whatever level the system is set to.

**Scope of change:**
- New `MicVolumeService` (or extension of existing `MicrophoneDeviceService`) with `readVolume(deviceID:)`, `setVolume(deviceID:value:)`, `hasVolumeControl(deviceID:)` methods.
- `AppCoordinator` calls `micVolumeService.boost()` on `recordingDidStart`, and `micVolumeService.restore()` on all recording stop paths.
- Saved volume is instance state; cleared after restore.

**What controls macOS input volume in System Settings vs CoreAudio:**
The System Settings > Sound > Input slider sets `kAudioDevicePropertyVolumeScalar` on the input scope. Reading and writing this property via CoreAudio is exactly what the System Settings slider does — there is no separate privileged API.

#### Table Stakes for Mic Volume Feature

| Behavior | Why Expected | Complexity | Notes |
|----------|--------------|------------|-------|
| Input volume set to 1.0 on recording start | Core premise: maximize signal before transcription | LOW | `AudioObjectSetPropertyData` with `kAudioDevicePropertyVolumeScalar`, input scope |
| Original volume restored on recording complete | User's calibration preserved — this is the critical UX contract | LOW | Store Float32 before set; restore on stop |
| Original volume restored on recording cancel (Escape) | Cancel path must restore — otherwise Escape leaves mic at max | LOW | All stop paths must call restore. Check AppCoordinator cancel flow |
| Original volume restored on error | Error path (e.g., STT failure) must also restore | LOW | Error handling in AppCoordinator must include restore |
| Graceful no-op if device has no volume control | Built-in mic on many Macs does not expose input volume via CoreAudio | MEDIUM | Check `AudioObjectHasProperty` before any read/write. Log debug message if not supported |
| Works with user-selected microphone, not just default | User may have selected an external USB mic in Settings | LOW | Use `MicrophoneDeviceService.selectedDeviceID` to get the active device ID — same device used by `AudioRecorder` |

#### Differentiators for Mic Volume Feature

| Behavior | Value | Complexity | Notes |
|----------|-------|------------|-------|
| Optional Settings toggle | User who relies on manual gain staging (podcasters, musicians) may not want auto-max | LOW | UserDefaults bool `autoMaxMicVolume`, default `true`. Single toggle in Settings |
| Smooth ramp instead of hard jump to 1.0 | Avoids audio pop/click if recording starts while gain changes | MEDIUM | Probably not needed — AVAudioEngine taps start after volume is set. Likely not perceptible in practice. Defer unless user reports audio artifacts |
| Per-device saved volume | If user switches mics between sessions, the saved original per-device is maintained | MEDIUM | Store `[AudioDeviceID: Float32]` in UserDefaults. V1: just use a single in-memory Float32 — simpler, sufficient for within-session use |

#### Anti-Features for Mic Volume Feature

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| Set volume without restore | Simpler implementation | Leaves user's system audio input at max permanently. Hostile to users who carefully calibrated their mic. Support burden | Always restore. Make restore the invariant, not the optimization |
| Use AVAudioSession input gain | Seems more Swift-native | AVAudioSession on macOS does not support `setInputGain` — that is an iOS-only API. CoreAudio is the correct macOS approach | Use `AudioObjectSetPropertyData` with CoreAudio directly |
| Expose volume level in UI | Show current mic level in Settings or recording overlay | Adds visual complexity; user's system Settings already shows this | Not needed. Silent behavior is better UX |
| Hard-coded device ID | Skip device lookup by reusing AVAudioEngine inputNode | AVAudioEngine uses the currently active system default, which may differ from the user's selected device | Always use `MicrophoneDeviceService.selectedDeviceID` (falling back to default device ID from `AudioObjectID(kAudioObjectSystemObject)`) |

#### Edge Cases to Handle

| Scenario | Expected Behavior | Implementation Note |
|----------|-------------------|---------------------|
| Device has no volume control (built-in mic on MacBook) | Silent no-op; feature is disabled for this device | `AudioObjectHasProperty` check returns false → skip set/restore entirely |
| User changes mic selection mid-session | New device gets volume-maxed on next recording | Volume service re-reads device ID on each `boost()` call, not cached at app start |
| Recording starts while previous recording is still restoring | Edge case: rapid back-to-back hotkey presses | `restore()` must complete before new `boost()` reads the original. Use a serial dispatch queue or actor for safety |
| App crashes during recording | Volume left at max until next run | On `applicationDidFinishLaunching`, check if there is a saved "boosted" state flag; if so, restore immediately. Store boost flag in UserDefaults during set, clear on restore |
| External USB mic disconnected during recording | Device ID becomes invalid; restore fails silently | Wrap restore in a guard; if device not available, the user already lost audio, no further action needed |
| Multi-channel mic (stereo input) | Per-channel volume set needed for some devices | Use `kAudioDevicePropertyPreferredChannelsForStereo` to enumerate channels; set each. Fall back to `kAudioObjectPropertyElementMain` if mono/main |

---

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| Global hotkey toggle | HIGH | LOW | P1 (shipped) |
| Audio capture | HIGH | LOW | P1 (shipped) |
| Local STT (Spanish) | HIGH | HIGH | P1 (shipped) |
| LLM cleanup (Spanish filler words) | HIGH | MEDIUM | P1 (shipped) |
| Auto-paste at cursor | HIGH | MEDIUM | P1 (shipped) |
| Menubar status icon | HIGH | LOW | P1 (shipped) |
| Waveform during recording | HIGH | LOW | P1 (shipped) |
| Permission prompts (first launch) | HIGH | LOW | P1 (shipped) |
| Configurable hotkey | MEDIUM | LOW | P1 (shipped) |
| Microphone selection | MEDIUM | LOW | P1 (shipped) |
| Pause Playback (auto-pause media) | HIGH | LOW | P1 (v1.1 shipped) |
| Pause Playback Settings toggle | HIGH | LOW | P1 (v1.1 shipped) |
| **Prevent "gracias" hallucination** | **HIGH** | **LOW** | **P1 (v1.2)** |
| **Auto-maximize mic input volume** | **HIGH** | **LOW-MEDIUM** | **P1 (v1.2)** |
| Push-to-talk mode | MEDIUM | LOW | P2 |
| Configurable LLM cleanup aggressiveness | LOW | LOW | P2 |
| Reformulation modes | LOW | HIGH | P3 |
| Multi-language support | LOW | HIGH | P3 |

**Priority key:**
- P1: Must have for launch
- P2: Should have, add when possible
- P3: Nice to have, future consideration

---

## Competitor Feature Analysis

| Feature | SuperWhisper | Wispr Flow | Sotto | macOS Dictation | Our Approach |
|---------|--------------|------------|-------|-----------------|--------------|
| Global hotkey | Yes (⌥+Space, configurable) | Yes | Yes | Yes (Fn key) | Yes (⌥+Space, configurable) — shipped |
| Push-to-talk | Yes (hold) | Yes (hold) | Yes (hold) | No | Planned v1.x |
| Toggle mode | Yes | No (hold only) | Yes | No | Yes — shipped |
| Local processing | Yes | No (cloud) | Yes | Partial (on-device option) | Yes (hard requirement) — shipped |
| Auto-paste | Yes | Yes | Yes | No | Yes — shipped |
| Waveform feedback | Yes (full window) | Yes (floating) | Yes (bar) | Yes (2025 Liquid Glass overlay) | Yes (floating overlay) — shipped |
| Filler word removal | Yes (LLM) | Yes (cloud LLM) | Yes (LLM) | No | Yes (local LLM, Spanish-aware) — shipped |
| Punctuation cleanup | Yes | Yes | Yes | Partial (auto-punctuation) | Yes — shipped |
| Spanish support | Yes (100+ langs) | Yes (cloud) | Yes | Yes (system language) | Yes (primary language, optimized) — shipped |
| Custom vocabulary | Yes | Unknown | Yes | No | Yes — shipped |
| History log | Yes (search) | Unknown | No | No | Yes (last 20) — shipped |
| Pause media while recording | Yes (v1.44.0+, default in v2.7.0) | Unknown | Unknown | No | v1.1 — shipped |
| **Prevent hallucinated output words** | **Unknown (not documented)** | **Unknown** | **Unknown** | **No** | **v1.2 — in progress** |
| **Auto-maximize mic volume** | **Unknown** | **Unknown** | **Unknown** | **No** | **v1.2 — in progress** |
| Menubar app | Yes | Yes | Yes | N/A (system feature) | Yes — shipped |
| Context capture (clipboard/screen) | Yes (Super Mode) | Yes | No | No | No (out of scope) |
| Cloud required | No | Yes | No | Optional | Never |
| Idle RAM | ~150MB (est.) | ~800MB | Unknown | Minimal | ~27MB — shipped |

---

## Sources

- [SuperWhisper official website](https://superwhisper.com/) — feature overview, modes
- [SuperWhisper changelog](https://superwhisper.com/changelog) — Pause media feature added v1.44.0 (Jan 13, 2025), refined v2.2.4 (Aug 20, 2025), default in v2.7.0 (Nov 26, 2025)
- [SuperWhisper Recording Window docs](https://superwhisper.com/docs/get-started/interface-rec-window) — UI states, waveform behavior
- [SuperWhisper on Twitter re: pause music](https://x.com/superwhisperapp/status/1963687889193095282) — confirmed "pause music while recording option in mode settings"
- [Sotto official website](https://sotto.to/) — full feature list
- [WhisperFlow official website](https://www.whisperflow.de/) — hold-to-talk, local Whisper, notch UI
- [Wispr Flow official website](https://wisprflow.ai/) — cloud approach, filler removal, context awareness
- [BackgroundMusic GitHub](https://github.com/kyleneideck/BackgroundMusic) — AppleScript-based auto-pause mechanism, supported players list
- [AutoPause HN thread](https://news.ycombinator.com/item?id=44823938) — mic-activity-based pause, Chrome extension for browser media, Bluetooth SCO side effect documented
- [MediaKeyTap GitHub](https://github.com/nhurden/MediaKeyTap) — Swift media key access library
- [Rogue Amoeba: Apple Keyboard Media Key Event Handling](https://weblog.rogueamoeba.com/2007/09/09/apple-keyboard-media-key-event-handling/) — NX_KEYTYPE_PLAY / NSSystemDefined subtype 8 mechanism
- [macOS NX_KEYTYPE_PLAY CGEventPost approach via Qiita](https://qiita.com/nak435/items/53d952147c3986afd7fc) — Swift code pattern
- [Apple Developer Forums: Play/Pause now playing with MediaRemote](https://developer.apple.com/forums/thread/688433) — MediaRemote private framework discussion
- [macOS Prevent Bluetooth Headphones Microphone switch](https://www.codejam.info/2024/05/macos-prevent-bluetooth-headphones-microphone.html) — Bluetooth SCO profile switching on mic activation
- [macOS Dictation Apple Support](https://support.apple.com/guide/mac-help/use-dictation-mh40584/mac) — built-in dictation capabilities
- [OpenAI Whisper Discussion #679](https://github.com/openai/whisper/discussions/679) — Whisper hallucination solutions
- [OpenAI Whisper Discussion #1455](https://github.com/openai/whisper/discussions/1455) — Random words / hallucination at end of recording
- [OpenAI Whisper Discussion #1606](https://github.com/openai/whisper/discussions/1606) — Hallucination on audio with no speech
- [Deepgram: Whisper-v3 Hallucinations on Real World Data](https://deepgram.com/learn/whisper-v3-results) — v3 hallucinates 4x more than v2
- [WhisperLive Issue #185](https://github.com/collabora/WhisperLive/issues/185) — Hallucinating "Thanks for watching" / conclusive remarks with near-silence
- [arxiv: Investigation of Whisper ASR Hallucinations Induced by Non-Speech Audio](https://arxiv.org/html/2501.11378v1) — Academic analysis of hallucination triggers
- [GitHub: STT-Basic-Cleanup-System-Prompt](https://github.com/danielrosehill/STT-Basic-Cleanup-System-Prompt) — Pattern for preventing LLM from adding words not in STT output
- [Anthropic Claude Prompting Best Practices](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/claude-prompting-best-practices) — Naming the exact forbidden output is more effective than describing the category
- [SimplyCoreAudio GitHub](https://github.com/rnine/SimplyCoreAudio) — Swift CoreAudio framework; confirms `virtualMainVolume(scope:)` method for input/output volume
- [CoreAudio Swift output device methods Gist](https://gist.github.com/kimsungwhee/91a4cbd7855089c302fc93f03a0fb15c) — `kAudioDevicePropertyVolumeScalar` with input scope pattern
- [Apple Developer: AudioObjectSetPropertyData](https://developer.apple.com/documentation/coreaudio/audioobjectsetpropertydata(_:_:_:_:_:_:)?language=objc) — Official CoreAudio API docs
- [Apple Support: Change sound input settings on Mac](https://support.apple.com/guide/mac-help/change-the-sound-input-settings-mchlp2567/mac) — Confirms System Settings slider controls input volume (same CoreAudio property)

---
*Feature research for: local voice-to-text macOS menubar app*
*Originally researched: 2026-03-15*
*Updated: 2026-03-16 — added v1.1 Pause Playback milestone feature detail*
*Updated: 2026-03-17 — added v1.2 Dictation Quality milestone feature detail (prevent "gracias" + auto-max mic volume)*
