# Architecture Research

**Domain:** SwiftUI Settings Migration — AppKit NSPanel to SwiftUI in existing macOS menubar app
**Researched:** 2026-03-24
**Confidence:** HIGH (existing codebase read directly; SwiftUI/AppKit interop patterns verified via official Apple docs and confirmed community sources)

---

## System Overview — v1.3 Settings Migration

```
┌──────────────────────────────────────────────────────────────────────┐
│                         AppDelegate (wiring)                          │
│  UserDefaults.register(defaults:) on launch                           │
├──────────────────────────────────────────────────────────────────────┤
│  ┌────────────────┐  ┌─────────────────┐  ┌──────────────────────┐   │
│  │ HotkeyMonitor  │  │  EscapeMonitor  │  │  MenubarController   │   │
│  └────────┬───────┘  └────────┬────────┘  └──────────┬───────────┘   │
│           │                  │                       │                │
├───────────▼──────────────────▼───────────────────────▼────────────────┤
│                       AppCoordinator (FSM)                             │
│              idle ↔ recording ↔ processing ↔ error                    │
├──────────────────────────────────────────────────────────────────────┤
│  ┌─────────────────────────────────────────────────────────────────┐  │
│  │                    StatusMenuController                          │  │
│  │  openSettings() → SettingsWindowController.show()   [MODIFIED]  │  │
│  └─────────────────────────────────────────────────────────────────┘  │
├──────────────────────────────────────────────────────────────────────┤
│  ┌──────────────────────────────────────────────────────────────┐     │
│  │  SettingsWindowController  [REPLACED]                         │     │
│  │                                                               │     │
│  │  NSWindow (titled, closable, NOT nonactivating)               │     │
│  │    └── contentViewController = NSHostingController(           │     │
│  │              rootView: SettingsView(                          │     │
│  │                  viewModel: SettingsViewModel))                │     │
│  │                                                               │     │
│  │  Lifecycle: panel = nil until first show();                   │     │
│  │  makeKeyAndOrderFront on re-open;                             │     │
│  │  windowWillClose → NSApp.setActivationPolicy(.accessory)      │     │
│  └──────────────────────────────────────────────────────────────┘     │
├──────────────────────────────────────────────────────────────────────┤
│  ┌──────────────────────────────────────────────────────────────┐     │
│  │  SettingsViewModel  [@Observable, @MainActor]  [NEW]          │     │
│  │                                                               │     │
│  │  Owns: pausePlayback, maximizeMicVolume (UserDefaults via      │     │
│  │         didSet),  launchAtLogin (SMAppService live query),     │     │
│  │         selectedMicID (MicrophoneDeviceService delegate),      │     │
│  │         vocabularyEntries ([VocabularyEntry] — VocabService)   │     │
│  └──────────────────────────────────────────────────────────────┘     │
├──────────────────────────────────────────────────────────────────────┤
│  ┌──────────────────────────────────────────────────────────────┐     │
│  │  SettingsView (SwiftUI)  [NEW]                                │     │
│  │                                                               │     │
│  │  Form {                                                       │     │
│  │    Section("Grabacion") { KeyboardShortcuts.Recorder; Picker} │     │
│  │    Section("API") { Button → APIKeyWindowController.show() }  │     │
│  │    Section("Vocabulario") { List + add/remove }               │     │
│  │    Section("Sistema") { Toggle launch; Toggle pause; Toggle   │     │
│  │                         maximize }                            │     │
│  │  }                                                            │     │
│  └──────────────────────────────────────────────────────────────┘     │
├──────────────────────────────────────────────────────────────────────┤
│  ┌──────────────────┐  ┌────────────────────┐  ┌─────────────────┐   │
│  │ VocabularyService│  │MicrophoneDevService │  │ APIKeyWindow    │   │
│  │ (unchanged)      │  │ (unchanged)         │  │ Controller      │   │
│  │                  │  │                     │  │ (unchanged)     │   │
│  └──────────────────┘  └────────────────────┘  └─────────────────┘   │
└──────────────────────────────────────────────────────────────────────┘
```

---

## New vs Modified Components

### Modified: `SettingsWindowController.swift` (306 lines → ~60 lines)

**What changes:** Gutted from a full AppKit NSPanel builder with NSTableView/NSLayoutConstraint
to a thin window host that creates an NSWindow, wraps `SettingsView` in `NSHostingController`,
and manages the activation policy lifecycle.

**The only AppKit responsibility that remains:**
- Creating the `NSWindow` (titled, closable)
- Injecting a `SettingsViewModel` as the hosting controller's root view
- Managing the `panel = nil` / activation policy dance on open and close
- Forwarding `show()` calls from `StatusMenuController`

The class stays `@MainActor final` and `NSWindowDelegate` for `windowWillClose`. All
NSTableView datasource/delegate code, NSPopUpButton wiring, NSButton target/action pairs,
and NSLayoutConstraint blocks are deleted.

```swift
@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    private var panel: NSWindow?
    private let viewModel: SettingsViewModel

    init(vocabularyService: VocabularyService,
         microphoneService: MicrophoneDeviceService,
         haikuCleanup: (any HaikuCleanupProtocol)?) {
        self.viewModel = SettingsViewModel(
            vocabularyService: vocabularyService,
            microphoneService: microphoneService,
            haikuCleanup: haikuCleanup
        )
        super.init()
    }

    func show() {
        if let existing = panel {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let hostingController = NSHostingController(
            rootView: SettingsView(viewModel: viewModel)
        )
        let window = NSWindow(contentViewController: hostingController)
        window.title = "MyWhisper — Preferencias"
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()
        NSApp.setActivationPolicy(.regular)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.panel = window
    }

    func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        self.panel = nil
    }
}
```

The `NSWindow(contentViewController:)` initializer auto-sizes the window to fit the
`NSHostingController`'s `view.fittingSize`, so no fixed `contentRect` is needed — the SwiftUI
Form determines the window size.

**Why NSWindow over NSPanel:** The current NSPanel with `[.titled, .closable]` closes when
the user clicks outside because that is the default NSPanel behavior. Using a plain `NSWindow`
with the same style mask keeps it open until the user explicitly presses the close button,
fulfilling the v1.3 requirement. (NSPanel with `.nonactivating` would be wrong here —
that prevents the panel from ever becoming key, making text fields unresponsive.)

---

### New: `SettingsViewModel.swift`

**Location:** `MyWhisper/Settings/SettingsViewModel.swift`

`@Observable @MainActor` class. Holds all settings state, bridges UserDefaults and the
existing services, and provides mutation methods the SwiftUI view calls.

**State owned:**

| Property | Type | Persistence | Bridge |
|----------|------|-------------|--------|
| `pausePlaybackEnabled` | `Bool` | UserDefaults key `"pausePlaybackEnabled"` | didSet writes to UserDefaults |
| `maximizeMicVolumeEnabled` | `Bool` | UserDefaults key `"maximizeMicVolumeEnabled"` | didSet writes to UserDefaults |
| `launchAtLoginEnabled` | `Bool` | SMAppService live query | didSet calls register/unregister |
| `selectedMicID` | `AudioDeviceID?` | UserDefaults via MicrophoneDeviceService | didSet delegates to microphoneService |
| `vocabularyEntries` | `[VocabularyEntry]` | UserDefaults via VocabularyService | didSet delegates to vocabularyService |

**Why @Observable over @AppStorage in the view:**

`@AppStorage` inside a SwiftUI view works for scalar types but conflicts with
`@Observable` — the Observation framework does not support `@AppStorage` as a stored
property on an `@Observable` class (confirmed limitation as of macOS 14/15). Using
`didSet` on plain stored properties with manual `UserDefaults.standard.set(...)` is
the correct pattern when `@Observable` is required. This also centralizes all
persistence logic in one class rather than scattering `@AppStorage` across views.

**Why not pass SettingsViewModel via environment:**

The hosting controller creates a fresh SwiftUI view tree. Passing the view model as a
direct constructor argument (`SettingsView(viewModel:)`) is simpler than environment
injection for a single-window case and avoids the `environmentObject`/`@Observable`
environment mismatch (the `.environment` modifier for `@Observable` objects requires
the object to be passed at the scene level, which is inaccessible from an
`NSHostingController` created outside the `App` scene graph).

```swift
@Observable
@MainActor
final class SettingsViewModel {
    var pausePlaybackEnabled: Bool {
        didSet { UserDefaults.standard.set(pausePlaybackEnabled, forKey: "pausePlaybackEnabled") }
    }
    var maximizeMicVolumeEnabled: Bool {
        didSet { UserDefaults.standard.set(maximizeMicVolumeEnabled, forKey: "maximizeMicVolumeEnabled") }
    }
    var launchAtLoginEnabled: Bool {
        didSet {
            do {
                if launchAtLoginEnabled { try SMAppService.mainApp.register() }
                else { try SMAppService.mainApp.unregister() }
            } catch {
                // Revert on failure — SMAppService can fail if user denied in Privacy
                launchAtLoginEnabled = SMAppService.mainApp.status == .enabled
            }
        }
    }
    var selectedMicID: AudioDeviceID?  {
        didSet { microphoneService.selectedDeviceID = selectedMicID }
    }
    var vocabularyEntries: [VocabularyEntry] {
        didSet { vocabularyService.entries = vocabularyEntries }
    }

    private(set) var availableMics: [AudioDeviceInfo] = []
    private(set) var haikuCleanup: (any HaikuCleanupProtocol)?

    private let vocabularyService: VocabularyService
    private let microphoneService: MicrophoneDeviceService

    init(vocabularyService: VocabularyService,
         microphoneService: MicrophoneDeviceService,
         haikuCleanup: (any HaikuCleanupProtocol)?) {
        self.vocabularyService = vocabularyService
        self.microphoneService = microphoneService
        self.haikuCleanup = haikuCleanup
        // Load initial values from existing persistence layer
        self.pausePlaybackEnabled = UserDefaults.standard.bool(forKey: "pausePlaybackEnabled")
        self.maximizeMicVolumeEnabled = UserDefaults.standard.bool(forKey: "maximizeMicVolumeEnabled")
        self.launchAtLoginEnabled = SMAppService.mainApp.status == .enabled
        self.selectedMicID = microphoneService.selectedDeviceID
        self.vocabularyEntries = vocabularyService.entries
        self.availableMics = microphoneService.availableInputDevices()
    }
}
```

---

### New: `SettingsView.swift`

**Location:** `MyWhisper/Settings/SettingsView.swift`

Pure SwiftUI view. Receives `SettingsViewModel` as a constructor argument. Uses `@Bindable`
to derive bindings from the `@Observable` view model.

```swift
struct SettingsView: View {
    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        Form {
            Section("Grabacion") {
                KeyboardShortcuts.Recorder("Atajo de grabacion:", name: .toggleRecording)
                Picker("Microfono:", selection: $viewModel.selectedMicID) {
                    Text("Predeterminado del sistema").tag(AudioDeviceID?.none)
                    ForEach(viewModel.availableMics) { mic in
                        Text(mic.name).tag(AudioDeviceID?.some(mic.id))
                    }
                }
            }
            Section("API") {
                Button("Cambiar clave de API...") {
                    // delegate to APIKeyWindowController via callback stored in viewModel
                    viewModel.openAPIKey()
                }
            }
            Section("Vocabulario") {
                // List with inline editing, add/remove buttons
            }
            Section("Sistema") {
                Toggle("Iniciar al arranque", isOn: $viewModel.launchAtLoginEnabled)
                Toggle("Pausar reproduccion al grabar", isOn: $viewModel.pausePlaybackEnabled)
                Toggle("Maximizar volumen al grabar", isOn: $viewModel.maximizeMicVolumeEnabled)
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(minWidth: 480, minHeight: 520)
    }
}
```

**`KeyboardShortcuts.Recorder` in SwiftUI:** The `KeyboardShortcuts` library ships a native
SwiftUI `KeyboardShortcuts.Recorder` view (distinct from the existing `RecorderCocoa` used
in the AppKit panel). No bridge required. It handles UserDefaults persistence internally
and integrates directly in a `Form` without wrapper code.

**Vocabulary list:** `List` with `ForEach` over `viewModel.vocabularyEntries` using
`.onDelete` and a toolbar button for add. Each row uses `TextField` bound to
`$viewModel.vocabularyEntries[index].wrong` / `.correct`. This replaces the
`NSTableView` + manual datasource entirely.

**APIKeyWindowController bridge:** The view model holds a closure `openAPIKey: () -> Void`
injected by `SettingsWindowController` at init. The SwiftUI button calls it. This keeps
the SwiftUI view free of AppKit references while preserving the existing APIKeyWindowController
without modification.

---

### Unchanged Components

| Component | Why Unchanged |
|-----------|---------------|
| `APIKeyWindowController.swift` | Remains AppKit NSPanel; called via closure from SettingsViewModel |
| `VocabularyService.swift` | SettingsViewModel delegates to it directly; no interface change needed |
| `MicrophoneDeviceService.swift` | SettingsViewModel reads `availableInputDevices()` and delegates `selectedDeviceID` writes |
| `StatusMenuController.swift` | `openSettings()` already calls `settingsWindowController?.show()` — no change |
| `AppDelegate.swift` | `SettingsWindowController` init signature stays identical (`vocabularyService:microphoneService:haikuCleanup:`) |
| `AppCoordinator.swift` | Not involved in settings UI at all |
| `UserDefaults` keys | Same keys: `"pausePlaybackEnabled"`, `"maximizeMicVolumeEnabled"`, `"selectedMicrophoneID"`, `"vocabularyCorrections"` |

---

## Data Flow

### Settings Open

```
User clicks "Preferencias..." in menubar
    ↓
StatusMenuController.openSettings()
    ↓
SettingsWindowController.show()
    → panel already exists? → makeKeyAndOrderFront()
    → first open: create NSWindow(contentViewController: NSHostingController(rootView: SettingsView(viewModel:)))
    → window.center(), setActivationPolicy(.regular), makeKeyAndOrderFront()
    ↓
NSHostingController renders SettingsView
    → @Bindable var viewModel reads initial state already loaded in SettingsViewModel.init()
    → All controls show current values immediately
```

### Setting Changed (Boolean Toggle)

```
User flips "Pausar reproduccion al grabar"
    ↓
SwiftUI Toggle mutates $viewModel.pausePlaybackEnabled (Binding from @Bindable)
    ↓
SettingsViewModel.pausePlaybackEnabled.didSet fires
    → UserDefaults.standard.set(true, forKey: "pausePlaybackEnabled")
    ↓
AppCoordinator reads UserDefaults.standard.bool(forKey: "pausePlaybackEnabled")
  at next recording start — no live observer needed, value is read on each use
```

### Setting Changed (Microphone Selection)

```
User selects mic from Picker
    ↓
SwiftUI Picker mutates $viewModel.selectedMicID
    ↓
SettingsViewModel.selectedMicID.didSet fires
    → microphoneService.selectedDeviceID = newValue
    → MicrophoneDeviceService writes UInt32 to UserDefaults key "selectedMicrophoneID"
    ↓
AudioRecorder.start() reads microphoneService.selectedDeviceID at next recording
  — no live observer needed
```

### Setting Changed (Vocabulary)

```
User edits vocabulary entry text field
    ↓
Binding mutation on $viewModel.vocabularyEntries[i].wrong/.correct
    ↓
SettingsViewModel.vocabularyEntries.didSet fires
    → vocabularyService.entries = vocabularyEntries
    → VocabularyService encodes [VocabularyEntry] to UserDefaults key "vocabularyCorrections"
    ↓
AppCoordinator calls vocabularyService.apply(to:) after Haiku cleanup —
  reads from UserDefaults on each call; always current
```

### Settings Window Closed

```
User clicks red close button
    ↓
NSWindowDelegate.windowWillClose(_:)
    → NSApp.setActivationPolicy(.accessory)  // hide from Dock
    → self.panel = nil                        // allow fresh window on next open
```

---

## Architectural Patterns

### Pattern 1: NSHostingController as Content View Controller

**What:** `NSWindow(contentViewController: NSHostingController(rootView:))` — AppKit creates
the window and owns the lifecycle; SwiftUI owns the layout. The hosting controller's
`view.fittingSize` drives automatic window sizing.

**When to use:** Any AppKit-managed window that needs SwiftUI content in an existing
non-scene-based (AppDelegate) app.

**Trade-offs:** Clean boundary. SwiftUI Form renders natively with macOS grouping/styling.
No storyboard or XIB needed. Window lifecycle (show/close/activate) remains in AppKit
where the existing activation policy logic already lives.

### Pattern 2: @Observable ViewModel as Bridge Layer

**What:** `SettingsViewModel` acts as the translation layer between the SwiftUI reactive
model (Observation framework) and the imperative persistence layer (UserDefaults direct
writes, service method calls). `didSet` on each property fires the side effect.

**When to use:** When services are injected objects (not singletons), when `@AppStorage`
is insufficient (custom types, service delegation), or when bridging `@Observable` with
existing non-reactive services.

**Trade-offs:** All mutation logic is in one class — easy to test. The view stays dumb.
`didSet` fires synchronously on `@MainActor`, consistent with all existing service access
patterns. Slight verbosity vs `@AppStorage` for scalar Booleans, but necessary because
`@Observable` and `@AppStorage` on the same class are incompatible.

### Pattern 3: Closure Injection for AppKit Sub-Panel

**What:** `SettingsViewModel` holds `var openAPIKey: () -> Void = {}`. The
`SettingsWindowController` injects a concrete implementation at init:
`viewModel.openAPIKey = { [weak self] in self?.apiKeyController.show() }`.

**When to use:** When a SwiftUI view needs to trigger an AppKit window without importing
AppKit or holding a reference to a controller.

**Trade-offs:** SwiftUI view remains pure Swift/SwiftUI. APIKeyWindowController needs
no changes. Testable — the closure can be swapped for a mock in tests.

### Pattern 4: Persistent Window (NSWindow not NSPanel)

**What:** Replace `NSPanel` with `NSWindow` using identical style mask `[.titled, .closable]`.

**When to use:** When a settings-style window should remain open after the user clicks
outside it (standard System Preferences / Settings.app behavior).

**Why NSPanel closed on outside click:** `NSPanel` has implicit behavior where it
resigns key status and can be closed on outside click unless style flags are carefully
set. `NSWindow` with `[.titled, .closable]` does not auto-close on outside click.
This is the simplest fix for the v1.3 requirement.

---

## Recommended File Structure

```
MyWhisper/
├── Settings/
│   ├── SettingsWindowController.swift   (MODIFIED — gutted to ~60 lines)
│   ├── SettingsViewModel.swift          (NEW)
│   └── SettingsView.swift               (NEW)
├── UI/
│   ├── APIKeyWindowController.swift     (unchanged)
│   └── ...
```

No folder restructuring required. The existing `MyWhisper/Settings/` folder already exists
(currently holds only `SettingsWindowController.swift`).

---

## Build Order

Dependencies determine build order. No changes to AppDelegate, StatusMenuController,
or any service — only the Settings folder changes.

```
Step 1: SettingsViewModel.swift  (new file)
        - Depends on: VocabularyService, MicrophoneDeviceService, HaikuCleanupProtocol
          (all already exist, no changes needed there)
        - Add ServiceManagement import; no new framework import in project needed
          (ServiceManagement already imported in SettingsWindowController for SMAppService)
        - Can be written and compiled before the view exists

Step 2: SettingsView.swift  (new file)
        - Depends on: SettingsViewModel (Step 1)
        - Import KeyboardShortcuts for KeyboardShortcuts.Recorder SwiftUI view
        - Write Form structure with all sections
        - Vocabulary List with inline editing
        - APIKey button calling viewModel.openAPIKey()

Step 3: SettingsWindowController.swift  (modify — delete ~250 lines, write ~60)
        - Depends on: SettingsViewModel (Step 1), SettingsView (Step 2)
        - Delete all NSTableView datasource/delegate code
        - Delete all NSLayoutConstraint code
        - Delete all NSButton/NSPopUpButton/NSCheckbox wiring
        - Replace show() body with NSHostingController embedding
        - Inject openAPIKey closure into viewModel
        - windowWillClose keeps existing activation policy reset

Step 4: Manual smoke test
        - Open Settings from menubar
        - Verify window stays open on outside click
        - Toggle each setting, quit, relaunch — verify persistence
        - Change mic, record audio — verify correct device used
        - Add/edit/remove vocabulary entry — verify applied to next transcription
        - Change API key via button — verify APIKeyWindowController opens
        - Verify hotkey recorder (KeyboardShortcuts.Recorder) works in the Form
```

---

## Integration Points

### Internal Boundaries

| Boundary | Communication | Notes |
|----------|---------------|-------|
| `SettingsWindowController` → `SettingsViewModel` | Constructor injection | ViewModel created once per controller lifetime |
| `SettingsWindowController` → `NSHostingController` | `NSWindow(contentViewController:)` | SwiftUI tree created on first `show()` |
| `SettingsViewModel` → `VocabularyService` | Direct method calls in `didSet` | Same instance AppCoordinator uses |
| `SettingsViewModel` → `MicrophoneDeviceService` | Direct property write in `didSet` | Same instance AudioRecorder uses |
| `SettingsViewModel` → `UserDefaults.standard` | Direct key-value write in `didSet` | Same keys as current AppKit implementation |
| `SettingsViewModel` → `SMAppService.mainApp` | `register()` / `unregister()` in `didSet` | Error causes state revert |
| `SettingsView` → `SettingsViewModel` | `@Bindable` bindings | Two-way, mutation goes through ViewModel |
| `SettingsView` → `APIKeyWindowController` | Closure via ViewModel | No AppKit import in view |

### No New External Boundaries

No new frameworks, no new UserDefaults keys, no new network calls. The migration is
entirely within the Settings folder.

---

## Anti-Patterns

### Anti-Pattern 1: Using @AppStorage in SettingsView Directly

**What people do:** Add `@AppStorage("pausePlaybackEnabled") var pause = false` directly
in the SwiftUI view, skipping the view model.

**Why it's wrong:** `@AppStorage` on an `@Observable` class is unsupported (compiler error
or silent misbehavior). In the view itself it works, but then persistence logic is scattered
across the view instead of centralized. More importantly, it bypasses the `VocabularyService`
and `MicrophoneDeviceService` — those services own the storage for their respective keys
and must be the single writer.

**Do this instead:** Centralize all persistence in `SettingsViewModel.didSet` blocks.
`@AppStorage` is acceptable for simple scalar preferences in a fully SwiftUI app with
no existing service layer; not appropriate here.

### Anti-Pattern 2: Keeping NSPanel for the Settings Window

**What people do:** Keep `NSPanel` and add `.nonactivating` or `becomesKeyOnlyIfNeeded`
flags to prevent it from closing on outside click.

**Why it's wrong:** `.nonactivating` prevents the panel from ever becoming the key window,
which makes text fields (vocabulary editing, API key) unresponsive to keyboard input.
`becomesKeyOnlyIfNeeded` helps but has documented edge cases. A plain `NSWindow` avoids
the entire NSPanel behavioral complexity for a standard settings use case.

**Do this instead:** Use `NSWindow` with `[.titled, .closable]`. It stays open on outside
click by default.

### Anti-Pattern 3: Injecting Services via SwiftUI Environment from NSHostingController

**What people do:** Call `.environment(viewModel)` on the SwiftUI view inside the
`NSHostingController` to inject the view model.

**Why it's wrong:** The `.environment` modifier for `@Observable` objects (the new API,
not `environmentObject`) works within a SwiftUI `App` scene graph. An `NSHostingController`
created outside the scene (which is the case here — `MyWhisperApp.body` is just a
`Settings { EmptyView() }` stub) may not propagate environment values correctly in all
macOS versions. Direct constructor argument is reliable and explicit.

**Do this instead:** Pass `SettingsView(viewModel: viewModel)` as the root view.

### Anti-Pattern 4: Recreating NSHostingController on Every show()

**What people do:** Create a new `NSHostingController` and `NSWindow` every time `show()`
is called, including when the window is already open.

**Why it's wrong:** Recreating the hosting controller discards SwiftUI state (vocabulary
list edits in progress, scroll position). The existing `if let existing = panel` guard
prevents this and is the correct pattern — reuse the existing window.

**Do this instead:** Keep the `guard if panel exists → makeKeyAndOrderFront` early return.
Set `panel = nil` only in `windowWillClose`, not in `show()`.

### Anti-Pattern 5: Observing UserDefaults in AppCoordinator for Live Settings Updates

**What people do:** Add a `UserDefaults` observer or Combine publisher in `AppCoordinator`
so settings changes take effect immediately without restarting a recording.

**Why it's wrong:** None of the settings require live application during an active recording.
`pausePlaybackEnabled` and `maximizeMicVolumeEnabled` are read at recording start. Adding
reactive observation adds complexity with no user-visible benefit.

**Do this instead:** Keep the current pattern — services read their UserDefaults values
at the moment they are needed (recording start). No observer wiring required.

---

## Sources

- Existing source code read directly from `/Users/max/Personal/repos/my-superwhisper/MyWhisper/` — HIGH confidence
- [Showing Settings from macOS Menu Bar Items — Peter Steinberger (2025)](https://steipete.me/posts/2025/showing-settings-from-macos-menu-bar-items) — HIGH confidence (documents activation policy pattern, NSWindow vs NSPanel for menubar apps)
- [KeyboardShortcuts — sindresorhus/KeyboardShortcuts GitHub README](https://github.com/sindresorhus/KeyboardShortcuts) — HIGH confidence (confirms SwiftUI `KeyboardShortcuts.Recorder` view, distinct from `RecorderCocoa`)
- [Launch at Login Setting — nilcoalescing.com](https://nilcoalescing.com/blog/LaunchAtLoginSetting/) — HIGH confidence (SMAppService + SwiftUI Toggle pattern with error revert)
- [NSHostingController — Apple Developer Documentation](https://developer.apple.com/documentation/swiftui/nshostingcontroller) — HIGH confidence (official API)
- [@Observable and @AppStorage compatibility — Apple Developer Forums](https://developer.apple.com/forums/thread/731187) — MEDIUM confidence (confirms @Observable + @AppStorage incompatibility; workaround is didSet + manual UserDefaults.standard.set)
- [The Curious Case of NSPanel's Nonactivating Style Mask Flag (2025)](https://philz.blog/nspanel-nonactivating-style-mask-flag/) — MEDIUM confidence (explains NSPanel behavioral edge cases; supports NSWindow preference)

---

*Architecture research for: v1.3 Settings UX — SwiftUI migration + persistent window*
*Researched: 2026-03-24*
