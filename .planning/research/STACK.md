# Stack Research

**Domain:** v1.3 Settings UX — SwiftUI settings window migration + persistent window behavior
**Researched:** 2026-03-24
**Confidence:** HIGH (NSHostingController bridge), HIGH (NSWindow persistent pattern), MEDIUM (Form/GroupBox styling)

> **Scope note:** This file covers ONLY the new capabilities needed for v1.3.
> The existing validated stack (Swift/SwiftUI, WhisperKit, Haiku API, KeyboardShortcuts,
> CoreAudio, CGEventPost, MediaRemote, NSWorkspace) is unchanged and not re-researched here.

---

## Recommended Stack

### Core Technologies

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| `NSHostingController<Content>` (SwiftUI) | macOS 14+ (built-in) | Embed a SwiftUI view tree as the contentViewController of an NSWindow | The correct AppKit bridge for controllers (not just views). Manages the SwiftUI render tree lifecycle, environment injection, and `@State` re-renders properly. The project already uses `NSHostingView` in `AppDelegate.showPermissionBlockedWindow` — same pattern scaled to a full settings screen. |
| `NSWindow` (AppKit) | macOS 14+ (built-in) | Host the settings content with full behavioral control | Preferred over NSPanel for settings. NSPanel's default `hidesOnDeactivate = true` causes it to disappear when the app loses focus — the exact bug we're fixing. A plain `NSWindow` with `isReleasedWhenClosed = false` and `override func close()` → `orderOut(nil)` gives persistent behavior without subclassing NSPanel. |
| `Form` + `.formStyle(.grouped)` (SwiftUI) | macOS 14+ | Main layout container for settings sections | `.formStyle(.grouped)` renders as a macOS-native inset grouped list — the closest approximation to System Settings appearance without custom drawing. Available on macOS 13+ but matured in macOS 14 with `LabeledContent` alignment. |
| `LabeledContent` (SwiftUI) | macOS 14+ | Label-control pairs inside Form sections | Automatically aligns labels and controls in a two-column grid matching macOS Human Interface Guidelines. Replaces manual HStack with trailing alignment. The correct primitive for hotkey recorder row, microphone picker row, etc. |
| `GroupBox` (SwiftUI) | macOS 13+ | Optional visual grouping within Form | Renders with a rounded-rect background on macOS, matching System Preferences section cards. Use for logical groups (e.g., "Recording", "Appearance"). Alternative to relying solely on `Section` headers inside Form. |

### Supporting Libraries

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `KeyboardShortcuts.Recorder` (SwiftUI view) | 2.4.0+ (already in Package.swift) | SwiftUI-native hotkey recorder | Use `KeyboardShortcuts.Recorder("Label:", name: .toggleRecording)` directly inside `Form`/`LabeledContent` — no `NSViewRepresentable` wrapper needed. The library ships both `Recorder` (SwiftUI) and `RecorderCocoa` (AppKit). The current code uses `RecorderCocoa` in the AppKit panel; migration just swaps to the SwiftUI `Recorder`. |

### Development Tools

| Tool | Purpose | Notes |
|------|---------|-------|
| Xcode 16 / Swift 5.10 | Build toolchain | No change. Project already targets macOS 14, which is the minimum for `LabeledContent` alignment behavior in Form. |

---

## Installation

No new SPM packages. No new frameworks. No Info.plist changes. No entitlement changes.

The only relevant Package.swift version constraint (already satisfied):

```swift
.package(url: "https://github.com/sindresorhus/KeyboardShortcuts", from: "2.4.0")
// KeyboardShortcuts.Recorder (SwiftUI) ships in all versions >= 1.0
```

---

## NSWindow Persistent Pattern — Exact Implementation

This is the core of v1.3. The goal is a settings window that stays open when the user clicks another app, only closing on explicit ✕ or Cmd+W.

### Why NSPanel closes on focus loss (current bug)

`NSPanel` has `hidesOnDeactivate = true` by default. When the menubar app switches from `.regular` to `.accessory` activation policy after the settings window appears, or when the user focuses another app, the panel hides. Fixing this on `NSPanel` requires overriding `hidesOnDeactivate` AND fighting the `.nonactivatingPanel` style mask semantics. It is cleaner to use `NSWindow` directly.

### Correct pattern: NSWindow + NSHostingController

```swift
// In SettingsWindowController.show():

let hostingController = NSHostingController(rootView: SettingsView(...))

let window = NSWindow(
    contentRect: NSRect(x: 0, y: 0, width: 520, height: 620),
    styleMask: [.titled, .closable, .miniaturizable, .resizable],
    backing: .buffered,
    defer: false
)
window.title = "MyWhisper — Preferencias"
window.contentViewController = hostingController
window.isReleasedWhenClosed = false   // CRITICAL: keep window in memory
window.center()

self.window = window
```

### Preventing auto-close on focus loss

Override `close()` in an NSWindow subclass to call `orderOut(nil)` (hide) instead of actually closing, and set `windowWillClose` delegate to restore activation policy:

```swift
final class PersistentWindow: NSWindow {
    override func close() {
        // orderOut hides the window without deallocating it.
        // The controller holds the strong reference via self.window.
        orderOut(nil)
    }
}
```

Alternatively (simpler, no subclass): intercept `windowShouldClose` in the delegate and return `false`, calling `orderOut(nil)` manually. Both approaches work on macOS 14+.

### Activation policy lifecycle

The existing `SettingsWindowController` already handles this correctly:
- `show()`: `NSApp.setActivationPolicy(.regular)` then `window.makeKeyAndOrderFront(nil)` then `NSApp.activate(ignoringOtherApps: true)`
- `windowWillClose`: `NSApp.setActivationPolicy(.accessory)`

With persistent behavior, "close" means "hide" (`orderOut`) — the `windowWillClose` path for policy restoration must be triggered only when the user explicitly closes (✕ button or Cmd+W), not on focus loss.

**Key distinction:**
- Focus loss (user switches to another app) → window stays visible (no action needed)
- Explicit close (✕ or Cmd+W) → `orderOut` + restore `.accessory` policy

---

## SwiftUI Form Layout — Exact Pattern

```swift
import SwiftUI

struct SettingsView: View {
    var body: some View {
        Form {
            Section("Grabación") {
                LabeledContent("Atajo:") {
                    KeyboardShortcuts.Recorder("", name: .toggleRecording)
                }
                LabeledContent("Micrófono:") {
                    Picker("", selection: $selectedMicID) {
                        Text("Predeterminado del sistema").tag(AudioDeviceID?.none)
                        ForEach(availableMics) { mic in
                            Text(mic.name).tag(Optional(mic.id))
                        }
                    }
                    .labelsHidden()
                }
            }

            Section("Comportamiento") {
                Toggle("Pausar reproducción al grabar",
                       isOn: $pausePlaybackEnabled)
                Toggle("Maximizar volumen al grabar",
                       isOn: $maximizeMicVolumeEnabled)
                Toggle("Iniciar al arranque",
                       isOn: $launchAtLoginEnabled)
            }

            Section("Vocabulario") {
                // ForEach with TextField for editable vocabulary list
            }

            Section {
                Button("Cambiar clave de API...") { showAPIKeyWindow() }
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 480, maxWidth: 600)
    }
}
```

**Notes on `.formStyle(.grouped)`:**
- Produces inset-grouped sections matching System Settings on macOS 13+.
- On macOS 14+ the two-column label alignment in `LabeledContent` is automatic.
- A known cosmetic issue: `.formStyle(.grouped)` adds ~20pt top padding that looks excessive in a standalone window. Apply `.padding(.top, -20)` to the `Form` if this appears.

---

## Vocabulary List — Editable Rows Pattern

The current AppKit `NSTableView` with inline editing can be replaced with a SwiftUI `List` + `TextField` bindings. For this small dataset (< 50 entries), SwiftUI `List` performance is adequate on macOS 14:

```swift
Section("Correcciones de vocabulario") {
    List {
        ForEach($vocabEntries) { $entry in
            HStack {
                TextField("Incorrecto", text: $entry.wrong)
                TextField("Correcto", text: $entry.correct)
            }
        }
        .onDelete { indexSet in
            vocabEntries.remove(atOffsets: indexSet)
        }
    }
    .frame(minHeight: 120, maxHeight: 200)

    HStack {
        Button(action: addEntry) { Image(systemName: "plus") }
        Button(action: removeSelected) { Image(systemName: "minus") }
            .disabled(selectedEntry == nil)
    }
    .buttonStyle(.borderless)
}
```

**Caveat:** SwiftUI `List` on macOS does not natively support the Delete key removing rows (.onDeleteCommand works but only with a selected row and the Edit > Delete menu path). If UX testing reveals friction with the Delete key, fallback to wrapping the existing `NSTableView` via `NSViewRepresentable` — the current AppKit implementation is correct and can be bridged without full replacement.

---

## Alternatives Considered

| Recommended | Alternative | When to Use Alternative |
|-------------|-------------|-------------------------|
| `NSWindow` + `NSHostingController` | SwiftUI `Settings` scene | Use `Settings` scene only if the app is a fully SwiftUI lifecycle app with `WindowGroup`. This project uses `NSApplicationDelegateAdaptor` and manual window management — the `Settings` scene requires calling `openSettings` from a SwiftUI environment action, which requires a hidden 1x1 NSWindow workaround for menubar apps (5+ hours of complexity per steipete.me). Direct `NSWindow + NSHostingController` is the right choice here. |
| `NSWindow` with `isReleasedWhenClosed = false` | `NSPanel` with `hidesOnDeactivate = false` | `NSPanel` with `hidesOnDeactivate = false` technically works but fights against the panel's design intent. NSPanel was designed for floating tool palettes, not primary settings windows. Use NSPanel only for truly non-modal floating overlays (inspector panels, color pickers). |
| `KeyboardShortcuts.Recorder` (SwiftUI) | `KeyboardShortcuts.RecorderCocoa` wrapped in `NSViewRepresentable` | Only use `RecorderCocoa` if staying in an AppKit view hierarchy. In a SwiftUI Form, `Recorder` is the first-class API and requires zero bridging code. |
| `Form` + `.formStyle(.grouped)` | `NavigationSplitView` with sidebar | `NavigationSplitView` is for multi-pane settings (like System Settings with 30+ sections). This app has one settings screen with < 10 controls. A single-column `Form` is the correct complexity level — avoid `NavigationSplitView` here. |
| `List` with `TextField` rows for vocabulary | `NSTableView` via `NSViewRepresentable` | If Delete-key row removal or complex column resizing is needed, keep `NSTableView` bridged. For a small list with basic add/remove, SwiftUI `List` is sufficient and avoids AppKit bridging overhead. |
| `LabeledContent` for control rows | Manual `HStack` with `Spacer()` | `LabeledContent` handles macOS-idiomatic two-column alignment automatically and adapts to system font size. Manual `HStack` requires explicit width constants that break on different system font sizes. |

---

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| SwiftUI `Settings` scene + `openSettings` | On this project's architecture (AppDelegate + NSApplicationDelegateAdaptor), reliably opening the Settings scene from a menubar app requires a hidden 1x1 NSWindow workaround, timing delays (100ms + 200ms), and activation policy juggling. On macOS 26 (Tahoe), `openSettings` is confirmed broken. The complexity is not justified when `NSWindow + NSHostingController` is simpler and already proven by `showPermissionBlockedWindow`. | `NSWindow` + `NSHostingController` |
| `NSPanel` for the settings window | Default `hidesOnDeactivate = true` causes the settings window to disappear when focus moves to another app — this is the exact regression v1.3 fixes. | `NSWindow` with explicit persistent behavior |
| `.nonactivatingPanel` style mask | Prevents the window from becoming key, which blocks keyboard input in `TextField` and the `KeyboardShortcuts.Recorder`. | Standard `.titled, .closable` style mask on `NSWindow` |
| `NavigationSplitView` for a single-page settings UI | Adds tab bar / sidebar chrome unnecessary for < 10 settings. System Settings uses it because it has 50+ sections. Our settings fits in one scroll view. | `Form` + `.formStyle(.grouped)` |
| Calling `NSApp.setActivationPolicy(.regular)` on every app activation/focus event | Causes the Dock icon to flash in and out. Policy should only change to `.regular` when showing the settings window and back to `.accessory` when the window is explicitly closed (not on focus loss). | Change policy only in `show()` and explicit `close()` handler. |
| `window.isReleasedWhenClosed = true` (the default for NSWindow) | Default is `true` for NSWindow (opposite of NSPanel). If the controller stores a strong reference and the window self-releases on close, accessing the deallocated window on the next `show()` call crashes. | Always set `isReleasedWhenClosed = false` when keeping a window reference. |

---

## Stack Patterns by Variant

**If staying 100% within existing AppKit controller (`SettingsWindowController`):**
- Replace `NSPanel` with `NSWindow` (same constructor call, change class name)
- Replace `contentView` manual Auto Layout with `contentViewController = NSHostingController(rootView: SettingsView(...))`
- Set `isReleasedWhenClosed = false`
- Override `close()` to `orderOut(nil)` via subclass or `windowShouldClose` delegate
- Migration is surgical: one file changed, behavior is fully tested in isolation

**If extracting settings to a pure SwiftUI `SettingsView` struct:**
- `SettingsView` receives its dependencies via `@ObservableObject` / `@Bindable` wrappers, not as `init` parameters
- Services (`VocabularyService`, `MicrophoneDeviceService`, `HaikuCleanupService`) remain in AppKit layer, passed into `NSHostingController(rootView:)` via environment or init
- Preferred for testability — `SettingsView` previews in Xcode without spinning up `AppDelegate`

---

## Version Compatibility

| API | macOS Requirement | Notes |
|-----|-------------------|-------|
| `NSHostingController` | macOS 10.15+ | Stable, used in AppDelegate already via `NSHostingView` sibling |
| `Form` + `.formStyle(.grouped)` | macOS 13+ (stable in 14+) | `.grouped` style available on 13; two-column `LabeledContent` alignment reliable on 14+ — matches project's existing macOS 14 deployment target |
| `LabeledContent` | macOS 13+ | Alignment behavior improved in 14; fine for this project's macOS 14 target |
| `KeyboardShortcuts.Recorder` (SwiftUI) | macOS 10.15+ | Ships in the already-pinned `KeyboardShortcuts >= 2.4.0` |
| `NSWindow.isReleasedWhenClosed` | macOS 10.0+ | Stable AppKit property, unchanged |
| `NSApp.setActivationPolicy(_:)` | macOS 10.6+ | Stable; current code already uses this pattern correctly |

**Deployment target:** No change. macOS 14+ (Apple Silicon). All APIs above are available on macOS 14.

**Non-sandboxed requirement:** No change. Settings window management requires no new entitlements.

---

## Sources

- `steipete.me/posts/2025/showing-settings-from-macos-menu-bar-items` — confirmed that SwiftUI `Settings` scene + `openSettings` requires hidden-window workarounds for menubar apps; `openSettings` broken on macOS Tahoe (26); NSWindow + NSHostingController is the recommended alternative — MEDIUM confidence (personal blog, confirmed by mjtsai.com commentary)
- `artlasovsky.com/fine-tuning-macos-app-activation-behavior` — exact activation policy switching patterns (`applicationWillFinishLaunching` / `applicationDidFinishLaunching`), `isReleasedWhenClosed` usage, NSPanel vs NSWindow behavioral differences — MEDIUM confidence (personal blog, patterns cross-validated with Apple Developer Forums)
- `cindori.com/developer/floating-panel` — NSPanel subclass pattern; confirmed `canBecomeKey = true` required for text input in panels; confirmed `hidesOnDeactivate` is the root cause of settings panel closure — MEDIUM confidence (well-known macOS developer blog)
- Apple Developer Documentation — `NSHostingController`, `NSHostingView`, `Form`, `LabeledContent`, `GroupBox`, `NSWindow.isReleasedWhenClosed` — HIGH confidence (official Apple docs)
- `github.com/sindresorhus/KeyboardShortcuts` — confirmed `KeyboardShortcuts.Recorder` SwiftUI view ships in the library; `RecorderCocoa` is the AppKit-only variant — HIGH confidence (official repository README)
- `github.com/sindresorhus/Settings` — confirmed pattern of `NSHostingController` + `NSWindow` for settings; library approach validated but not needed (adds dependency for functionality already achievable with 20 lines) — MEDIUM confidence (well-maintained OSS)
- WebSearch + Apple Developer Forums — `.formStyle(.grouped)` top-padding quirk; `List` Delete-key limitation on macOS; `LabeledContent` two-column alignment — LOW-MEDIUM confidence (community sources, not official docs)

---

*Stack research for: v1.3 Settings UX — SwiftUI migration + persistent window behavior*
*Researched: 2026-03-24*
