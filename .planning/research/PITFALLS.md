# Pitfalls Research

**Domain:** macOS menubar app — v1.3 Settings UX: AppKit NSPanel → SwiftUI migration
**Researched:** 2026-03-24
**Confidence:** HIGH (activation policy pitfalls verified via steipete.me primary source + mjtsai.com synthesis + SettingsAccess library documentation), HIGH (NSHostingController sizing verified via Apple Developer Documentation + mjtsai.com), MEDIUM (KeyboardShortcuts interop verified via GitHub issue #127 + library source), MEDIUM (data binding pitfalls verified via sindresorhus/Settings issue #117 + Apple Developer Forums)

---

## Critical Pitfalls

### Pitfall 1: SettingsLink and openSettings Do Not Work From a .accessory App Without Activation Policy Juggling

**What goes wrong:**
Calling SwiftUI's `openSettings` environment action (or placing `SettingsLink` in a `MenuBarExtra`) in an app using `.accessory` activation policy opens the settings window but it appears behind other windows, is non-interactive, and does not take keyboard focus. On second click ("settings already open"), the window does not come to front. The call succeeds silently with no error. As of macOS 14, Apple also removed the legacy `NSApp.sendAction(#selector(NSApplication.showSettingsWindow:), to: nil, from: nil)` path entirely.

**Why it happens:**
Menu bar apps run with `NSApplication.ActivationPolicy.accessory`. macOS refuses to bring windows to the foreground for background utilities without an active dock icon. The SwiftUI `openSettings` action requires an initialized SwiftUI render tree — in apps using `@NSApplicationDelegateAdaptor` with no `WindowGroup`, this render tree may not exist at all when the action fires from the menu delegate (AppKit), leaving no valid execution context.

**How to avoid:**
Use a two-step activation dance before opening settings:
1. Switch activation policy to `.regular` to temporarily acquire a dock icon: `NSApp.setActivationPolicy(.regular)`.
2. Call `NSApp.activate(ignoringOtherApps: true)`.
3. Open settings via `NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:")!)` — or better, use the `openSettings` environment action injected into a 1×1 off-screen hidden SwiftUI window that is always resident. **Scene declaration order matters**: the hidden window scene MUST be declared before the `Settings` scene in the `App` body, otherwise the environment variable does not propagate.
4. Observe `NSWindow` notifications for `NSWindow.didBecomeKeyNotification` on the settings window; when settings closes, restore `.accessory` policy and call `NSApp.hide(nil)` to prevent the dock icon from lingering.

Note: The `openSettings` environment action works on macOS 15 (Sequoia) but is broken again on macOS 26 (Tahoe). Plan for this instability and keep the AppKit fallback path.

**Warning signs:**
- Settings window opens but immediately falls behind the frontmost app.
- Second "Open Settings" click does nothing visible.
- Console shows no error — the failure is completely silent.
- `SettingsLink` placed inside a `menu`-based `MenuBarExtra` triggers no action at all.

**Phase to address:**
Phase 1 of v1.3 (settings window lifecycle). Must be solved before any SwiftUI settings UI work — the window presentation mechanism is the foundation.

---

### Pitfall 2: Activation Policy Transition Leaks Dock Icon or Steals Focus

**What goes wrong:**
After switching to `.regular` to show settings and then back to `.accessory` when settings closes, the dock icon persists, the app remains active and appears in the app switcher, or the app steals focus from whatever the user was typing in when they opened settings. These side effects make the app feel broken and intrusive.

**Why it happens:**
The activation policy switch happens synchronously but the dock icon and "active app" state are managed asynchronously by the window server. If the settings window takes more than a few milliseconds to present after the policy switch, the race condition window is large enough for the dock to register the app. Similarly, calling `NSApp.activate(ignoringOtherApps: true)` is a blunt instrument — it forcibly takes focus regardless of what the user was doing.

**How to avoid:**
1. Set `.prohibited` in `applicationWillFinishLaunching` to prevent any focus steal at startup.
2. After settings closes (via `windowWillClose` delegate or `NSWindow.willCloseNotification`): call `NSApp.setActivationPolicy(.accessory)` then `NSApp.hide(nil)` in sequence. The explicit `hide(nil)` is required — policy switch alone does not return focus to the previously active app.
3. Wrap the `.regular` period tightly: switch to `.regular`, open settings, switch back only after `windowWillClose` fires — not on a timer.
4. Do not call `NSApp.activate` if settings is already the key window (check `NSApp.keyWindow?.identifier` before activating).

**Warning signs:**
- Dock icon persists after closing settings.
- App appears in Command-Tab switcher when it should not.
- The text editor the user was typing in loses focus permanently after opening settings.
- `NSApp.activationPolicy()` still returns `.regular` after settings closes.

**Phase to address:**
Phase 1 of v1.3 (settings window lifecycle). Address as part of the same work as Pitfall 1.

---

### Pitfall 3: NSHostingController Window Does Not Become Key (Keyboard Input Dead)

**What goes wrong:**
A settings window backed by `NSHostingController` presents visually but keyboard input does not work. `TextField` controls show the cursor but typing has no effect. The `KeyboardShortcuts.Recorder` view never enters recording mode when clicked. `Tab` to navigate between fields does nothing.

**Why it happens:**
Two causes: (a) The window is not the key window — `canBecomeKeyWindow` returns `false` for certain window styles, particularly when `.windowStyle(.plain)` or certain `NSPanel` configurations are used. Console shows: `"-[NSWindow makeKeyWindow] called on SwiftUI.AppKitWindow which returned NO from -[NSWindow canBecomeKeyWindow]"`. (b) The app's activation policy is still `.accessory` when the window is shown, so macOS does not route keyboard events to it.

**How to avoid:**
1. If using a custom `NSWindow` subclass to host the SwiftUI view, override `canBecomeKey` to return `true`.
2. If using the SwiftUI `Settings` scene (recommended), avoid `.windowStyle(.plain)` on the settings scene — it breaks `canBecomeKeyWindow`.
3. Ensure `NSApp.setActivationPolicy(.regular)` and `NSApp.activate(ignoringOtherApps: true)` have completed before calling `makeKeyAndOrderFront(nil)` on the window. Call `makeKeyAndOrderFront` after a `DispatchQueue.main.async` yield to allow the activation policy change to take effect.

**Warning signs:**
- Clicking into a `TextField` in settings shows cursor but typing does nothing.
- `KeyboardShortcuts.Recorder` never activates on click.
- Console prints `canBecomeKeyWindow` returning NO.
- The window title bar is grayed out (inactive color) even when it appears to be the frontmost window.

**Phase to address:**
Phase 1 of v1.3 (settings window lifecycle) — must be caught during initial window presentation work, before building settings UI content.

---

### Pitfall 4: KeyboardShortcuts.Recorder First Responder Warning in SwiftUI Context

**What goes wrong:**
When `KeyboardShortcuts.Recorder` (the SwiftUI wrapper around `RecorderCocoa`) is placed inside an `NSHostingController`-backed settings window, Xcode console emits: `"Setting <RecorderCocoa> as the first responder for window, but it is in a different window ((null))! This would eventually crash when the view is freed."` In older versions this was a crash; in newer versions of the library it is a warning that can still cause the recorder to be non-functional (clicking it does nothing).

**Why it happens:**
The `RecorderCocoa` NSView attempts to become first responder in a window context that doesn't fully exist at the time of initialization — this occurs when SwiftUI's view lifecycle creates the AppKit backing view before the `NSHostingController`'s window has been fully configured and made key. This is a known AppKit/SwiftUI boundary issue at view initialization time.

**How to avoid:**
1. Use the latest version of `KeyboardShortcuts` — this was fixed in commit `92af660` ("Fix first responder warning in SwiftUI contexts"). Pin the package to at least that version.
2. Use `KeyboardShortcuts.Recorder` (SwiftUI native) instead of `KeyboardShortcuts.RecorderCocoa` (AppKit) in the SwiftUI settings view. The SwiftUI variant handles the responder chain correctly within `NSHostingController`.
3. Do not attempt to call `makeFirstResponder` on a `RecorderCocoa` instance from outside SwiftUI — let SwiftUI manage focus via `.focused()` modifier.

**Warning signs:**
- The "different window" warning in Xcode console on settings open.
- Clicking the recorder control has no visual response.
- The recorder activates only after clicking somewhere else first (focus needs to land in the window, then on the recorder).

**Phase to address:**
Phase 2 of v1.3 (settings UI content) — specifically the hotkey configuration row.

---

### Pitfall 5: NSHostingController Sizing Constraints Conflict With Window Auto-Resize

**What goes wrong:**
The settings window either (a) has the wrong initial size and cannot be resized by the user, (b) has AutoLayout constraint conflicts logged to console during window display, or (c) SwiftUI views with `Spacer()` or `.frame(maxWidth: .infinity)` do not expand to fill the available window width.

**Why it happens:**
`NSHostingController` by default applies three constraint sets to its view: minimum size, intrinsic content size, and maximum size (`sizingOptions` defaults to `[.minSize, .intrinsicContentSize, .maxSize]`). The `.intrinsicContentSize` constraint probes the SwiftUI view hierarchy once and pins the window to that measured size. This prevents `Spacer` from expanding and can cause the window to refuse user resizing. Additionally, when the `NSHostingController`'s view is not the direct content view of the window but is embedded in an Auto Layout container, the three constraint sets compete with the container's own constraints.

**How to avoid:**
1. Use the SwiftUI `Settings` scene directly with a `TabView` or `Form` — SwiftUI manages the hosting internally and avoids manual `NSHostingController` setup entirely.
2. If using `NSHostingController` directly: set `sizingOptions = [.minSize]` to prevent intrinsic size pinning. The window can then grow freely via Auto Layout.
3. Set the `NSHostingController`'s view as the direct `contentView` of the `NSWindow` — do not embed it inside another view with its own size constraints.
4. Use `.fixedSize()` sparingly in the SwiftUI view — it forces the intrinsic content size to propagate upward and will fight the window's resizability.

**Warning signs:**
- Console: "Unable to simultaneously satisfy constraints" on settings window show.
- Window opens at a tiny size and cannot be dragged to resize.
- `Spacer()` between two controls has zero width/height.
- Settings window ignores `.frame(minWidth:)` declared in SwiftUI.

**Phase to address:**
Phase 2 of v1.3 (settings UI content) — verify layout sizing immediately after building the first Form/GroupBox section.

---

### Pitfall 6: @AppStorage Toggle Does Not Update UI (macOS 14 Bug)

**What goes wrong:**
A `Toggle` bound to `@AppStorage` in a settings `Form` or `GroupBox` visually snaps back to its previous position when tapped, even though the underlying `UserDefaults` value has been updated correctly. The UI and data are out of sync after the first interaction. This is particularly visible in the "Maximizar volumen al grabar" and "Pause Playback" toggles.

**Why it happens:**
This is a confirmed bug in macOS 14 / Xcode 15 SDK, affecting `@AppStorage` inside `AnyView` erasure contexts (which SwiftUI's `Form` and certain container views use internally). The fix shipped in macOS 15.1. The root cause is SwiftUI's view invalidation not propagating through the `AnyView` boundary when an `@AppStorage` property changes.

**How to avoid:**
1. Test on macOS 15.1+ first to establish correct behavior as baseline.
2. For macOS 14 support: wrap `@AppStorage`-backed toggles in an `@Observable` class with manual getter/setter that reads/writes `UserDefaults` directly. This bypasses the broken SwiftUI observation path through `AnyView`.
3. Alternatively, use `@State` locally and write to `UserDefaults` manually in `.onChange(of:)`. This is verbose but reliable across all macOS versions.
4. Do not use `@AppStorage` directly as the binding source for `Toggle` if you must support macOS 14 — go through an `@Observable` intermediary.

**Warning signs:**
- Toggle "bounces back" visually on first tap.
- Reopening settings shows the toggle in the correct (updated) state — confirming the data was saved but the live view is stale.
- Bug reproduces consistently on macOS 14.x but not on macOS 15.1+.

**Phase to address:**
Phase 2 of v1.3 (settings UI content) — discovered immediately when building any toggle. Must be verified on macOS 14 if that is a target.

---

### Pitfall 7: Settings Window Does Not Become Persistent (Closes on Focus Loss)

**What goes wrong:**
The new SwiftUI settings window closes when the user clicks outside it — the same behavior as the current `NSPanel`. The explicit v1.3 requirement is that settings stays open until explicit close. Using `NSPanel.becomesKeyOnlyIfNeeded` or default `NSWindow` behavior does not achieve this.

**Why it happens:**
SwiftUI's `Settings` scene creates an `NSWindow` (not `NSPanel`) with `styleMask` including `.closable`, `.titled`, `.resizable`. The window should persist by default IF the app is active. The problem is the app returns to `.accessory` policy after settings opens, making macOS treat the window as belonging to a background process and hiding it when the user activates another app.

**How to avoid:**
Two strategies depending on the desired UX:
- **Option A (recommended for this app):** Keep the window's `NSWindowController` strongly retained (not as a local `var`). Store it on `AppDelegate`. When the user activates another app, the window stays open because it is owned by a retained controller, not dismissed by SwiftUI's scene management.
- **Option B:** Use `NSPanel` with `styleMask: [.nonactivatingPanel, .titled, .closable, .resizable]`. Non-activating panels remain visible when the app is background. However, they do not receive keyboard events without the activation dance from Pitfall 1.
- In both cases: implement `windowShouldClose(_:)` in `NSWindowDelegate` to intercept the close button and update app state (e.g., restore `.accessory` policy, hide dock icon if it was shown).

**Warning signs:**
- Settings window disappears when user clicks on a text editor.
- The window close delegate method is not being called — the window is being freed directly.
- Settings is opening as a floating panel but not as a persistent window.

**Phase to address:**
Phase 1 of v1.3 (settings window lifecycle) — this is a core v1.3 requirement and must be designed into the window management architecture from the start.

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Use `SettingsLink` directly in `MenuBarExtra` without activation dance | Simplest code | Silently does nothing in menu-based `MenuBarExtra`; window behind other apps in window-based variant | Never — always add activation policy handling |
| Wrap `RecorderCocoa` instead of using `KeyboardShortcuts.Recorder` | Reuse existing AppKit view | First-responder warning; may not receive keyboard in SwiftUI window context | Never in new SwiftUI settings — use SwiftUI `Recorder` |
| Use `@AppStorage` directly on `Toggle` without `@Observable` intermediary | Shortest code | Toggle UI desync on macOS 14; hard to debug | Only if macOS 15.1+ is minimum deployment target |
| Keep `NSHostingController` default `sizingOptions` (all three) | No extra code | Window locked to intrinsic size; `Spacer()` does not work; constraint conflicts | Never for settings windows that need flexible layout |
| Set `activationPolicy(.accessory)` immediately after opening settings (no delegate) | Simpler flow | Dock icon persists; app stays in app switcher; keyboard events broken | Never — always use `windowWillClose` notification to time the policy restore |
| Skip `NSApp.hide(nil)` after restoring `.accessory` | Slightly less code | App stays "active" after settings closes; steals focus from foreground app | Never — `hide(nil)` is required to complete the transition |

---

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| `openSettings` environment action | Call it from AppKit `NSMenuItem` action handler directly | Action requires a live SwiftUI render context; inject a hidden 1×1 `NSHostingController` window with the environment action captured, dispatch through NotificationCenter from AppKit |
| `KeyboardShortcuts.Recorder` in SwiftUI settings | Use `RecorderCocoa` wrapped in `NSViewRepresentable` | Use `KeyboardShortcuts.Recorder` (SwiftUI) directly — it handles the responder chain correctly within `NSHostingController` |
| Activation policy after settings close | Restore `.regular` → `.accessory` on a timer | Restore on `windowWillClose` delegate callback — timer causes race conditions (window may not be closed yet) |
| SwiftUI `Picker` for mic selection | Bind to `selectedDeviceID` (an `AudioDeviceID` which is `UInt32`) | `Picker` requires `Hashable` selection value — `UInt32` is hashable but mic device objects need a stable ID; bind to the full device ID and resolve at recording time |
| `NSHostingController` as window content | Add `NSHostingController.view` to an `NSView` container | Set `NSHostingController.view` as the direct `contentViewController`'s view, or use `NSWindow(contentViewController:)` constructor — do not embed in intermediate containers |
| Scene declaration order | `Settings {}` before hidden helper window in `App.body` | Hidden window scene MUST come before `Settings {}` for the `openSettings` environment action to have a valid context |

---

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| Re-creating `NSHostingController` every time settings opens | Memory growth; short lag on every open; SwiftUI state resets | Retain `NSHostingController` on `AppDelegate` and reuse — call `makeKeyAndOrderFront` on the existing window | Every settings open cycle |
| Storing `[AVCaptureDevice]` in SwiftUI `@State` for mic picker | Array is re-fetched on every view redraw; `AVCaptureDevice` query is not cheap | Fetch device list once on settings open and store in a stable `@Observable` model — not in `@State` | On any state change that triggers re-render of the mic picker row |
| Building vocabulary list as `ForEach` over `UserDefaults` array directly | `UserDefaults.array(forKey:)` called on every render pass | Model the vocabulary list in an `@Observable` class; update the array in the class, not in `UserDefaults` on every keystroke | Any settings interaction that triggers re-render |

---

## UX Pitfalls

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| Settings window position not persisted | Window always opens at the same (often center-screen) position; user cannot place it where convenient | Use `NSWindow.setFrameAutosaveName("settings")` — AppKit then saves and restores position automatically |
| Settings window opens behind the menubar on small screens | User cannot see the settings window; appears as if nothing happened | Set `window.center()` as fallback position on first show only; prefer user's saved position on subsequent shows |
| Activation policy switch makes dock icon flash briefly | Jarring visual artifact on every settings open | Switch to `.regular` and immediately back is noticeable; consider accepting the dock icon while settings is open as the intentional state |
| macOS 14 Toggle bounce causes user to double-tap | Users think the toggle didn't register and tap again, toggling back | Use `@Observable` intermediary (see Pitfall 6) to prevent the bounce |
| RecorderCocoa does not show "type shortcut" affordance on first click | User clicks the recorder, nothing happens visually, clicks again | The first-responder issue from Pitfall 4 is the cause — fixing that makes the recorder immediately responsive |

---

## "Looks Done But Isn't" Checklist

- [ ] **Settings window persistence:** Click outside settings window — window stays open (does not close on deactivation)
- [ ] **Settings window focus:** Click a `TextField` inside settings — typing produces characters (keyboard is routed to the window)
- [ ] **Settings second open:** Close settings, reopen via menu — window appears in front, not behind other apps
- [ ] **Settings already open:** Open settings, click somewhere else, click "Open Settings" again — window comes to front without creating a duplicate
- [ ] **Hotkey recorder:** Click `KeyboardShortcuts.Recorder` in settings — immediately enters "waiting for shortcut" state with no warning in console
- [ ] **Toggle persistence (macOS 14):** Tap "Maximizar volumen" toggle — visually stays in new state (does not bounce back)
- [ ] **Toggle persistence (macOS 14):** Tap "Pause Playback" toggle — same as above
- [ ] **Mic picker:** Select a different mic from Picker — `UserDefaults` saves the new selection; re-open settings shows selected value
- [ ] **Dock icon restore:** Close settings — dock icon disappears, app is no longer in app switcher
- [ ] **Focus steal on open:** Open settings — the app the user was typing in does not lose focus permanently
- [ ] **Window position:** Move settings window, close, reopen — window appears at the last user-set position
- [ ] **Constraint conflicts:** Open settings — no "Unable to simultaneously satisfy constraints" in console
- [ ] **Activation policy after close:** Close settings — `NSApp.activationPolicy()` returns `.accessory`

---

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| Settings window not receiving keyboard input | MEDIUM | Add `canBecomeKey` override to window subclass; add `NSApp.activate` before `makeKeyAndOrderFront` |
| Dock icon persists after settings close | LOW | Add `NSApp.hide(nil)` in `windowWillClose` delegate handler |
| Toggle UI desync (macOS 14) | LOW | Wrap `@AppStorage` in `@Observable` class with manual `UserDefaults` read/write |
| `openSettings` does nothing (no SwiftUI context) | HIGH | Add hidden 1×1 resident `NSHostingController` window; rearchitect menu action to dispatch via `NotificationCenter` |
| Window closes on background click | MEDIUM | Switch from `NSWindow` to `NSPanel` with `.nonactivatingPanel` mask, or retain window controller strongly on `AppDelegate` |
| Scene declaration order breaks `openSettings` | LOW | Move hidden helper window scene above `Settings {}` in `App.body` |

---

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| `openSettings` silent failure / activation dance | v1.3 Phase 1: Window Lifecycle | Settings window opens in front, receives keyboard, on first and second menu click |
| Activation policy leaks dock icon / steals focus | v1.3 Phase 1: Window Lifecycle | After closing settings: dock icon gone, previous app retains focus |
| Window not becoming key (keyboard dead) | v1.3 Phase 1: Window Lifecycle | Type in `TextField` immediately after settings opens |
| Settings closes on focus loss | v1.3 Phase 1: Window Lifecycle | Click outside settings — window stays open |
| `KeyboardShortcuts.Recorder` first-responder warning | v1.3 Phase 2: Settings UI Content | Click recorder on first open — no console warning, immediate response |
| `NSHostingController` sizing constraints | v1.3 Phase 2: Settings UI Content | No constraint conflicts in console; `Spacer()` expands; window is resizable |
| `@AppStorage` Toggle UI desync (macOS 14) | v1.3 Phase 2: Settings UI Content | Toggle tested on macOS 14.x device — no visual bounce |
| Window position not persisted | v1.3 Phase 2: Settings UI Content | Move window, reopen — appears at last position |

---

## Sources

- [Showing Settings from macOS Menu Bar Items: A 5-Hour Journey — Peter Steinberger (2025)](https://steipete.me/posts/2025/showing-settings-from-macos-menu-bar-items)
- [Michael Tsai — Showing Settings From macOS Menu Bar Items (2025 synthesis)](https://mjtsai.com/blog/2025/06/18/showing-settings-from-macos-menu-bar-items/)
- [Fine-Tuning macOS App Activation Behavior — Art Lasovsky](https://artlasovsky.com/fine-tuning-macos-app-activation-behavior)
- [orchetect/SettingsAccess — Better SwiftUI Settings Scene Access on macOS](https://github.com/orchetect/SettingsAccess)
- [KeyboardShortcuts Issue #127 — Warning message in Xcode output pane (first-responder fix)](https://github.com/sindresorhus/KeyboardShortcuts/issues/127)
- [sindresorhus/Settings Issue #117 — AppStorage + Toggle UI render bug](https://github.com/sindresorhus/Settings/issues/117)
- [How NSHostingView Determines Its Sizing — Michael Tsai (2023)](https://mjtsai.com/blog/2023/08/03/how-nshostingview-determines-its-sizing/)
- [NSHostingController sizingOptions — Apple Developer Documentation](https://developer.apple.com/documentation/swiftui/nshostingcontroller/sizingoptions)
- [Use SwiftUI with AppKit — WWDC22 Session 10075](https://developer.apple.com/videos/play/wwdc2022/10075/)
- [SwiftUI for Mac 2024 — TrozWare (windowStyle .plain canBecomeKey bug)](https://troz.net/post/2024/swiftui-mac-2024/)
- [How to Manage Settings in macOS Menu Bar Apps with SwiftUI — DEV Community](https://dev.to/generatecodedev/how-to-manage-settings-in-macos-menu-bar-apps-with-swiftui-45f4)

---

## Appendix: Pre-existing Pitfalls (v1.0–v1.2, Still Applicable)

The following pitfalls from prior milestones remain valid and are not duplicated here. See archived PITFALLS.md versions for full detail.

- CoreAudio volume property not settable on all devices — v1.2 addressed
- Volume not restored on all exit paths — v1.2 addressed
- Haiku adds hallucinated courtesy phrases — v1.2 addressed
- Volume set on wrong device (stale ID) — v1.2 addressed
- MediaRemote private API activation (pause/resume) — v1.1 addressed
- Resuming user-paused media — v1.1 addressed
- AVAudioEngine sample rate mismatch — v1.0 addressed
- Whisper hallucination on silence / VAD gate — v1.0 addressed
- CGEventPost blocked in sandboxed apps (non-sandboxed distribution required) — v1.0 addressed
- Accessibility permission lost on Xcode rebuild — v1.0 addressed
- LLM rewrites text meaning — v1.0 addressed
- Stale microphone device ID from UserDefaults — v1.0 addressed

---
*Pitfalls research for: v1.3 Settings UX — AppKit NSPanel → SwiftUI migration, persistent settings window*
*Researched: 2026-03-24*
