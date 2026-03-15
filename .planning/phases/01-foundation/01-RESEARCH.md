# Phase 1: Foundation - Research

**Researched:** 2026-03-15
**Domain:** Swift/SwiftUI macOS system integration — menubar, global hotkey, paste simulation, permissions
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- Microphone icon in menubar that changes color by state: gray (idle), red (recording), blue (processing), green flash (done → returns to gray)
- "Done" state: icon does NOT flash green — just returns to idle silently ("sin feedback")
- Dropdown menu contains: current status text, configured hotkey display, Settings option, Quit option
- Recording state also shows a floating overlay window with waveform animation near center of screen (in addition to red menubar icon)
- When processing completes and text is pasted, no explicit feedback — text appearing at cursor is sufficient
- Default hotkey: Option+Space (NOT Ctrl+Space — macOS input source conflict)
- Toggle mode: first press starts recording, second press stops and triggers pipeline
- If hotkey pressed during processing state: IGNORED — no action until pipeline completes
- Escape during recording: cancels immediately with a subtle system sound, overlay disappears, icon returns to gray, no text pasted
- Permissions requested on-the-fly: microphone permission when first recording starts, accessibility permission when first paste attempt happens
- If user denies any permission: app shows a blocking screen explaining what the permission is for and how to enable it in System Settings (with a "Open System Settings" button)
- Permission health check on every launch: if previously granted permission is revoked (e.g., after OS update), surface the same blocking screen immediately
- Paste mechanism: set clipboard to transcribed text, then simulate Cmd+V via CGEventPost
- Clipboard is OVERWRITTEN with transcribed text (not preserved/restored) — user can re-paste the text later
- If paste simulation fails (app blocks it): leave text in clipboard + show macOS notification "Texto copiado — pegá con Cmd+V"
- Non-sandboxed app required for CGEventPost — distribute via Developer ID, not Mac App Store

### Claude's Discretion
- Exact overlay window dimensions and positioning
- Waveform animation style (sine wave, frequency bars, etc.)
- System sound choice for cancel action
- Internal state machine design (FSM states and transitions)
- Code signing and entitlements configuration

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| MAC-01 | App runs as a menubar application with status icon showing current state (idle/recording/processing/done) | NSStatusItem + non-template colored images per state |
| MAC-02 | App prompts for Accessibility and Microphone permissions on first launch with clear explanations | AXIsProcessTrustedWithOptions + AVCaptureDevice.requestAccess, on-the-fly pattern |
| MAC-03 | App checks permission health on every launch (permissions can reset after OS updates) | AXIsProcessTrusted() + AVCaptureDevice.authorizationStatus called in AppDelegate.applicationDidFinishLaunching |
| MAC-06 | App requires macOS 14+ on Apple Silicon (M1 or later) | MACOSX_DEPLOYMENT_TARGET = 14.0, MinimumOSVersion in Info.plist |
| PRV-01 | Audio is transcribed 100% locally — raw audio never leaves the machine | Phase 1 discards audio; architecture constraint enforced by not wiring any network calls in AudioRecorder |
| PRV-02 | Only transcribed text (not audio) is sent to Anthropic's Haiku API for cleanup | Phase 1: no Haiku call yet; architecture boundary established in AppCoordinator |
| REC-01 | User can press a global hotkey to start recording from any application | HotKey v0.2.1 with Key.space + NSEventModifierFlags.option |
| REC-04 | User can press Escape to cancel recording without pasting any text | NSEvent.addGlobalMonitorForEvents for Escape key during recording state only |
| OUT-01 | Clean text is automatically pasted at the current cursor position (simulates Cmd+V) | CGEventPost with CGEventCreateKeyboardEvent(nil, 0x09, true/false) + .maskCommand |
| OUT-02 | Auto-paste works system-wide in any macOS application (Slack, VS Code, browsers, Notes, etc.) | NSPasteboard.general.setString + CGEventPost to cgSessionEventTap |
</phase_requirements>

---

## Summary

Phase 1 establishes all macOS system integration without any ML — the foundation every subsequent phase builds on. This is a greenfield Swift/SwiftUI project. The phase covers four distinct technical domains: (1) menubar status icon with colored state images, (2) global hotkey registration via HotKey library, (3) clipboard-write + CGEventPost paste simulation, and (4) Accessibility and Microphone permission management with on-the-fly requesting and health checking on every launch.

All four domains interact with macOS TCC (Transparency, Consent, and Control) in ways that make code signing critical from day one. The most important architectural constraint for this phase is the FSM-based AppCoordinator: all state transitions must funnel through a single @MainActor class so that the menubar icon, overlay window, and hotkey behavior stay in sync. Audio is captured but discarded in this phase — a stub AudioRecorder satisfies the recording state without any ML.

The most dangerous pitfall is the code signing trap: Accessibility permission in TCC is tied to the binary's code signature. Every unsigned Xcode rebuild creates a new identity and silently revokes permissions. Setting up Developer ID signing from the very first build prevents mid-development breakage. The second most dangerous pitfall is hotkey event delivery: the HotKey library's Carbon callback fires on a non-main thread and must dispatch to MainActor via `Task { @MainActor in ... }` — calling coordinator methods synchronously from the callback can crash the system event queue.

**Primary recommendation:** Use NSStatusItem (not SwiftUI MenuBarExtra) for full control over icon images and color, NSPanel for the overlay window, HotKey v0.2.1 for global shortcut registration, and an explicit FSM enum for all state management. Set up Developer ID code signing before writing any code that touches Accessibility APIs.

---

## Standard Stack

### Core

| Library / Framework | Version | Purpose | Why Standard |
|--------------------|---------|---------|--------------|
| Swift / SwiftUI | Swift 5.10+, macOS 14+ | App shell, menubar UI, overlay window | Native macOS APIs — lowest memory overhead, required for all Accessibility/AVFoundation permission flows |
| HotKey (soffes) | 0.2.1 | Global hotkey registration (Option+Space) | Thin Swift wrapper over Carbon EventHotKey APIs — the only non-deprecated way to register system-wide shortcuts. No Input Monitoring permission required. Used by AudioWhisper in production. |
| AppKit NSStatusItem | System | Menubar icon with colored state images | Full control over image per state. SwiftUI MenuBarExtra lacks 1st-party API to set/change the icon image dynamically or control presentation state. NSStatusItem is the production-grade approach. |
| AppKit NSPanel | System | Floating overlay window during recording | NSPanel subclass floats above all windows. Simpler than NSWindow for transient UI. Zero extra dependencies. |
| AVFoundation | System | Microphone permission request + stub capture | AVCaptureDevice.requestAccess(for: .audio) is the correct API for on-the-fly permission requesting. |
| ApplicationServices (AXIsProcessTrusted) | System | Accessibility permission check | AXIsProcessTrustedWithOptions prompts or redirects user; AXIsProcessTrusted() is the health-check call. |
| CGEventPost / CGEventCreateKeyboardEvent | System | Simulate Cmd+V to paste text | Standard paste simulation approach for non-sandboxed macOS apps. Requires Accessibility permission. |
| NSPasteboard | System | Write transcribed text to clipboard | Write text, then trigger Cmd+V. In this phase, used for stub paste with a hardcoded test string. |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| KeyboardShortcuts (sindresorhus) | latest | User-configurable hotkey UI with SwiftUI recorder widget | Use in Phase 4 (Settings UI) when user needs to remap the hotkey. Heavier than HotKey but has a visual key-recorder component. Not needed in Phase 1. |
| Swift Testing | Xcode 16+ | Modern test framework alongside XCTest | Prefer for new unit tests on Swift 6 actor-isolated types. XCTest works fine for Phase 1. |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| NSStatusItem | SwiftUI MenuBarExtra | MenuBarExtra lacks API to change icon image dynamically at runtime (confirmed limitation); NSStatusItem has full control via `button.image`. |
| HotKey (Carbon EventHotKey) | CGEventTap for hotkey | CGEventTap requires Accessibility permission before the app can register the hotkey. Carbon EventHotKey (wrapped by HotKey) does NOT require Input Monitoring or Accessibility permission. Use HotKey. |
| NSPanel floating overlay | SwiftUI WindowGroup scene | WindowGroup windows appear in the Dock and Window menu; NSPanel can be .nonactivatingPanel so focus does not switch away from the user's active app. |
| CGEventPost Cmd+V | AXUIElement text insertion | AXUIElement insertion works only in apps that correctly expose accessibility text fields — fails in terminals, games, many Electron apps. CGEventPost has near-universal compatibility. |

**Installation:**
```bash
# Package.swift — add to dependencies array:
.package(url: "https://github.com/soffes/HotKey", from: "0.2.1")

# Target dependencies:
.product(name: "HotKey", package: "HotKey")
```

---

## Architecture Patterns

### Recommended Project Structure
```
MyWhisper/
├── App/
│   ├── MyWhisperApp.swift          # @main, App scene with MenuBarExtra or NSApplicationDelegate
│   └── AppDelegate.swift           # applicationDidFinishLaunching: permission health check, setup
│
├── Coordinator/
│   ├── AppCoordinator.swift        # @MainActor @Observable FSM — owns all state transitions
│   └── AppState.swift              # enum AppState: idle | recording | processing | error(String)
│
├── System/
│   ├── HotkeyMonitor.swift         # HotKey v0.2.1 wrapper, dispatches to AppCoordinator
│   ├── EscapeMonitor.swift         # NSEvent.addGlobalMonitorForEvents for Escape during recording
│   ├── TextInjector.swift          # NSPasteboard write + CGEventPost Cmd+V simulation
│   └── PermissionsManager.swift    # Checks Accessibility + Microphone; surfaces blocking UI
│
├── UI/
│   ├── MenubarController.swift     # NSStatusItem setup, icon state updates
│   ├── OverlayWindowController.swift # NSPanel floating overlay during recording
│   ├── OverlayView.swift           # SwiftUI view: waveform animation placeholder
│   ├── PermissionBlockedView.swift # SwiftUI: blocking screen with "Open System Settings" button
│   └── StatusMenuView.swift        # NSMenu or SwiftUI view for the dropdown menu
│
└── Audio/
    └── AudioRecorder.swift         # Stub: starts/stops AVAudioEngine, discards audio (no ML yet)
```

### Pattern 1: FSM AppCoordinator
**What:** A single @MainActor @Observable class owns the app's state as an explicit enum. All transitions go through one method: `handleHotkey()`. Other actors/monitors only report events — they never transition state directly.
**When to use:** The FSM is the only safe pattern when multiple async operations (recording, future STT, future cleanup, paste) must run in strict sequence. It prevents race conditions between hotkey presses and makes the "hotkey ignored during processing" requirement trivial to implement.

```swift
// Source: ARCHITECTURE.md + Pattern 1
@MainActor
@Observable
final class AppCoordinator {
    var state: AppState = .idle

    func handleHotkey() async {
        switch state {
        case .idle:
            state = .recording
            await audioRecorder.startStub()    // Phase 1: stub, discards audio
            overlayController.show()
        case .recording:
            overlayController.hide()
            state = .processing
            // Phase 1: no STT — paste a test string directly
            await textInjector.inject("Texto de prueba")
            state = .idle
        case .processing:
            break  // IGNORE hotkey during processing — per spec
        case .error:
            state = .idle
        }
    }

    func handleEscape() {
        guard state == .recording else { return }
        audioRecorder.cancelStub()
        overlayController.hide()
        NSSound.beep()    // subtle system sound for cancel
        state = .idle
    }
}
```

### Pattern 2: HotKey Registration
**What:** Create a `HotKey` instance with `.space` key and `.option` modifier. Store it as a property so it remains registered for the app's lifetime. Set `keyDownHandler` to dispatch to `@MainActor`.
**When to use:** This is the only approach for Phase 1. Carbon EventHotKey does not require Accessibility permission and does not conflict with Option+Space being a potential system shortcut (unlike Ctrl+Space).

```swift
// Source: soffes/HotKey README + STACK.md
import HotKey

final class HotkeyMonitor {
    private var hotKey: HotKey?
    private weak var coordinator: AppCoordinator?

    init(coordinator: AppCoordinator) {
        self.coordinator = coordinator
        hotKey = HotKey(key: .space, modifiers: [.option])
        hotKey?.keyDownHandler = { [weak self] in
            Task { @MainActor [weak self] in
                await self?.coordinator?.handleHotkey()
            }
        }
    }
}
```

**Critical:** Store the `HotKey` instance as a property. If it deallocates, the hotkey is automatically unregistered (Carbon EventHotKey lifecycle is tied to the object).

### Pattern 3: NSStatusItem with Colored State Images
**What:** Use non-template NSImage instances (one per state) to show colored microphone icons. Call `statusItem.button?.image = stateImage` on MainActor when state changes.
**When to use:** Always for this app. Template images are grayscale-only and adapt to light/dark mode but cannot express red vs. blue vs. gray — the required color states.

```swift
// Source: Apple NSStatusItem docs + WebSearch findings
final class MenubarController {
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

    // Images: create programmatically with SwiftUI/NSImage or from asset catalog
    // isTemplate = false to preserve color
    private let idleImage    = makeIcon(color: .gray)      // gray microphone
    private let recordImage  = makeIcon(color: .red)       // red microphone
    private let processImage = makeIcon(color: .systemBlue)// blue microphone

    func update(state: AppState) {
        switch state {
        case .idle:       statusItem.button?.image = idleImage
        case .recording:  statusItem.button?.image = recordImage
        case .processing: statusItem.button?.image = processImage
        case .error:      statusItem.button?.image = idleImage
        }
    }
}
```

**Note:** Generate images using `NSImage(size:)` + `NSBezierPath` or `SF Symbols` with a tint. SF Symbols support `.withSymbolConfiguration(.init(paletteColors: [color]))` which is the cleanest approach for a microphone icon.

### Pattern 4: CGEventPost Paste Simulation
**What:** Write text to `NSPasteboard.general`, then post a keyDown + keyUp event for key code 0x09 (V) with `.maskCommand`. No clipboard preservation — per spec, clipboard is overwritten.
**When to use:** Always for non-sandboxed paste-anywhere simulation on macOS.

```swift
// Source: ARCHITECTURE.md Pattern 4 + Apple Developer Forums thread/659804
func inject(_ text: String) async {
    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()
    pasteboard.setString(text, forType: .string)

    // Small delay: clipboard write is async to target app
    try? await Task.sleep(for: .milliseconds(150))

    let source = CGEventSource(stateID: .hidSystemState)
    let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true)
    let keyUp   = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
    keyDown?.flags = .maskCommand
    keyUp?.flags   = .maskCommand
    keyDown?.post(tap: .cgSessionEventTap)
    keyUp?.post(tap: .cgSessionEventTap)
}
```

**Failure path:** If paste does not work (e.g., target app blocks synthetic events), detect by checking if the frontmost app has received the event — this is hard to verify directly, so implement the fallback notification path: show a `UNUserNotificationCenter` notification with "Texto copiado — pegá con Cmd+V".

### Pattern 5: Permission Management — On-The-Fly + Health Check
**What:** Two separate flows: (a) health check on every launch using synchronous status APIs; (b) on-the-fly requesting when the user first triggers the action requiring the permission.
**When to use:** Required pattern per spec. Never request all permissions at once on first launch.

```swift
// Source: Apple AVFoundation docs + jano.dev Accessibility permission article (2025)
final class PermissionsManager {

    // Called from AppDelegate.applicationDidFinishLaunching
    func checkAllOnLaunch() -> PermissionStatus {
        let accessibility = AXIsProcessTrusted()
        let mic = AVCaptureDevice.authorizationStatus(for: .audio)
        if !accessibility || mic == .denied || mic == .restricted {
            return .blocked(reason: accessibility ? .microphone : .accessibility)
        }
        return .ok
    }

    // Called when first recording starts
    func requestMicrophone() async -> Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        if status == .authorized { return true }
        if status == .notDetermined {
            return await AVCaptureDevice.requestAccess(for: .audio)
        }
        return false // denied — show blocking screen
    }

    // Called when first paste attempt happens
    func requestAccessibility() -> Bool {
        // AXIsProcessTrustedWithOptions prompts or redirects user to System Settings
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true]
        return AXIsProcessTrustedWithOptions(options)
    }

    // Open System Settings directly to the right pane
    func openSystemSettingsForAccessibility() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    func openSystemSettingsForMicrophone() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")!
        NSWorkspace.shared.open(url)
    }
}
```

### Pattern 6: Floating Overlay NSPanel
**What:** Create an NSPanel with `.nonActivatingPanel` style to show the waveform overlay without stealing focus from the user's active app.
**When to use:** Always for a recording indicator that must appear above all windows without interrupting the user's current context.

```swift
// Source: cindori.com floating panel article + WebSearch 2024-2025 findings
final class OverlayWindowController {
    private var panel: NSPanel?

    func show() {
        let panel = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.level = .floating        // floats above all normal windows
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentView = NSHostingView(rootView: OverlayView())
        panel.center()                 // Claude's discretion: center of screen
        panel.setFrameAutosaveName("")
        panel.makeKeyAndOrderFront(nil)
        self.panel = panel
    }

    func hide() {
        panel?.orderOut(nil)
        panel = nil
    }
}
```

### Anti-Patterns to Avoid
- **Calling AppCoordinator from HotKey Carbon callback synchronously:** The Carbon callback fires on a non-main thread. Always wrap in `Task { @MainActor in ... }`.
- **Using SwiftUI MenuBarExtra for this app:** MenuBarExtra cannot change its icon image dynamically — confirmed limitation. Use NSStatusItem.
- **Requesting all permissions at launch:** Per spec, permissions are requested on-the-fly when the relevant action first runs.
- **Hardcoding sample rate in AudioRecorder stub:** Even the stub must call `inputNode.outputFormat(forBus: 0)` to query the actual hardware rate — sets up Phase 2 correctly.
- **Using NSEvent global monitor for the main hotkey:** NSEvent monitors observe but cannot consume events. The hotkey would also fire in the user's focused app (e.g., triggering autocomplete in an IDE). HotKey (Carbon) consumes the event.
- **Checking permissions only at first launch:** TCC can revoke permissions after OS updates. Check on every `applicationDidFinishLaunching`.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Global hotkey registration | Custom Carbon API wrapper | HotKey v0.2.1 (soffes) | Carbon EventHotKey management is complex; HotKey handles registration, deregistration, modifier flag parsing, and lifecycle correctly in ~300 lines |
| Paste simulation | Custom AXUIElement text insertion | CGEventPost + NSPasteboard | AXUIElement fails in ~30% of real-world apps (terminals, browsers, Electron); CGEventPost has near-universal compatibility |
| System Settings URL for permissions | Custom URL string building | The documented URL scheme `x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility` | URL format changes across OS versions; use the documented path |
| Colored SF Symbol image generation | Custom drawing code | `NSImage(systemSymbolName:accessibilityDescription:)` + `.withSymbolConfiguration(.init(paletteColors:))` | SF Symbols handle all sizes and display densities; Retina, Dark Mode, and accessibility are automatic |

**Key insight:** The system integration layer (Carbon EventHotKey, CGEvent, TCC) has enough edge cases and OS-version-specific behavior that hand-rolling wrappers always misses 2-3 important cases. Use the libraries and APIs that have already been battle-tested in production dictation apps.

---

## Common Pitfalls

### Pitfall 1: Accessibility Permission Revoked on Every Xcode Rebuild
**What goes wrong:** TCC ties Accessibility permission to the app binary's code signature identity. Each Xcode build without a consistent Developer ID signature creates a new identity, silently revoking the previously granted permission. The hotkey stops working mid-development with no error message.
**Why it happens:** Default Xcode debug builds use ad-hoc signing, which generates a different identity per build.
**How to avoid:** Set up Developer ID signing (or at minimum a consistent team signing certificate) from day one, before writing any code that touches Accessibility APIs. In Xcode: Signing & Capabilities → select a consistent Team.
**Warning signs:** Global hotkey stops working after a rebuild; `AXIsProcessTrusted()` returns false unexpectedly.

### Pitfall 2: HotKey Carbon Callback on Non-Main Thread
**What goes wrong:** The HotKey `keyDownHandler` closure fires on the Carbon event thread, not the main thread. Calling any `@MainActor`-isolated method (like updating AppCoordinator.state) directly from the callback causes a runtime crash or data race in Swift concurrency strict mode.
**Why it happens:** Carbon EventHotKey dispatches on its own thread.
**How to avoid:** Always wrap the handler body in `Task { @MainActor in ... }`. Never call coordinator methods directly.
**Warning signs:** Purple Thread Sanitizer warnings, `@MainActor` isolation violations, or crashes in Swift concurrency mode.

### Pitfall 3: CGEventPost Requires Accessibility — App Appears Broken on First Run
**What goes wrong:** On first launch, neither Accessibility nor Microphone permission is granted. The user presses the hotkey, nothing happens, and there is no feedback. The user assumes the app is broken.
**Why it happens:** On-the-fly permission requesting means the first action silently fails before the permission prompt appears.
**How to avoid:** Implement the "on-the-fly" flow correctly: when `state == .recording` and the user presses the hotkey a second time (stop + paste), check `AXIsProcessTrusted()` first. If false, pause, call `AXIsProcessTrustedWithOptions` to prompt, and surface the blocking screen. Only attempt paste after permission is confirmed.
**Warning signs:** No paste happens on first run; no permission dialog appears; Accessibility list in System Settings is empty.

### Pitfall 4: Option+Space May Have Edge Cases on Some Keyboards
**What goes wrong:** On Spanish-layout keyboards, Option+Space may produce a non-breaking space character in some apps, causing unwanted characters to be typed when the hotkey fires (Carbon consumes the event, but timing edge cases exist).
**Why it happens:** Carbon EventHotKey processes at a lower level than character event generation but timing of character event vs. hotkey event dispatch can vary.
**How to avoid:** Use HotKey's Carbon-level registration which intercepts before character generation. Verify during testing with a Spanish keyboard layout active. If issues arise, Option+Shift+Space or Cmd+Shift+R are clean fallbacks without character-generation side effects.
**Warning signs:** Occasional non-breaking spaces appearing in apps after pressing the hotkey.

### Pitfall 5: NSPanel Overlay Captures Focus or Appears Behind Active App
**What goes wrong:** The overlay window either (a) steals focus from the user's current app (breaking their cursor position for the paste), or (b) appears behind full-screen apps or apps using a dedicated Space.
**Why it happens:** Default NSWindow initialization activates the window, stealing focus. Full-screen apps and dedicated Spaces need specific collection behavior settings.
**How to avoid:** Use `styleMask: [.borderless, .nonactivatingPanel]` and `collectionBehavior: [.canJoinAllSpaces, .fullScreenAuxiliary]`. Never call `makeKeyAndOrderFront` — use `orderFront(nil)` instead.
**Warning signs:** Cursor jumps to a different app when recording starts; paste fails because focus moved; overlay invisible during full-screen apps.

### Pitfall 6: Clipboard Paste Race Condition
**What goes wrong:** CGEventPost fires before the target app has received and processed the clipboard write. The previous clipboard content is pasted instead of the transcribed text.
**Why it happens:** `NSPasteboard.setString` is synchronous from the writing app's perspective but the target app reads the clipboard asynchronously. Posting the Cmd+V event immediately after `setString` can arrive before the clipboard update propagates.
**How to avoid:** Add a 150ms delay between `NSPasteboard.setString` and the CGEventPost. This is the established minimum from production dictation apps.
**Warning signs:** Wrong text gets pasted (previous clipboard content); intermittent paste failures under load.

---

## Code Examples

Verified patterns from official sources and production reference implementations:

### App Entry Point — No Dock Icon
```swift
// Source: Apple LSUIElement documentation + nilcoalescing.com tutorial
@main
struct MyWhisperApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // No WindowGroup — menubar only app
        Settings { EmptyView() }  // Required or SwiftUI complains about no scenes
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide dock icon — LSUIElement in Info.plist is the correct approach
        // Also set via: NSApp.setActivationPolicy(.accessory)
        NSApp.setActivationPolicy(.accessory)
        // ... setup coordinator, menubar, hotkey
    }
}
```

**Note:** `LSUIElement = YES` in Info.plist is the recommended approach. `NSApp.setActivationPolicy(.accessory)` is the runtime equivalent and can be used together.

### HotKey Option+Space Registration
```swift
// Source: soffes/HotKey README, v0.2.1
import HotKey

final class HotkeyMonitor {
    private var hotKey: HotKey?

    func register(coordinator: AppCoordinator) {
        hotKey = HotKey(key: .space, modifiers: [.option])
        hotKey?.keyDownHandler = {
            Task { @MainActor in
                await coordinator.handleHotkey()
            }
        }
    }

    func unregister() {
        hotKey = nil   // Deregisters Carbon EventHotKey automatically
    }
}
```

### Escape Key Global Monitor During Recording
```swift
// Source: Apple NSEvent.addGlobalMonitorForEvents documentation
final class EscapeMonitor {
    private var monitor: Any?

    func startMonitoring(onEscape: @escaping @MainActor () -> Void) {
        monitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 {  // kVK_Escape = 53
                Task { @MainActor in onEscape() }
            }
        }
    }

    func stopMonitoring() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }
}
// Activate only while state == .recording; deactivate on stop or cancel
```

**Note:** Escape is monitored using `NSEvent.addGlobalMonitorForEvents` (observation only, does not consume). Since Escape in recording context is an in-app action and the recording state is exclusive, this is fine — Escape in most apps does nothing that conflicts with canceling recording.

### Accessibility Permission with Blocking UI
```swift
// Source: jano.dev Accessibility Permission in macOS (2025)
func checkAndRequestAccessibility(showBlockingUI: @escaping (PermissionReason) -> Void) {
    if AXIsProcessTrusted() { return }

    // Option A: prompt immediately (shows system dialog or redirects to Settings)
    let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true]
    let trusted = AXIsProcessTrustedWithOptions(options)

    if !trusted {
        // Show our own blocking screen with "Open System Settings" button
        showBlockingUI(.accessibility)
    }
}

// URL to open directly in System Settings:
// "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
// "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone"
```

### NSStatusItem Colored Icon Setup
```swift
// Source: Apple NSStatusItem documentation + WebSearch 2024 findings
final class MenubarController {
    let statusItem: NSStatusItem

    init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        update(state: .idle)
    }

    func update(state: AppState) {
        DispatchQueue.main.async { [weak self] in
            self?.statusItem.button?.image = Self.image(for: state)
        }
    }

    private static func image(for state: AppState) -> NSImage? {
        let name = "mic"   // SF Symbol
        let config: NSImage.SymbolConfiguration
        switch state {
        case .idle:
            config = .init(paletteColors: [.secondaryLabelColor])
        case .recording:
            config = .init(paletteColors: [.systemRed])
        case .processing:
            config = .init(paletteColors: [.systemBlue])
        case .error:
            config = .init(paletteColors: [.systemOrange])
        }
        let img = NSImage(systemSymbolName: name, accessibilityDescription: state.description)?
            .withSymbolConfiguration(config)
        img?.isTemplate = false   // MUST be false to preserve color
        return img
    }
}
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| NSEvent.addGlobalMonitorForEvents for hotkeys | Carbon EventHotKey (via HotKey library) | Always been the right approach — NSEvent monitors cannot consume events | Using NSEvent for hotkeys lets the keypress "leak" to the focused app |
| Checking permissions only at first launch | Check on every `applicationDidFinishLaunching` | macOS Sequoia (15.0) accelerated permission reset cadence for some permission types | Required to handle TCC resets after OS updates |
| Clipboard save/restore around paste | Clipboard overwrite (per spec decision) | This app's design choice — user can re-paste | Simpler code, user is informed via clipboard that text is available |
| SwiftUI MenuBarExtra (macOS 13+) | NSStatusItem for dynamic icon control | MenuBarExtra introduced macOS 13, but lacks dynamic icon API | NSStatusItem remains necessary for apps with colored state icons |
| App Sandbox for distribution | Non-sandboxed with Developer ID + hardened runtime + notarization | Always the case for CGEventPost | Mac App Store is not possible; direct download is the distribution model |

**Deprecated/outdated:**
- `NSEvent.addGlobalMonitorForEvents` for hotkeys: Observation-only, does not consume. Use HotKey.
- `CGEventTap` for the hotkey: Requires Accessibility permission before the hotkey even registers. Carbon EventHotKey (HotKey library) does not.
- Ctrl+Space as default hotkey: Conflicts with macOS Input Source switching for bilingual users. Option+Space is the correct default.
- `AXIsProcessTrustedWithOptions` with the prompt option is now more likely to open System Settings directly than to show an in-app dialog on macOS 14+.

---

## Open Questions

1. **Waveform animation complexity**
   - What we know: The overlay view needs a waveform animation while recording is active. Multiple approaches work: sine wave Canvas drawing, frequency bars, or a simple pulsing circle.
   - What's unclear: Phase 1 discards audio (no AVAudioEngine meter data yet), so the animation cannot react to actual audio levels.
   - Recommendation: Implement a CSS-style looping animation (e.g., three animated bars or a pulsing ring) that does not require audio level input. Phase 2 can upgrade it to a live-level waveform once AudioRecorder provides meter data.

2. **Notification permission for the paste-failure fallback**
   - What we know: The spec requires showing a notification "Texto copiado — pegá con Cmd+V" when paste fails.
   - What's unclear: UNUserNotificationCenter requires a separate permission request on macOS. The paste failure path is rare — it may not be worth requesting notification permission upfront.
   - Recommendation: Use `UNUserNotificationCenter.current().requestAuthorization` only when the paste failure is first triggered (lazy request). Alternatively, show an in-app floating toast instead of a system notification, which requires no permission.

3. **Audio stub for recording state**
   - What we know: Phase 1 establishes the recording state but discards audio. AVAudioEngine must be started to actually capture (the phase requirement PRV-01 says audio stays local — no concern about data leaving).
   - What's unclear: Whether the stub should actually start AVAudioEngine (with microphone permission) or just simulate the state change without touching audio hardware.
   - Recommendation: Start AVAudioEngine for real in the stub (no processing, just capture and discard). This (a) validates microphone permission flow, (b) prevents AVAudioEngine initialization surprises in Phase 2, and (c) means the recording state feels authentic (mic LED activates on MacBook).

---

## Validation Architecture

> `workflow.nyquist_validation` is `true` in `.planning/config.json` — section included.

### Test Framework
| Property | Value |
|----------|-------|
| Framework | XCTest (built into Xcode) + Swift Testing (Xcode 16+) |
| Config file | None — Xcode project handles test targets |
| Quick run command | `xcodebuild test -scheme MyWhisper -destination 'platform=macOS' -only-testing:MyWhisperTests/AppCoordinatorTests` |
| Full suite command | `xcodebuild test -scheme MyWhisper -destination 'platform=macOS'` |

**Note:** This is a greenfield project. Test target must be created in Xcode during Wave 0 (project scaffold).

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| MAC-01 | Menubar icon image changes on state transitions | unit | `xcodebuild test ... -only-testing:MyWhisperTests/MenubarControllerTests` | ❌ Wave 0 |
| MAC-02 | Accessibility permission request triggers on first paste | manual-only | N/A — requires TCC interaction | N/A — manual |
| MAC-02 | Microphone permission request triggers on first recording | manual-only | N/A — requires TCC interaction | N/A — manual |
| MAC-03 | Permission health check detects revoked Accessibility on launch | unit | `xcodebuild test ... -only-testing:MyWhisperTests/PermissionsManagerTests/testAccessibilityRevoked` | ❌ Wave 0 |
| MAC-03 | Permission health check detects denied Microphone on launch | unit | `xcodebuild test ... -only-testing:MyWhisperTests/PermissionsManagerTests/testMicrophoneDenied` | ❌ Wave 0 |
| MAC-06 | Minimum deployment target is macOS 14.0 | smoke | Verify `MACOSX_DEPLOYMENT_TARGET = 14.0` in build settings | ❌ Wave 0 |
| REC-01 | Hotkey registration succeeds and fires keyDownHandler | unit | `xcodebuild test ... -only-testing:MyWhisperTests/HotkeyMonitorTests` | ❌ Wave 0 |
| REC-01 | FSM transitions idle → recording on hotkey press | unit | `xcodebuild test ... -only-testing:MyWhisperTests/AppCoordinatorTests/testHotkeyStartsRecording` | ❌ Wave 0 |
| REC-01 | FSM transitions recording → processing on second hotkey press | unit | `xcodebuild test ... -only-testing:MyWhisperTests/AppCoordinatorTests/testHotkeyStopsRecording` | ❌ Wave 0 |
| REC-01 | Hotkey ignored during processing state | unit | `xcodebuild test ... -only-testing:MyWhisperTests/AppCoordinatorTests/testHotkeyIgnoredDuringProcessing` | ❌ Wave 0 |
| REC-04 | Escape during recording cancels and returns to idle | unit | `xcodebuild test ... -only-testing:MyWhisperTests/AppCoordinatorTests/testEscapeCancelsRecording` | ❌ Wave 0 |
| OUT-01 | TextInjector writes correct text to NSPasteboard | unit | `xcodebuild test ... -only-testing:MyWhisperTests/TextInjectorTests/testPasteboardWrite` | ❌ Wave 0 |
| OUT-02 | Paste simulation works in TextEdit | manual-only | N/A — requires running app + TextEdit | N/A — manual |
| PRV-01 | Audio stub discards audio — no network calls | unit | `xcodebuild test ... -only-testing:MyWhisperTests/AudioRecorderTests/testNoNetworkCalls` | ❌ Wave 0 |

**Manual-only justifications:**
- MAC-02: TCC permission dialogs cannot be scripted or mocked in unit tests without special tooling.
- OUT-02: Cross-app event injection requires a running macOS session with a focused target app.

### Sampling Rate
- **Per task commit:** `xcodebuild test -scheme MyWhisper -destination 'platform=macOS' -only-testing:MyWhisperTests/AppCoordinatorTests`
- **Per wave merge:** `xcodebuild test -scheme MyWhisper -destination 'platform=macOS'` (full unit suite)
- **Phase gate:** Full unit suite green + manual verification checklist before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `MyWhisper.xcodeproj` — Xcode project with app target (macOS 14+, no sandbox, Developer ID signing)
- [ ] `MyWhisperTests/` test target added to Xcode project
- [ ] `MyWhisperTests/AppCoordinatorTests.swift` — covers REC-01, REC-04 FSM transitions
- [ ] `MyWhisperTests/MenubarControllerTests.swift` — covers MAC-01 icon state changes
- [ ] `MyWhisperTests/PermissionsManagerTests.swift` — covers MAC-03 health check logic (mock AXIsProcessTrusted)
- [ ] `MyWhisperTests/HotkeyMonitorTests.swift` — covers REC-01 hotkey registration
- [ ] `MyWhisperTests/TextInjectorTests.swift` — covers OUT-01 pasteboard write
- [ ] `MyWhisperTests/AudioRecorderTests.swift` — covers PRV-01 stub behavior
- [ ] `Package.swift` — HotKey v0.2.1 dependency
- [ ] `Info.plist` entries: `LSUIElement = YES`, `NSMicrophoneUsageDescription`, `MACOSX_DEPLOYMENT_TARGET = 14.0`
- [ ] `MyWhisper.entitlements` — `com.apple.security.app-sandbox = NO`, `com.apple.security.automation.apple-events = YES`

---

## Sources

### Primary (HIGH confidence)
- [soffes/HotKey GitHub](https://github.com/soffes/HotKey) — v0.2.1 API, Carbon EventHotKey wrapper, keyDownHandler pattern
- [Apple NSStatusItem Documentation](https://developer.apple.com/documentation/appkit/nsstatusitem) — button.image, isTemplate, squareLength
- [Apple AXIsProcessTrusted / AXIsProcessTrustedWithOptions](https://developer.apple.com/documentation/applicationservices/1459134-axisprocesstrusted) — accessibility check API
- [Apple AVCaptureDevice.requestAccess](https://developer.apple.com/documentation/avfoundation/avcapturedevice/requestaccess(for:completionhandler:)) — microphone permission on-the-fly pattern
- [Apple CGEvent Documentation](https://developer.apple.com/documentation/coregraphics/cgevent) — keyboard event simulation, CGEventPost
- [Apple Developer Forums thread/659804](https://developer.apple.com/forums/thread/659804) — CGEvent paste simulation, 150ms delay requirement verified
- .planning/research/STACK.md — HotKey v0.2.1, Swift/SwiftUI stack decision (HIGH)
- .planning/research/ARCHITECTURE.md — FSM pattern, component responsibilities, data flow (HIGH)
- .planning/research/PITFALLS.md — Code signing trap, CGEventPost sandbox restriction, permission resets (HIGH)

### Secondary (MEDIUM confidence)
- [jano.dev Accessibility Permission in macOS (2025)](https://jano.dev/apple/macos/swift/2025/01/08/Accessibility-Permission.html) — AXIsProcessTrustedWithOptions behavior on macOS 14+, System Settings URL
- [cindori.com Floating Panel in SwiftUI for macOS](https://cindori.com/developer/floating-panel) — NSPanel .nonactivatingPanel pattern
- [AudioWhisper reference implementation](https://github.com/mazdak/AudioWhisper) — Production app using same stack (HotKey + CGEvent)
- [nilcoalescing.com Build a macOS Menu Bar Utility in SwiftUI](https://nilcoalescing.com/blog/BuildAMacOSMenuBarUtilityInSwiftUI/) — LSUIElement, MenuBarExtra vs NSStatusItem tradeoffs
- [multi.app blog: Pushing limits of NSStatusItem](https://multi.app/blog/pushing-the-limits-nsstatusitem) — NSStatusItem advanced usage patterns

### Tertiary (LOW confidence — needs manual verification)
- WebSearch findings on Option+Space keyboard layout interaction on Spanish keyboards — verify with physical Spanish keyboard during testing

---

## Metadata

**Confidence breakdown:**
- Standard Stack: HIGH — HotKey v0.2.1, NSStatusItem, CGEventPost, AXIsProcessTrusted all verified via official docs and production reference implementations
- Architecture (FSM, patterns): HIGH — verified in ARCHITECTURE.md which cites production implementations; pattern is standard in all dictation apps
- Pitfalls: HIGH — code signing trap, CGEventPost sandbox limitation, permission reset all verified via Apple Developer Forums and official docs
- Waveform animation specifics: MEDIUM — multiple valid approaches, exact implementation is Claude's discretion per CONTEXT.md

**Research date:** 2026-03-15
**Valid until:** 2026-04-15 (stable macOS/Swift APIs; HotKey library is mature and infrequently updated)
