# Feature Research

**Domain:** Local voice-to-text macOS menubar application
**Researched:** 2026-03-15 (v1.0) / Updated 2026-03-16 (v1.1 Pause Playback milestone)
**Confidence:** HIGH (primary sources: SuperWhisper official docs, Sotto, WhisperFlow, Wispr Flow, macOS Dictation official docs, multiple competitor analyses)

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
```

### Dependency Notes

- **Auto-Paste requires Accessibility Permission:** macOS requires the app be granted Accessibility access in System Settings to simulate Cmd+V keystrokes or type into other applications. This is a hard gate — app must prompt for this on first launch.
- **Transcription requires Microphone Permission:** Separate from Accessibility. Two distinct permission prompts are required on first use.
- **LLM Cleanup requires STT output:** The pipeline is sequential: record → transcribe → clean → paste. LLM cannot run until STT finishes. No parallelism is possible in the core pipeline.
- **Waveform enhances Recording State:** Waveform animation is the most important visual signal during recording. Menubar icon state alone is not sufficient feedback.
- **Custom Vocabulary post-processes LLM output:** Correction dictionary applies after LLM cleanup to fix persistent misrecognitions. Applying before LLM would allow LLM to "fix" the corrections.
- **Pause Playback requires no new permissions:** The app is non-sandboxed (Developer ID). Simulating media key events via CGEventPost is already used for paste simulation. No Accessibility or Input Monitoring entitlements beyond what v1.0 already has.

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

- [ ] **Pause Playback (v1.1):** Auto-pause media when recording starts, resume when recording ends, with Settings toggle — see detailed breakdown below
- [ ] Push-to-talk mode (hold hotkey vs toggle) — many users prefer this, low complexity to add
- [ ] Configurable LLM cleanup aggressiveness (light/full modes) — nice to have, not blocking

### Future Consideration (v2+)

Features to defer until product-market fit is established.

- [ ] Reformulation modes (formal email, structured notes) — needs powerful local LLM; validate accuracy first
- [ ] Second language support — add Spanish+English after v1 proves the architecture
- [ ] Keyboard-driven history navigation — power user feature only

---

## v1.1 Milestone: Pause Playback — Feature Detail

### What the Feature Does

When the user starts recording (hotkey press), the app sends a media play/pause key event to macOS. This pauses whatever is currently playing (Spotify, Apple Music, VLC, YouTube in a browser, etc.). When recording ends (hotkey press to stop, or transcription pipeline completes), the app sends the key event again to resume playback.

The feature is controlled by a single toggle in Settings. Off by default; user opts in.

### Mechanism: Media Key Simulation via CGEvent/NSEvent

**Approach:** Simulate pressing the physical Play/Pause media key (F8 / keyboard media key) programmatically using `NSEvent` with `NSSystemDefined` type and subtype 8 with `NX_KEYTYPE_PLAY` (value 16). Post the event via `CGEventPost(.cghidEventTap)`.

This is the same mechanism used by:
- BackgroundMusic (auto-pause utility)
- BeardedSpice (media key forwarder)
- Mac Media Key Forwarder
- SuperWhisper v1.44.0+ (confirmed: "Media will now pause when recording is started and play when recording ends")

**Why this approach:**
- Works with all apps that respond to the physical Play/Pause media key (Spotify, Apple Music, VLC, browsers, Pocket Casts, etc.)
- No private API usage — NSEvent + CGEventPost are public APIs
- No additional permissions required for non-sandboxed apps (app already uses CGEventPost for paste simulation)
- Single code path, no per-app logic
- Identical to pressing F8 on the keyboard from the OS's perspective

**Alternative rejected — MediaRemote private framework:**
- Private framework (`/System/Library/PrivateFrameworks/MediaRemote.framework`)
- macOS 15.4+ introduced entitlement verification in mediaremoted; clients without entitlement are denied NowPlaying access
- Would break on future macOS updates without warning
- App Store ineligible (already the case, but still bad practice)

**Alternative rejected — AppleScript per-app (BackgroundMusic approach):**
- Requires knowing which apps are playing and scripting each one individually
- Does not cover browser tabs (YouTube, Netflix)
- Brittle: each new app needs explicit support
- BackgroundMusic only supports: iTunes, Spotify, VLC, VOX, Decibel, Hermes, Swinsian, GPMDP

### Table Stakes for Pause Playback Feature

| Behavior | Why Expected | Complexity | Notes |
|----------|--------------|------------|-------|
| Pause on recording start | Core premise of the feature; user expectation from SuperWhisper, AutoPause, etc. | LOW | Send `NX_KEYTYPE_PLAY` key down + key up on `recordingDidStart` |
| Resume on recording end | Without resume, user must manually restart media after every dictation — breaks flow | LOW | Send `NX_KEYTYPE_PLAY` key down + key up after paste completes (not at stop-hotkey press, since processing takes 3-5s) |
| Settings toggle to enable/disable | Feature is disruptive if user doesn't want it. Single toggle in Settings panel | LOW | UserDefaults bool, default `false`. Show in Settings alongside other behavioral options |
| Works with Spotify | Most common audio player on macOS; users expect it to work | LOW | Media key approach handles Spotify natively |
| Works with Apple Music | Second most common; built into macOS | LOW | Media key approach handles Apple Music natively |
| Works with browser media (YouTube, etc.) | Users routinely have YouTube/Netflix playing in background | LOW | Media key approach works for browser tabs that have media focus |

### Differentiators for Pause Playback Feature

| Behavior | Value | Complexity | Notes |
|----------|-------|------------|-------|
| Resume after processing completes (not at stop-hotkey) | More polished than resuming immediately at stop-press, since processing takes 3-5s more — resuming during transcription noise is jarring | LOW | Track "was paused by us" state; resume in `transcriptionDidComplete` or `pipelineDidComplete` |
| Guard against double-resume | If user manually resumed media during the processing window, a second resume would pause it again | LOW | Track boolean `pausedByApp`. Only resume if we were the ones who paused |
| Silent no-op when nothing is playing | Sending media key when nothing plays should not open Music app or cause side effects | MEDIUM | macOS behavior: sending play/pause when nothing plays can launch Music.app on some configurations. Test and add guard if needed |
| VLC support | VLC is common among power users for video files | LOW | Media key approach handles VLC natively |

### Anti-Features for Pause Playback

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| Per-app pause logic (pause Spotify specifically, not others) | Seems more surgical | Requires AppleScript per app, misses browser tabs, brittle with app updates, 10x implementation complexity | Media key simulation is universal and correct |
| Pause on push-to-talk hold (not just toggle) | Consistency with hold-to-talk mode | Push-to-talk recordings are typically very short (2-5s); media key round-trip adds complexity for negligible benefit | Start with toggle mode only; extend later if users request it |
| Resume to different track / smart resume | Remember position in podcast or video | Requires state tracking per media type, AppleScript, different APIs per app | Not needed: media key resume is native behavior |
| Mute system audio instead of pause | Alternative approach | Muting leaves the audio running (CPU, network for streams); pausing is what users expect and what competitors do | Always pause, not mute |
| Chrome extension integration | Required for YouTube pause in some implementations | Media key simulation works without any browser extension for standard HTML5 players; extension adds distribution complexity | Media key approach sufficient |

### Edge Cases to Handle

| Scenario | Expected Behavior | Implementation Note |
|----------|-------------------|---------------------|
| Nothing is playing when recording starts | No-op; do not open Music.app or cause any side effect | Test on macOS: sending play/pause when nothing plays may launch Music.app. If so, guard with NowPlaying check or accept limitation |
| User manually pauses during transcription (3-5s window) | App should not resume media (user explicitly paused) | Problematic: we cannot distinguish "user paused" from "we paused." Track `pausedByApp` flag, only resume if flag is set. Flag is cleared if recording cancelled |
| Recording cancelled (user presses Escape or cancels) | Resume media since the recording was abandoned, not completed | Resume on cancel the same as on completion — user interrupted dictation, media should come back |
| Rapid back-to-back recordings | Media paused → resumed → paused again in quick succession | Each recording cycle should independently pause and resume. No cumulative state issues |
| Bluetooth headphones in use | macOS switches Bluetooth headphones to SCO (lower quality) profile when microphone activates — separate from this feature but often reported together | This is a macOS/hardware behavior, not fixable in app. Document in settings tooltip: "Media pauses during recording; Bluetooth headphones may switch audio profile while mic is active." |
| Browser tab has media focus vs background music | Sending play/pause pauses whichever app currently "owns" the Now Playing widget | macOS determines media key target via the NowPlaying focus mechanism. This is correct behavior — pause whatever is currently "playing" per the OS |
| Multiple apps playing simultaneously | Rare but possible (Spotify + browser) | Media key pauses the NowPlaying-registered app. Other audio continues. Acceptable limitation |
| App that intercepts media keys (Discord, Teams) | These apps can steal media key focus, causing pause to affect call audio instead of music | Known ecosystem conflict. Superwhisper v2.2.1 flagged Discord and Obsidian as problematic. Document in release notes. No reliable workaround without per-app AppleScript |
| User disables toggle mid-session | If recording is already in progress when toggle is turned off, do not resume media when recording ends | Check toggle state at resume time, not just at pause time |

### Feature Dependencies (Pause Playback Specific)

```
[Pause Playback Toggle]
    └──stored-in──> [UserDefaults (existing)]
    └──displayed-in──> [Settings Panel (existing)]

[Pause on Recording Start]
    └──triggered-by──> [RecordingManager.startRecording() (existing)]
    └──uses──> [CGEventPost / NSEvent systemDefined (same API as paste simulation)]
    └──sets──> [pausedByApp: Bool = true]

[Resume on Recording End]
    └──triggered-by──> [Pipeline completion: paste done OR recording cancelled]
    └──guard──> [pausedByApp == true]
    └──clears──> [pausedByApp = false]
    └──uses──> [same CGEventPost / NSEvent path as pause]
```

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
| **Pause Playback (auto-pause media)** | **HIGH** | **LOW** | **P1 (v1.1)** |
| **Pause Playback Settings toggle** | **HIGH** | **LOW** | **P1 (v1.1)** |
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
| **Pause media while recording** | **Yes (v1.44.0+, default in v2.7.0)** | **Unknown** | **Unknown** | **No** | **v1.1 — in progress** |
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

---
*Feature research for: local voice-to-text macOS menubar app*
*Originally researched: 2026-03-15*
*Updated: 2026-03-16 — added v1.1 Pause Playback milestone feature detail*
