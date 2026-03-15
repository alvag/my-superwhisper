# Feature Research

**Domain:** Local voice-to-text macOS menubar application
**Researched:** 2026-03-15
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
```

### Dependency Notes

- **Auto-Paste requires Accessibility Permission:** macOS requires the app be granted Accessibility access in System Settings to simulate Cmd+V keystrokes or type into other applications. This is a hard gate — app must prompt for this on first launch.
- **Transcription requires Microphone Permission:** Separate from Accessibility. Two distinct permission prompts are required on first use.
- **LLM Cleanup requires STT output:** The pipeline is sequential: record → transcribe → clean → paste. LLM cannot run until STT finishes. No parallelism is possible in the core pipeline.
- **Waveform enhances Recording State:** Waveform animation is the most important visual signal during recording. Menubar icon state alone is not sufficient feedback.
- **Custom Vocabulary post-processes LLM output:** Correction dictionary applies after LLM cleanup to fix persistent misrecognitions. Applying before LLM would allow LLM to "fix" the corrections.

---

## MVP Definition

### Launch With (v1)

Minimum viable product — what's needed to validate the concept.

- [ ] Global hotkey (Ctrl+Space) toggles recording from anywhere — core interaction model
- [ ] Audio capture from selected microphone while recording is active
- [ ] Menubar status icon: 3 states minimum (idle / recording / processing)
- [ ] Waveform animation during recording — essential feedback, otherwise users don't know it's working
- [ ] Local STT transcription (Whisper.cpp or MLX-Whisper) optimized for Spanish
- [ ] Local LLM post-processing: punctuation, capitalization, filler word removal (Spanish-aware)
- [ ] Auto-paste clean text at cursor position via Accessibility API
- [ ] Permission prompts on first launch (Accessibility + Microphone)
- [ ] Cancel recording (Escape key or button) — prevents pasting garbage
- [ ] Configurable hotkey in settings — Ctrl+Space may conflict for some users
- [ ] Microphone selection in settings — basic but expected

### Add After Validation (v1.x)

Features to add once core is working.

- [ ] Push-to-talk mode (hold hotkey vs toggle) — many users prefer this, low complexity to add
- [ ] Transaction history (last 10 transcriptions) — immediate recovery from accidental dismiss
- [ ] Custom vocabulary / correction dictionary — for users with specialized terminology
- [ ] Processing state granularity (transcribing vs cleaning vs pasting) — reduces perceived wait

### Future Consideration (v2+)

Features to defer until product-market fit is established.

- [ ] Reformulation modes (formal email, structured notes) — needs powerful local LLM; validate accuracy first
- [ ] Second language support — add Spanish+English after v1 proves the architecture
- [ ] Configurable LLM cleanup aggressiveness (light/full modes) — nice to have, not blocking
- [ ] Keyboard-driven history navigation — power user feature only

---

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| Global hotkey toggle | HIGH | LOW | P1 |
| Audio capture | HIGH | LOW | P1 |
| Local STT (Spanish) | HIGH | HIGH | P1 |
| LLM cleanup (Spanish filler words) | HIGH | MEDIUM | P1 |
| Auto-paste at cursor | HIGH | MEDIUM | P1 |
| Menubar status icon | HIGH | LOW | P1 |
| Waveform during recording | HIGH | LOW | P1 |
| Permission prompts (first launch) | HIGH | LOW | P1 |
| Cancel recording | MEDIUM | LOW | P1 |
| Configurable hotkey | MEDIUM | LOW | P1 |
| Microphone selection | MEDIUM | LOW | P1 |
| Push-to-talk mode | MEDIUM | LOW | P2 |
| Transaction history | MEDIUM | LOW | P2 |
| Custom vocabulary | MEDIUM | MEDIUM | P2 |
| Granular processing states | LOW | LOW | P2 |
| Lightweight idle resources | MEDIUM | MEDIUM | P2 |
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
| Global hotkey | Yes (⌥+Space, configurable) | Yes | Yes | Yes (Fn key) | Yes (Ctrl+Space default, configurable) |
| Push-to-talk | Yes (hold) | Yes (hold) | Yes (hold) | No | Yes (v1.x) |
| Toggle mode | Yes | No (hold only) | Yes | No | Yes (v1) |
| Local processing | Yes | No (cloud) | Yes | Partial (on-device option) | Yes (hard requirement) |
| Auto-paste | Yes | Yes | Yes | No (inserts inline via Dictation API) | Yes |
| Waveform feedback | Yes (full window) | Yes (floating) | Yes (bar) | Yes (2025 Liquid Glass overlay) | Yes (menubar or floating) |
| Filler word removal | Yes (LLM) | Yes (cloud LLM) | Yes (LLM) | No | Yes (local LLM, Spanish-aware) |
| Punctuation cleanup | Yes | Yes | Yes | Partial (auto-punctuation) | Yes |
| Spanish support | Yes (100+ langs) | Yes (cloud) | Yes | Yes (system language) | Yes (primary language, optimized) |
| Custom vocabulary | Yes | Unknown | Yes | No | v1.x |
| Modes/presets | Yes (complex) | Partial | Yes | No | No (v1), light cleanup levels v1.x |
| History log | Yes (search) | Unknown | No | No | v1.x |
| Menubar app | Yes | Yes | Yes | N/A (system feature) | Yes |
| Context capture (clipboard/screen) | Yes (Super Mode) | Yes | No | No | No (v1) |
| Cloud required | No | Yes | No | Optional | Never |
| Idle RAM | ~150MB (est.) | ~800MB | Unknown | Minimal | Target <100MB |

---

## Sources

- [SuperWhisper official website](https://superwhisper.com/) — feature overview, modes
- [SuperWhisper Recording Window docs](https://superwhisper.com/docs/get-started/interface-rec-window) — UI states, waveform behavior
- [SuperWhisper Keyboard Shortcuts docs](https://superwhisper.com/docs/get-started/settings-shortcuts) — push-to-talk vs toggle
- [Sotto official website](https://sotto.to/) — full feature list including Parakeet, hotkey modes, AI functions
- [WhisperFlow official website](https://www.whisperflow.de/) — hold-to-talk, local Whisper, notch UI
- [Wispr Flow official website](https://wisprflow.ai/) — cloud approach, filler removal, context awareness
- [Vibe Transcribe GitHub](https://github.com/thewh1teagle/vibe) — file transcription, open source patterns
- [Buzz GitHub](https://github.com/chidiwilliams/buzz) — open source reference for Whisper wrappers
- [macOS Dictation Apple Support](https://support.apple.com/guide/mac-help/use-dictation-mh40584/mac) — built-in dictation capabilities
- [Choosing the Right AI Dictation App for Mac](https://afadingthought.substack.com/p/best-ai-dictation-tools-for-mac) — philosophy comparison, differentiators
- [Best Dictation App for Mac 2025 - Writingmate](https://writingmate.ai/blog/best-dictation-app-for-mac) — resource usage data, user expectations
- [push-to-talk-dictate GitHub (Rasala)](https://github.com/Rasala/push-to-talk-dictate) — MLX Whisper + Qwen pipeline reference
- [open-wispr GitHub](https://github.com/human37/open-wispr) — minimal local push-to-talk reference implementation

---
*Feature research for: local voice-to-text macOS menubar app*
*Researched: 2026-03-15*
