# Project Research Summary

**Project:** my-superwhisper — v1.3 Settings UX
**Domain:** macOS menubar app — AppKit NSPanel to SwiftUI settings window migration
**Researched:** 2026-03-24
**Confidence:** HIGH

## Executive Summary

v1.3 is a focused UI migration: the existing AppKit NSPanel-based `SettingsWindowController` (306 lines of NSTableView/NSLayoutConstraint wiring) is replaced with a SwiftUI `Form` hosted inside a plain `NSWindow` via `NSHostingController`. The core functional problem being fixed is that the current `NSPanel` closes when the user clicks outside it — standard macOS settings behavior is to stay open until the user explicitly presses the close button. The fix is precise and already proven in this codebase: replace `NSPanel` with `NSWindow` (same style mask, change the class name, set `isReleasedWhenClosed = false`). The architectural pattern of `NSWindow + NSHostingController` is the same one already used in `AppDelegate.showPermissionBlockedWindow`.

The recommended approach is a clean three-file migration inside the existing `MyWhisper/Settings/` folder. `SettingsWindowController.swift` shrinks from 306 to ~60 lines. Two new files are added: `SettingsViewModel.swift` (an `@Observable @MainActor` class that bridges UserDefaults and existing services) and `SettingsView.swift` (a pure SwiftUI `Form` with `.formStyle(.grouped)`). No new dependencies, no new entitlements, no new UserDefaults keys. All existing services (`VocabularyService`, `MicrophoneDeviceService`, `APIKeyWindowController`) are used unchanged. The activation policy lifecycle (`show()` sets `.regular`, `windowWillClose` restores `.accessory`) already exists in the current controller and is preserved as-is.

The primary risks are concentrated in Phase 1 (window lifecycle). The SwiftUI `openSettings` environment action and the `Settings` scene approach are explicitly ruled out for this architecture — they require hidden-window workarounds for menubar apps and `openSettings` is confirmed broken on macOS 26 (Tahoe). The four Phase 1 pitfalls (activation policy leaking dock icon, window not becoming key, settings closing on focus loss, `openSettings` silently failing) must be validated before any Phase 2 UI work begins. Phase 2 risks are lower: `@AppStorage` on an `@Observable` class is unsupported (use `didSet` + manual `UserDefaults.standard.set`), `NSHostingController` default sizing options pin the window size (set `sizingOptions = [.minSize]` if needed), and the `KeyboardShortcuts.Recorder` SwiftUI variant (not `RecorderCocoa`) must be used to avoid the first-responder warning.

---

## Key Findings

### Recommended Stack

No new dependencies are required. The migration uses only built-in macOS 14+ APIs and the already-pinned `KeyboardShortcuts >= 2.4.0` library. The project already targets macOS 14, which is the minimum for stable `LabeledContent` two-column alignment in `Form`.

**Core technologies:**
- `NSWindow` (AppKit, macOS 14+): replaces `NSPanel` as the settings window host — does not auto-close on outside click, unlike NSPanel's default `hidesOnDeactivate = true` behavior; same style mask `[.titled, .closable]`, just a different class
- `NSHostingController<SettingsView>` (SwiftUI, macOS 10.15+): bridges SwiftUI view tree into NSWindow as `contentViewController` — manages render lifecycle and `@State` re-renders; already used in `AppDelegate.showPermissionBlockedWindow`
- `Form` + `.formStyle(.grouped)` (SwiftUI, macOS 13+, stable 14+): main layout container — produces inset-grouped sections matching System Settings; apply `.padding(.top, -20)` if top padding looks excessive
- `LabeledContent` (SwiftUI, macOS 13+): label-control pairs inside Form — automatic two-column alignment matching macOS HIG; replaces manual `HStack` with spacing constants that break at non-default font sizes
- `KeyboardShortcuts.Recorder` SwiftUI view (already in Package.swift >= 2.4.0): native SwiftUI hotkey recorder — no `NSViewRepresentable` wrapper needed; handles first-responder chain correctly inside `NSHostingController`
- `@Observable @MainActor SettingsViewModel` (new): bridge layer between SwiftUI reactive model and imperative services — `didSet` fires UserDefaults writes and service method calls synchronously on main actor

**Critical constraint:** `@AppStorage` on an `@Observable` class is unsupported (compiler error or silent misbehavior on macOS 14/15). All persistence must go through `didSet` + `UserDefaults.standard.set(...)`. This is not a workaround — it is the correct and only supported pattern for this architecture.

### Expected Features

This milestone wraps all 7 existing settings into the new SwiftUI Form and fixes the window persistence bug. Feature scope is frozen — no new settings are added in v1.3.

**Must have (table stakes — all already implemented, must survive migration without regression):**
- Configurable hotkey (KeyboardShortcuts.Recorder SwiftUI variant) — users expect their custom shortcut to be preserved
- Microphone selection (Picker over available input devices from MicrophoneDeviceService) — users with external mics depend on this
- API key management (button delegating to existing APIKeyWindowController via closure) — breaks the app if removed
- Custom vocabulary corrections (List with inline TextField rows) — replaces NSTableView; Delete-key keyboard behavior caveat applies
- Launch at login toggle (SMAppService — error must revert UI state)
- Pause playback toggle (UserDefaults key `"pausePlaybackEnabled"`, read at recording start)
- Maximize mic volume toggle (UserDefaults key `"maximizeMicVolumeEnabled"`, read at recording start)

**Should have (v1.3 new behavior):**
- Settings window stays open when user clicks outside it — the core v1.3 requirement
- Settings window position persisted across sessions via `NSWindow.setFrameAutosaveName("settings")`
- Grouped visual layout matching macOS System Settings conventions

**Defer to v2+:**
- Push-to-talk mode (hold hotkey vs toggle) — low complexity, but out of v1.3 scope
- Configurable LLM cleanup aggressiveness — out of scope
- Transaction history / recent transcriptions — out of scope

### Architecture Approach

The migration introduces a clean MVVM boundary inside the Settings folder. `SettingsWindowController` becomes a thin AppKit host (~60 lines) that owns the NSWindow lifecycle and activation policy. `SettingsViewModel` owns all settings state and bridges to existing services via `didSet`. `SettingsView` is a pure SwiftUI Form with `@Bindable` bindings to the view model. The existing `APIKeyWindowController` is reached via a closure injected into the view model — the SwiftUI view never imports AppKit.

**Major components:**
1. `SettingsWindowController` (modified, 306 → ~60 lines) — NSWindow creation, `isReleasedWhenClosed = false`, activation policy lifecycle (`.regular` on show, `.accessory` on `windowWillClose`), `NSWindowDelegate`; all NSTableView datasource/delegate code and NSLayoutConstraint blocks deleted
2. `SettingsViewModel` (new file) — `@Observable @MainActor`, owns all 5 state properties with `didSet` persistence bridges to UserDefaults and services; holds `var openAPIKey: () -> Void` closure injected by the controller
3. `SettingsView` (new file) — SwiftUI `Form` with `.formStyle(.grouped)`, `@Bindable var viewModel`, four sections (Grabacion, API, Vocabulario, Sistema)

**Key patterns:**
- `NSWindow(contentViewController: NSHostingController(rootView:))` — AppKit owns window lifecycle, SwiftUI owns layout; window auto-sizes to Form's `fittingSize`
- `@Observable` ViewModel as bridge — centralizes all persistence, makes the view dumb and testable in Xcode previews
- Closure injection for AppKit sub-panels — keeps SwiftUI view free of AppKit imports; `APIKeyWindowController` unchanged
- `panel != nil` guard in `show()` → `makeKeyAndOrderFront` early return — prevents SwiftUI state discard on re-open; `panel = nil` only in `windowWillClose`

### Critical Pitfalls

1. **`openSettings` / SwiftUI Settings scene silently fail in menubar apps** — Do not use the SwiftUI `Settings` scene or `openSettings` environment action. Use `NSWindow + NSHostingController` directly. `openSettings` is broken on macOS 26 (Tahoe) and unreliable for `.accessory` policy apps on earlier versions.

2. **Activation policy leaks dock icon or steals focus** — Switch to `.regular` only in `show()`, restore to `.accessory` in `windowWillClose` delegate (not on a timer). Always call `NSApp.hide(nil)` after restoring `.accessory` — policy switch alone does not return focus to the previously active app.

3. **NSHostingController window not becoming key (keyboard input dead)** — Ensure `NSApp.setActivationPolicy(.regular)` and `NSApp.activate(ignoringOtherApps: true)` complete before `makeKeyAndOrderFront(nil)`. Call `makeKeyAndOrderFront` via `DispatchQueue.main.async` yield if keyboard input is still unresponsive. Avoid `.windowStyle(.plain)` on any scene — it breaks `canBecomeKeyWindow`.

4. **Settings window closes on focus loss** — `NSPanel.hidesOnDeactivate = true` is the current bug. Using `NSWindow` with `[.titled, .closable]` fixes this by default — `NSWindow` does not auto-close on outside click. Set `isReleasedWhenClosed = false` to prevent deallocation when the controller holds a strong reference.

5. **`@AppStorage` Toggle UI desync on macOS 14** — Confirmed macOS 14 bug: toggles inside `Form` visually snap back to previous state even though UserDefaults is correctly updated. Use `@Observable` intermediary with manual `UserDefaults` read/write in `didSet`. This is already the required pattern because `@AppStorage` on an `@Observable` class is unsupported regardless.

---

## Implications for Roadmap

Based on research, suggested phase structure:

### Phase 1: Window Lifecycle Foundation

**Rationale:** All Phase 2 work is blocked until the window reliably opens, stays open, receives keyboard input, and closes cleanly without leaking the dock icon. The four window lifecycle pitfalls must be validated before any UI content is built — building UI into a broken window host creates ambiguous debugging loops. This is the same sequencing recommended in PITFALLS.md's pitfall-to-phase mapping.

**Delivers:** A working `NSWindow` that opens from the menubar, stays visible when the user clicks outside it, accepts keyboard input in TextFields, and restores activation policy cleanly on close. Smoke test items 1-4 and 9-10 and 13 from the "Looks Done But Isn't" checklist in PITFALLS.md pass.

**Addresses:** Settings window persistent behavior (core v1.3 requirement)

**Avoids:**
- Pitfall 1 (`openSettings` silent failure) — by not using `openSettings` at all; `NSWindow + NSHostingController` is the chosen approach
- Pitfall 2 (activation policy leak) — timing `.regular`/`.accessory` transition in `show()` and `windowWillClose` delegate; `NSApp.hide(nil)` after `.accessory` restore
- Pitfall 3 (keyboard dead) — confirming `canBecomeKeyWindow` and sequencing activation before `makeKeyAndOrderFront`
- Pitfall 7 (closes on focus loss) — using `NSWindow` instead of `NSPanel`; `isReleasedWhenClosed = false`

**Build order:**
1. Replace NSPanel constructor in `SettingsWindowController` with `NSWindow` + `isReleasedWhenClosed = false`
2. Replace `contentView` manual layout with `contentViewController = NSHostingController(rootView: SettingsView(viewModel:))` (placeholder view acceptable at this stage)
3. Validate smoke test: open from menubar, click outside, verify window stays open, type in TextField, close with X button, verify dock icon gone and previous app retains focus

### Phase 2: Settings UI Content

**Rationale:** Once the window host is stable, replace the AppKit NSTableView/NSButton/NSLayoutConstraint content with the SwiftUI Form. Build `SettingsViewModel` first (pure Swift, no UI, unit-testable independently), then `SettingsView`. Each Form section can be validated in isolation using Xcode previews.

**Delivers:** Full SwiftUI settings UI with all 7 settings functional and data-persistent. `SettingsWindowController` reduced from 306 to ~60 lines. All NSTableView datasource/delegate code and NSLayoutConstraint blocks deleted.

**Uses:** `Form` + `.formStyle(.grouped)`, `LabeledContent`, `KeyboardShortcuts.Recorder` (SwiftUI), `List` with `TextField` rows for vocabulary, `SMAppService` for launch-at-login, `@Bindable` bindings from `@Observable` ViewModel

**Implements:** `SettingsViewModel.swift` and `SettingsView.swift` — the two new files in `MyWhisper/Settings/`

**Avoids:**
- Pitfall 4 (KeyboardShortcuts first-responder warning) — using `KeyboardShortcuts.Recorder` SwiftUI variant, not `RecorderCocoa`
- Pitfall 5 (NSHostingController sizing conflicts) — `NSWindow(contentViewController:)` constructor auto-sizes to `fittingSize`; set `sizingOptions = [.minSize]` if Spacer expansion or constraint conflicts appear
- Pitfall 6 (`@AppStorage` Toggle desync on macOS 14) — routing all persistence through `SettingsViewModel.didSet`, never using `@AppStorage` directly in the view or on the `@Observable` class
- Anti-pattern 1 (`@AppStorage` in view directly) — centralize all persistence in ViewModel
- Anti-pattern 4 (recreating NSHostingController on every `show()`) — `panel != nil` guard with `makeKeyAndOrderFront` early return

**Build order:**
1. `SettingsViewModel.swift` (new file) — write all 5 state properties with `didSet` bridges, compile and unit-test independently
2. `SettingsView.swift` (new file) — build Form section by section, validate layout with Xcode preview; apply `.padding(.top, -20)` if top padding is excessive
3. Wire vocabulary `List` with inline `TextField` rows and add/remove buttons; if Delete-key keyboard friction is found during QA, fall back to bridging the existing `NSTableView` via `NSViewRepresentable`
4. Run full "Looks Done But Isn't" checklist from PITFALLS.md (all 13 items), including testing on macOS 14 if available

### Phase Ordering Rationale

- Window lifecycle must precede UI content — a broken host window makes UI debugging ambiguous; the same issue might be a window problem or a SwiftUI problem without a known-good baseline
- `SettingsViewModel` precedes `SettingsView` — the view model compiles and is unit-testable without any UI; this validates persistence logic before binding it to controls
- No external dependencies block either phase — all APIs are in the existing stack, no SPM packages to add, no entitlements to change, no services to modify
- Two-phase structure matches the pitfall-to-phase mapping in PITFALLS.md: lifecycle pitfalls belong to Phase 1, UI content pitfalls belong to Phase 2

### Research Flags

Phases likely needing deeper validation during implementation (not blocking research, just watch points):

- **Phase 2 (Vocabulary List — Delete key):** SwiftUI `List` on macOS does not support Delete-key row removal via keyboard shortcut out of the box. Validate on a macOS 14 device during Phase 2. If users rely on keyboard deletion for a text-editing feature (likely), fall back to `NSTableView` via `NSViewRepresentable` — the existing NSTableView implementation is already correct and bridgeable in 20 lines.
- **Phase 2 (NSHostingController sizingOptions):** `NSWindow(contentViewController:)` auto-sizes to `fittingSize`. Whether `Spacer()` expands and whether the window is user-resizable depends on whether the hosting controller's intrinsic size constraints conflict with the window. Check console for "Unable to simultaneously satisfy constraints" on first show; if present, set `hostingController.sizingOptions = [.minSize]`.

Phases with standard patterns (no additional research needed):

- **Phase 1 (Window Lifecycle):** `NSWindow + NSHostingController` pattern is well-documented, already used in this codebase, and validated by primary sources (steipete.me, Apple Developer Docs). Implement directly.
- **Phase 1 (Activation Policy):** Existing `SettingsWindowController` already has the correct `show()`/`windowWillClose` lifecycle. The change is surgical — replace NSPanel with NSWindow. No new activation policy logic required.
- **Phase 2 (Toggle Persistence):** `@Observable` + `didSet` is the confirmed correct pattern. No research needed — it is already specified to the line level in ARCHITECTURE.md.

---

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | All APIs are built-in macOS 14+ or already-pinned SPM packages; Apple official docs confirm all APIs; no new dependencies |
| Features | HIGH | Feature scope is frozen — this is a migration of existing features, not new feature development; all existing services unchanged |
| Architecture | HIGH | Existing codebase was read directly; `NSHostingController` pattern already used in `AppDelegate`; activation policy lifecycle already exists in `SettingsWindowController`; migration is surgical |
| Pitfalls | HIGH | Primary pitfalls verified via steipete.me (2025 primary source), mjtsai.com synthesis, Apple Developer Forums, KeyboardShortcuts GitHub issues; `openSettings` breakage on macOS 26 Tahoe is documented |

**Overall confidence:** HIGH

### Gaps to Address

- **Vocabulary List Delete-key UX:** SwiftUI `List` on macOS does not natively support Delete-key row removal. This may or may not be acceptable. Validate in Phase 2 with real interaction testing — if users rely on keyboard deletion, fall back to the existing `NSTableView` via `NSViewRepresentable`. The existing AppKit implementation is already correct and bridgeable.

- **NSHostingController `sizingOptions` tuning:** The `NSWindow(contentViewController:)` constructor may or may not need explicit `sizingOptions` adjustment. Cannot be fully determined without running the code — treat as a Phase 2 implementation-time decision based on console output and resize behavior.

- **macOS 14 Toggle bounce confirmation:** The `@AppStorage` Toggle desync bug affects macOS 14 specifically. The `@Observable` + `didSet` pattern avoids it by design, but confirmation requires a macOS 14 test device. Acceptable to defer until a regression report surfaces if the team tests primarily on macOS 15+.

---

## Sources

### Primary (HIGH confidence)
- Apple Developer Documentation — `NSHostingController`, `NSHostingView`, `NSWindow.isReleasedWhenClosed`, `Form`, `LabeledContent`, `NSHostingController.sizingOptions`
- `github.com/sindresorhus/KeyboardShortcuts` — confirms `KeyboardShortcuts.Recorder` (SwiftUI) ships alongside `RecorderCocoa` (AppKit); SwiftUI variant is the correct choice inside `NSHostingController`
- Existing source code at `/Users/max/Personal/repos/my-superwhisper/MyWhisper/` — read directly; confirms current NSPanel lifecycle, activation policy pattern, and `showPermissionBlockedWindow` precedent for `NSHostingController` usage

### Secondary (MEDIUM confidence)
- `steipete.me/posts/2025/showing-settings-from-macos-menu-bar-items` — documents `openSettings` broken on macOS 26 Tahoe; `NSWindow + NSHostingController` as recommended alternative for menubar apps
- `mjtsai.com/blog/2025/06/18/showing-settings-from-macos-menu-bar-items` — synthesis of steipete.me findings with additional community commentary
- `artlasovsky.com/fine-tuning-macos-app-activation-behavior` — exact activation policy switching patterns; cross-validated with Apple Developer Forums
- `cindori.com/developer/floating-panel` — NSPanel behavioral differences; `hidesOnDeactivate` as root cause of settings panel closure
- `nilcoalescing.com/blog/LaunchAtLoginSetting/` — `SMAppService` + SwiftUI Toggle pattern with error revert
- Apple Developer Forums — `@Observable` + `@AppStorage` incompatibility confirmed; `.windowStyle(.plain)` breaks `canBecomeKeyWindow`
- `github.com/sindresorhus/KeyboardShortcuts` issue #127 — first-responder warning fix in SwiftUI context; confirms SwiftUI `Recorder` as the solution
- `github.com/sindresorhus/Settings` issue #117 — `@AppStorage` + Toggle UI render bug on macOS 14
- `github.com/orchetect/SettingsAccess` — documents `openSettings` workaround patterns; confirms the complexity that makes direct `NSWindow` preferable

### Tertiary (LOW-MEDIUM confidence)
- WebSearch + community sources — `.formStyle(.grouped)` top-padding quirk (`.padding(.top, -20)` workaround); `List` Delete-key limitation on macOS; `LabeledContent` two-column alignment details
- `philz.blog/nspanel-nonactivating-style-mask-flag/` — NSPanel behavioral edge cases; supports NSWindow preference for settings

---
*Research completed: 2026-03-24*
*Ready for roadmap: yes*
