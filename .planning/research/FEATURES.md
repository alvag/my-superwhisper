# Feature Research

**Domain:** Local voice-to-text macOS menubar application
**Researched:** 2026-03-15 (v1.0) / Updated 2026-03-16 (v1.1 Pause Playback milestone) / Updated 2026-03-17 (v1.2 Dictation Quality milestone) / Updated 2026-03-24 (v1.3 Settings UX milestone)
**Confidence:** HIGH (primary sources: SuperWhisper official docs, Sotto, WhisperFlow, Wispr Flow, macOS Dictation official docs, multiple competitor analyses, OpenAI Whisper GitHub discussions, Anthropic prompt engineering docs, CoreAudio documentation, Apple Developer docs, SwiftUI Settings scene docs, community implementations)

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

[SwiftUI Settings Window (v1.3)]
    └──replaces──> [AppKit NSPanel SettingsWindowController]
    └──requires──> [NSApp activation policy toggle (.accessory <-> .regular)]
    └──requires──> [Settings scene declared in App struct]
    └──wraps──> [All 7 existing settings: hotkey, mic, API key, vocabulary, launch-at-login, pause-playback, maximize-volume]
    └──depends-on──> [KeyboardShortcuts.RecorderView (existing SwiftUI component)]
    └──depends-on──> [VocabularyService (existing)]
    └──depends-on──> [MicrophoneDeviceService (existing)]
    └──depends-on──> [HaikuCleanupProtocol (existing, for API key validation)]
    └──window-persistence──> [hidesOnDeactivate = false on underlying NSWindow]
    └──conflict-with──> [SettingsLink in MenuBarExtra — unreliable, requires workaround]
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
- **SwiftUI Settings requires activation policy dance:** MenuBarExtra apps run as `.accessory` (no dock icon). Opening a Settings window requires temporarily switching to `.regular`, calling `NSApp.activate(ignoringOtherApps: true)`, then restoring `.accessory` on window close. This is the only reliable pattern for macOS 14+.
- **SettingsLink is broken in MenuBarExtra context:** Apple's `SettingsLink` and `@Environment(\.openSettings)` assume a regular app with an active SwiftUI render tree. Menu bar-only apps have no render tree before the first interaction. The workaround is either (a) using `SettingsAccess` package (orchetect/SettingsAccess) or (b) manually managing NSApp activation and calling `openSettings` from an AppKit-backed action.

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
- [x] **Prevent "gracias" hallucination (v1.2):** Dual-layer fix — Haiku prompt constraint + post-processing strip — **SHIPPED v1.2**
- [x] **Auto-maximize mic input volume (v1.2):** CoreAudio read/set/restore on recording start/stop, with graceful fallback — **SHIPPED v1.2**
- [ ] **Settings UX redesign (v1.3):** SwiftUI migration, grouped sections, persistent window — **IN PROGRESS**
- [ ] Push-to-talk mode (hold hotkey vs toggle) — many users prefer this, low complexity to add
- [ ] Configurable LLM cleanup aggressiveness (light/full modes) — nice to have, not blocking

### Future Consideration (v2+)

Features to defer until product-market fit is established.

- [ ] Reformulation modes (formal email, structured notes) — needs powerful local LLM; validate accuracy first
- [ ] Second language support — add Spanish+English after v1 proves the architecture
- [ ] Keyboard-driven history navigation — power user feature only

---

## v1.3 Milestone: Settings UX — Feature Detail

### Context: What Exists Today

The current Settings implementation (`SettingsWindowController.swift`, ~306 LOC) is a fully AppKit NSPanel built with raw Auto Layout constraints. Key characteristics:

- **Window type:** NSPanel (480×590px, `.titled | .closable` style mask)
- **Behavior:** Closes when app loses focus (because `hidesOnDeactivate` is not explicitly set to false). Window is re-created on every `show()` call if `panel == nil`.
- **Layout:** Single flat vertical list, no visual grouping. 7 items stacked top-to-bottom with constant spacing:
  1. Hotkey recorder (KeyboardShortcuts.RecorderCocoa)
  2. Microphone popup (NSPopUpButton)
  3. API key button (opens sub-panel)
  4. Vocabulary corrections table (NSTableView with +/- buttons)
  5. Launch at login checkbox
  6. Pause playback checkbox
  7. Maximize mic volume checkbox
- **Pain points:** No section labels, no visual grouping, flat layout feels unfinished, window closes unexpectedly when user clicks elsewhere.

### Feature 1: Persistent Settings Window

#### What the Feature Does

The settings window stays open until the user explicitly closes it via the close button or presses Escape. Clicking outside the window, switching to another app, or pressing the menubar icon again does not close settings.

#### Why This Matters

The current window closes whenever the app loses focus. This is frustrating when a user needs to reference settings while using another app, or needs to tab between the settings window and another window to verify a hotkey. Every macOS settings window from Apple (System Settings, Xcode Preferences, Safari Settings) and third-party apps (1Password, Alfred, Raycast) stays open until explicitly dismissed.

#### Table Stakes for Window Persistence

| Behavior | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Window stays open when user clicks another app | Standard macOS behavior for all settings/prefs windows | LOW | Set `hidesOnDeactivate = false` on the NSWindow via NSWindowDelegate or `withHostingView` bridge |
| Window stays open when user clicks menubar item again | Re-invoking settings should bring window to front, not toggle | LOW | Check for existing window: `makeKeyAndOrderFront` instead of re-creating |
| Close button (red X) closes the window | Standard macOS affordance | LOW | Default NSWindow behavior — no special handling needed |
| Cmd+W closes the window | Standard macOS keyboard shortcut for closing a window | LOW | Default NSWindow/SwiftUI Settings behavior |
| Cmd+, reopens settings if already closed | Standard macOS shortcut for app preferences | LOW | Automatically provided by the SwiftUI `Settings` scene + app menu "Settings..." item |
| Window remembers position between opens | macOS convention: windows reopen where they were left | MEDIUM | SwiftUI Settings scene handles this automatically via `restorationClass` / frame autosaving |

#### Anti-Features for Window Persistence

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| Always-on-top floating panel | Settings "should be easy to access" | NSPanel with floating level obscures other windows. Standard prefs windows are not floating | Normal window level. User places it where they want |
| Auto-close after N seconds | "Reduce clutter" | Settings should stay until explicitly dismissed. Timed close is unexpected and annoying | Always-explicit close |
| Re-open at fixed screen center | Consistent location | macOS convention is to restore last position. Users move windows where they want them | Restore last known position |

### Feature 2: SwiftUI Migration

#### What the Feature Does

Replace the AppKit NSPanel implementation with a native SwiftUI view inside the SwiftUI `Settings` scene. The `Settings` scene provides the Cmd+, menu integration, keyboard shortcut, and standard window management automatically.

#### SwiftUI Settings Scene — Key API Behaviors

**HIGH confidence (verified against multiple sources):**

- `Settings { MySettingsView() }` in `App.body` automatically registers the "Settings..." menu item under the app menu and binds Cmd+, to open it
- On macOS 14+, `openSettings` via `@Environment(\.openSettings)` is the programmatic API, but it is broken in `MenuBarExtra` context (no SwiftUI render tree exists for menu bar-only apps)
- The working workaround for menu bar apps: call `NSApp.setActivationPolicy(.regular)`, then `NSApp.activate(ignoringOtherApps: true)`, then invoke the settings open mechanism; restore `.accessory` in `windowWillClose` delegate
- The `SettingsAccess` package (orchetect/SettingsAccess) provides a clean solution that works across macOS 11–15+ without private APIs and is App Store compatible (though this app is not sandboxed)
- The existing `MyWhisperApp.swift` already declares `Settings { EmptyView() }` — the scene infrastructure exists, just needs a real view

**MEDIUM confidence:**

- SwiftUI `Settings` scene automatically persists window position between opens (via frame autosave) — confirmed by multiple sources but behavior may vary on minor macOS versions
- `windowResizability(.contentSize)` on a `Settings` scene creates a non-user-resizable window that matches content size — useful to prevent awkward resizing of settings

#### Form vs List — macOS Settings Recommendation

**Use `Form` with `.formStyle(.grouped)`.** Rationale:

- `.formStyle(.columns)` (the macOS default for `Form`) renders labels in a trailing-aligned left column and controls in a leading-aligned right column — looks like a spreadsheet, not a settings panel. It works for dense data-entry forms but feels cold for a 7-item settings window.
- `.formStyle(.grouped)` renders sections as visually distinct rounded groups with inset content — matches System Preferences / System Settings visual language exactly. This is the right choice for a settings window with heterogeneous controls (toggles, pickers, buttons, tables).
- `List` with `listStyle(.insetGrouped)` achieves a similar grouped visual on macOS but is semantically for data display (navigable rows), not settings controls. `Form` with grouped style is the semantic and visual correct choice for settings.
- `Section` within a `Form` creates the labeled group with a header — use for visual grouping without tab complexity.

#### Tab-Based vs Single-Pane

**Single-pane is correct for 7 settings items.** Use tabs only when:
- There are more than ~12-15 settings items that can't fit comfortably in a scrollable single pane, OR
- Settings fall into clearly distinct domains where users navigate to specific tabs independently (e.g., "General", "Advanced", "Integrations")

The existing 7 items can be grouped into 2–3 logical sections within a single scrollable pane:
- **Grabacion** (hotkey, microphone, mic volume)
- **API / Transcripcion** (API key)
- **Correcciones** (vocabulary table)
- **General** (launch at login, pause playback)

This avoids the overhead of tab navigation for a small settings set.

#### Visual Hierarchy Recommendations

**GroupBox for section containers** — provides the rounded box with optional title label, matching System Settings section groups. Use inside a `Form` or as standalone grouped container.

**Section inside Form** — lighter than GroupBox, renders a section header above the grouped items. Better when the section header is text-only.

**SF Symbols for section icons** — optional but improves visual scanning (e.g., `keyboard` for hotkey section, `mic.fill` for audio section, `gear` for general section).

**Descriptive footnotes** — small gray text below a control explaining its behavior. Use `.font(.caption).foregroundColor(.secondary)` inside the Form row. Particularly useful for the vocabulary table (explain what it does) and API key (explain Keychain storage).

#### Table Stakes for SwiftUI Migration

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| All 7 existing settings work identically after migration | Functional parity — nothing regresses | MEDIUM | Map each AppKit control to SwiftUI equivalent. KeyboardShortcuts provides `RecorderView` for SwiftUI |
| Grouped visual sections with headers | Modern macOS settings windows group related items. Flat list feels unfinished | LOW | Use `Form { Section("Grabacion") { ... } Section("General") { ... } }` with `.formStyle(.grouped)` |
| Settings changes take effect immediately | Users expect live feedback — no "Apply" button | LOW | Bind controls directly to `@AppStorage` or observable service properties. Standard SwiftUI pattern |
| Vocabulary table still editable | NSTableView with inline editing → SwiftUI `List` with `TextField` rows | MEDIUM | SwiftUI `List` with `@State var entries` + `TextField` in each row. Add/remove via +/- buttons below the list |
| Cmd+, opens settings from any app | Standard macOS keyboard shortcut for app preferences | LOW | Automatically provided by `Settings` scene registration |
| Window has standard title bar with "Preferencias" title | macOS convention | LOW | SwiftUI Settings window uses app name by default; customize via `navigationTitle` or window title |
| Dark mode support | macOS apps are expected to respect system appearance | LOW | Free with SwiftUI — all native controls adapt automatically |

#### Differentiators for SwiftUI Migration

| Feature | Value | Complexity | Notes |
|---------|-------|------------|-------|
| Section icons (SF Symbols) in group headers | Visual polish, faster scanning | LOW | Add `Label("Grabacion", systemImage: "mic.fill")` as Section header |
| Descriptive footnotes below complex settings | Explains vocabulary corrections behavior, API key Keychain storage | LOW | `.font(.caption).foregroundColor(.secondary)` text below control |
| Inline API key status indicator | Shows "Configurada" or "No configurada" without opening sub-panel | LOW-MEDIUM | Read Keychain on view appear; show status text. Still open full editor on button tap |
| Fixed window size that fits content | Avoids awkward stretching | LOW | `.frame(width: 460)` on the Settings content view, let height be content-driven |

#### Anti-Features for SwiftUI Migration

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| Tab-based navigation for 7 items | "Cleaner separation" | Adds navigation overhead for settings that fit in one scrollable pane. Tabs are correct at 15+ items or clearly distinct domains | Single pane with labeled sections |
| Live-search/filter for settings | "Easy to find settings" | Overkill for 7 items. Adds complexity without user value at this scale | Good section grouping is sufficient |
| Undo/redo for settings changes | "Settings should be undoable" | No macOS settings window implements this. Users expect immediate-apply with no undo | No undo. Settings apply immediately |
| Custom NSWindowController subclass kept alongside SwiftUI | "Easier migration" | Two systems managing the same window creates bugs. The whole point is to migrate fully | Full replacement, not coexistence |
| Sidebar navigation (like System Settings) | "Matches System Settings" | System Settings sidebar is for 40+ categories. Sidebar for 7 items is wasteful, adds navigation depth | Flat sections in single scrollable pane |
| Animations / transitions between sections | "Feels modern" | Settings windows are functional, not expressive. Unexpected animations are distracting | Static layout. Let SwiftUI's standard control animations handle feedback |

### Feature 3: Grouped Sections with Visual Hierarchy

This feature describes the visual design of the migrated settings, distinct from the technical migration.

#### Proposed Section Structure

**Section: Grabacion**
- Atajo de grabacion (KeyboardShortcuts.RecorderView)
- Microfono (Picker with system default + device list)
- Maximizar volumen al grabar (Toggle)

**Section: Transcripcion**
- Clave de API Anthropic (button "Cambiar clave..." + status indicator)
- Correcciones de vocabulario (List table with +/- buttons, expands the section)

**Section: Sistema**
- Iniciar al arranque (Toggle via SMAppService)
- Pausar reproduccion al grabar (Toggle via UserDefaults)

#### Rationale for This Grouping

- **Grabacion** groups everything that affects audio input quality and recording trigger — the hotkey, which mic to use, and whether to maximize its gain. These three are logically "what happens when I press the hotkey".
- **Transcripcion** groups the Anthropic API (required for cleanup) and the vocabulary corrections (which affect the cleanup output). These are "what happens to the text after I speak".
- **Sistema** groups OS-level behaviors that affect how the app integrates with macOS — launch at login and media pause. These are "how the app behaves as a system citizen".

#### Table Stakes for Section Grouping

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Logically related settings grouped visually | Users scan settings by purpose, not by implementation order | LOW | Form Section with header labels |
| Section headers are readable but not dominant | Headers guide, not dominate. Overly large headers waste space | LOW | Default `Section` header styling in `.formStyle(.grouped)` is correct — small caps, secondary color |
| Settings within a section are vertically aligned | Items within a group should have consistent left edges | LOW | Automatic with `Form` columns or grouped style |
| Adequate whitespace between sections | Separation signals "different category" | LOW | Built into SwiftUI `Form` section spacing |

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
| Prevent "gracias" hallucination | HIGH | LOW | P1 (v1.2 shipped) |
| Auto-maximize mic input volume | HIGH | LOW-MEDIUM | P1 (v1.2 shipped) |
| **Persistent settings window** | **HIGH** | **LOW** | **P1 (v1.3)** |
| **SwiftUI Settings migration** | **HIGH** | **MEDIUM** | **P1 (v1.3)** |
| **Grouped sections visual hierarchy** | **MEDIUM** | **LOW** | **P1 (v1.3)** |
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
| Prevent hallucinated output words | Unknown (not documented) | Unknown | Unknown | No | v1.2 — shipped |
| Auto-maximize mic volume | Unknown | Unknown | Unknown | No | v1.2 — shipped |
| **Settings window (native SwiftUI)** | **Yes (full SwiftUI, tab-based)** | **Unknown** | **Unknown** | **N/A** | **v1.3 — in progress** |
| **Settings window persistence** | **Yes (stays open)** | **Unknown** | **Unknown** | **N/A** | **v1.3 — in progress** |
| Menubar app | Yes | Yes | Yes | N/A (system feature) | Yes — shipped |
| Context capture (clipboard/screen) | Yes (Super Mode) | Yes | No | No | No (out of scope) |
| Cloud required | No | Yes | No | Optional | Never |
| Idle RAM | ~150MB (est.) | ~800MB | Unknown | Minimal | ~27MB — shipped |

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
- [Peter Steinberger: Showing Settings from macOS Menu Bar Items (2025)](https://steipete.me/posts/2025/showing-settings-from-macos-menu-bar-items) — SettingsLink broken in MenuBarExtra; activation policy workaround pattern documented
- [SettingsAccess package (orchetect)](https://github.com/orchetect/SettingsAccess) — Clean solution for opening Settings from menu bar apps; works macOS 11–15+, no private APIs
- [SerialCoder.dev: Presenting Preferences Window with SwiftUI](https://serialcoder.dev/text-tutorials/macos-tutorials/presenting-the-preferences-window-on-macos-using-swiftui/) — Tab-based Settings structure, fixed window dimensions, modular files
- [Apple Developer: SwiftUI Settings scene](https://developer.apple.com/documentation/swiftui/settings) — Official API reference for Settings scene
- [Apple Developer: Form](https://developer.apple.com/documentation/swiftui/form) — Form component documentation
- [Apple Developer: GroupedFormStyle](https://developer.apple.com/documentation/swiftui/groupedformstyle) — .formStyle(.grouped) for macOS settings-style layout
- [Apple Developer: GroupBox](https://developer.apple.com/documentation/swiftui/groupbox) — Visual container for grouped settings
- [Eclectic Light: SwiftUI on macOS Settings, defaults and About (2024)](https://eclecticlight.co/2024/04/30/swiftui-on-macos-settings-defaults-and-about/) — Xcode preview fidelity broken for Settings TabView; @AppStorage for persistence
- [Hacking with Swift: How to open Settings from menu bar app](https://www.hackingwithswift.com/forums/macos/how-to-open-settings-from-menu-bar-app-and-show-app-icon-in-dock/26267) — NSApp.setActivationPolicy(.regular) + activate pattern; restore .accessory on window close
- [Hendoi Technologies: macOS Menu Bar App with SwiftUI 2026](https://www.hendoi.in/blog/macos-menu-bar-utility-app-swiftui-startups-2026) — Current best practices for menubar app + settings window
- [sindresorhus/Settings GitHub](https://github.com/sindresorhus/Settings) — Toolbar-item and segmented-control tab styles for macOS settings windows; auto window sizing; `Settings.Container` and `Settings.Section` layout helpers

---
*Feature research for: local voice-to-text macOS menubar app*
*Originally researched: 2026-03-15*
*Updated: 2026-03-16 — added v1.1 Pause Playback milestone feature detail*
*Updated: 2026-03-17 — added v1.2 Dictation Quality milestone feature detail (prevent "gracias" + auto-max mic volume)*
*Updated: 2026-03-24 — added v1.3 Settings UX milestone feature detail (SwiftUI migration, persistent window, grouped sections)*
