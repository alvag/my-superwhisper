---
phase: 01-foundation
verified: 2026-03-15T22:00:00Z
status: human_needed
score: 10/10 must-haves verified
re_verification: true
  previous_status: gaps_found
  previous_score: 9/10
  gaps_closed:
    - "Microphone permission is requested on-the-fly (MAC-02): requestMicrophone() now called from AppCoordinator.handleHotkey() case .idle via PermissionsManaging protocol; AppDelegate wires coordinator.permissionsManager = permissionsManager; 3 new TDD tests cover denied/granted/nil paths"
  gaps_remaining: []
  regressions: []
human_verification:
  - test: "Menubar icon color transitions visible at runtime"
    expected: "Gray mic icon at idle, red mic icon when recording, brief blue during processing, back to gray"
    why_human: "NSImage.withSymbolConfiguration paletteColors requires a running NSApplication to render — cannot verify color rendering programmatically without launching the app."
  - test: "Overlay waveform floats above full-screen apps"
    expected: "NSPanel overlay appears above a full-screen application (e.g., full-screen Safari) while recording"
    why_human: "NSPanel.collectionBehavior=[.canJoinAllSpaces,.fullScreenAuxiliary] requires live Spaces/Mission Control interaction to verify."
  - test: "Paste lands at cursor position in various apps"
    expected: "After recording, 'Texto de prueba' appears in TextEdit, VS Code, Slack, and Safari URL bar at the cursor position"
    why_human: "CGEventPost behavior is system-level and depends on active Accessibility permission — requires manual end-to-end test."
  - test: "On-the-fly mic permission dialog appears on first recording"
    expected: "With microphone in notDetermined state, pressing Option+Space shows the macOS system microphone permission dialog before AVAudioEngine starts"
    why_human: "TCC system dialogs cannot be triggered programmatically in tests. The wiring is verified (requestMicrophone() is called), but the dialog presentation itself requires a live macOS session."
---

# Phase 1: Foundation Verification Report

**Phase Goal:** Users can press a hotkey from any app, see recording state in the menubar, and have text pasted at their cursor — without any ML
**Verified:** 2026-03-15T22:00:00Z
**Status:** human_needed
**Re-verification:** Yes — after gap closure plan 01-04 fixed the MAC-02 on-the-fly mic permission gap

---

## Re-Verification Summary

| Item | Previous | Current | Change |
|------|----------|---------|--------|
| MAC-02 on-the-fly mic permission gap | FAILED | VERIFIED | Gap closed by plan 01-04 |
| All other must-haves | VERIFIED | VERIFIED (regression check passed) |
| Regressions | — | None found | — |
| Overall score | 9/10 | 10/10 | +1 |
| Status | gaps_found | human_needed | Promoted |

**Gap closure commits:**
- `ca03b44` — PermissionsManaging protocol + AppCoordinator wiring + 3 TDD tests
- `5adadc2` — AppDelegate wires `coordinator.permissionsManager = permissionsManager`

---

## Goal Achievement

### Observable Truths (from ROADMAP.md Success Criteria)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | User presses hotkey from any app and menubar icon changes state | VERIFIED | HotkeyMonitor.swift registers HotKey(key: .space, modifiers: [.option]) and dispatches to AppCoordinator.handleHotkey() via Task { @MainActor in }; AppCoordinator.transitionTo() calls menubarController?.update(state:) on every transition |
| 2 | User can cancel active recording by pressing Escape with no text pasted | VERIFIED | EscapeMonitor.swift monitors keyCode==53 globally; handleEscape() guards state == .recording, stops monitoring, hides overlay, cancels audio, beeps, transitions to .idle — textInjector.inject() is never called on cancel path |
| 3 | App prompts for Accessibility and Microphone permissions on first launch with clear explanations | VERIFIED | PermissionBlockedView.swift contains "Abrir Configuración del Sistema" button; separate explanations for accessibility and microphone with actionable Spanish text; AppDelegate shows window before any other setup |
| 4 | App detects revoked permissions on every launch and surfaces recovery prompt | VERIFIED | AppDelegate.applicationDidFinishLaunching calls permissionsManager.checkAllOnLaunch() as first action; if .blocked, showPermissionBlockedWindow() is called and the function returns before wiring any other components |
| 5 | Text placed on clipboard is automatically pasted at cursor in any app | VERIFIED | TextInjector.swift writes NSPasteboard.general, waits 150ms, then posts CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true/false) with .maskCommand to .cgSessionEventTap |

**Score:** 5/5 ROADMAP success criteria verified

### Plan must_haves Truths (from PLAN frontmatter across all 4 plans)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| P1-T1 | Option+Space transitions idle→recording and back | VERIFIED | AppCoordinator.handleHotkey() FSM: .idle→.recording, .recording→.processing→.idle |
| P1-T2 | Option+Space while .processing is ignored | VERIFIED | case .processing: break in handleHotkey() |
| P1-T3 | Escape during .recording cancels to .idle | VERIFIED | handleEscape() guard state == .recording; EscapeMonitor keyCode==53 |
| P1-T4 | Menubar icon shows gray/red/blue SF Symbol mic | VERIFIED | MenubarController.image(for:) returns NSImage with paletteColors per state; img?.isTemplate = false |
| P1-T5 | App has no Dock icon (.accessory activation policy) | VERIFIED | NSApp.setActivationPolicy(.accessory) in applicationDidFinishLaunching; LSUIElement=true in Info.plist; MyWhisperApp.body = Settings { EmptyView() } (no window scene) |
| P1-T6 | Non-sandboxed entitlements | VERIFIED | MyWhisper.entitlements: com.apple.security.app-sandbox = false |
| P2-T1 | checkAllOnLaunch() returns .blocked when AXIsProcessTrusted() is false | VERIFIED | PermissionsManager.checkAllOnLaunch() checks checker.isAccessibilityTrusted first; SystemPermissionsChecker calls AXIsProcessTrusted() |
| P2-T2 | checkAllOnLaunch() returns .blocked when microphone status is .denied | VERIFIED | checkAllOnLaunch() checks microphoneAuthorizationStatus == .denied or .restricted |
| P2-T3 | Blocking screen has 'Open System Settings' button | VERIFIED | PermissionBlockedView.swift: Button("Abrir Configuración del Sistema") calls permissionsManager.openSystemSettingsFor* |
| P2-T4 | Microphone permission requested on first recording start (on-the-fly) | VERIFIED | requestMicrophone() called from AppCoordinator.handleHotkey() case .idle (line 22 via PermissionsManaging protocol). Denied path transitions to .error("microphone"). Nil path preserves backward compatibility. Three TDD tests cover all branches. |
| P3-T1 | Option+Space → overlay appears, menubar turns red | VERIFIED | AppCoordinator.handleHotkey() case .idle: calls overlayController?.show() and transitionTo(.recording) which updates menubar |
| P3-T2 | TextInjector uses CGEvent keycode 0x09 with 150ms delay | VERIFIED | TextInjector.swift: virtualKey: 0x09, .maskCommand, .cgSessionEventTap, Task.sleep(.milliseconds(150)) |
| P3-T3 | AudioRecorder stub uses AVAudioEngine with no network calls | VERIFIED | AudioRecorder.swift imports only AVFoundation; no URLSession/URLRequest; installTap with empty closure |
| P3-T4 | OverlayWindowController uses .nonactivatingPanel + orderFront | VERIFIED | NSPanel styleMask includes .nonactivatingPanel; panel.orderFront(nil) used, NOT makeKeyAndOrderFront |
| P3-T5 | AppDelegate injects all 6 coordinator dependencies | VERIFIED | coordinator.menubarController, .escapeMonitor, .audioRecorder, .textInjector, .overlayController, .permissionsManager all assigned in applicationDidFinishLaunching (line 41-46) |
| P4-T1 | notDetermined mic permission shows system dialog before AVAudioEngine starts | VERIFIED (wiring) | requestMicrophone() calls AVCaptureDevice.requestAccess(for: .audio) for .notDetermined case; this triggers the macOS system dialog. Dialog presentation itself requires human verification. |
| P4-T2 | Denied mic permission transitions to .error("microphone"), not .recording | VERIFIED | testHotkeyDeniedMicrophoneTransitionsToError passes: MockPermissionsManaging(grant: false) → state == .error("microphone") |
| P4-T3 | nil permissionsManager proceeds to .recording (backward compat) | VERIFIED | testHotkeyNilPermissionsManagerProceedsToRecording passes; existing tests with no permissionsManager set still pass |

**Score:** 18/18 plan must-have truths verified

---

## Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `MyWhisper/Coordinator/AppState.swift` | enum AppState with idle/recording/processing/error | VERIFIED | 17 lines, all 4 cases, Equatable, description computed property |
| `MyWhisper/Coordinator/AppCoordinator.swift` | @MainActor @Observable FSM with handleHotkey/handleEscape + permissionsManager | VERIFIED | 61 lines; permissionsManager property at line 15; on-the-fly check in handleHotkey() case .idle lines 21-27 |
| `MyWhisper/System/HotkeyMonitor.swift` | HotKey(key: .space, modifiers: [.option]) | VERIFIED | Contains HotKey(key: .space, modifiers: [.option]); Task { @MainActor in } dispatch |
| `MyWhisper/UI/MenubarController.swift` | NSStatusItem with isTemplate = false | VERIFIED | img?.isTemplate = false present; all 4 states handled |
| `MyWhisper/MyWhisper.entitlements` | com.apple.security.app-sandbox = false | VERIFIED | Exact key present with false value |
| `MyWhisper/System/PermissionsManager.swift` | AXIsProcessTrusted(), PermissionsChecking protocol, PermissionsManaging protocol | VERIFIED | PermissionsChecking protocol + SystemPermissionsChecker; PermissionsManaging protocol at lines 35-37; extension PermissionsManager: PermissionsManaging {} at line 92 |
| `MyWhisper/UI/PermissionBlockedView.swift` | "Open System Settings" button, both permission types | VERIFIED | "Abrir Configuración del Sistema" button; .accessibility and .microphone cases both handled |
| `MyWhisperTests/PermissionsManagerTests.swift` | testAccessibilityRevoked test | VERIFIED | testCheckAllOnLaunch_accessibilityRevoked present; 6 tests total with MockPermissionsChecker |
| `MyWhisper/System/TextInjector.swift` | CGEvent keyboardEventSource, keycode 0x09 | VERIFIED | virtualKey: 0x09; .maskCommand; .cgSessionEventTap; 150ms delay |
| `MyWhisper/Audio/AudioRecorder.swift` | AVAudioEngine, no network imports | VERIFIED | AVAudioEngine present; installTap with empty closure; no URLSession |
| `MyWhisper/UI/OverlayWindowController.swift` | .nonactivatingPanel | VERIFIED | .nonactivatingPanel in styleMask; orderFront(nil); .canJoinAllSpaces; .fullScreenAuxiliary |
| `MyWhisper/UI/OverlayView.swift` | .repeatForever animation | VERIFIED | .repeatForever(autoreverses: true) present; 5-bar waveform |
| `MyWhisperTests/TextInjectorTests.swift` | testPasteboardWrite | VERIFIED | Both testPasteboardWrite and testPasteboardWriteOverwritesPrevious present |
| `MyWhisperTests/AudioRecorderTests.swift` | testNoNetworkCalls | VERIFIED | 3 tests; no network imports in AudioRecorder confirmed |
| `MyWhisperTests/AppCoordinatorTests.swift` | testHotkeyDeniedMicrophoneTransitionsToError + 2 more | VERIFIED | All 3 new tests present: denied->error, granted->recording, nil->recording; MockPermissionsManaging class at lines 6-10 |

---

## Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| HotkeyMonitor.swift | AppCoordinator.swift | Task { @MainActor in await coordinator.handleHotkey() } | WIRED | Exact pattern present at lines 13-15 of HotkeyMonitor.swift |
| AppCoordinator.swift | MenubarController.swift | menubarController?.update(state:) in transitionTo() | WIRED | transitionTo() calls menubarController?.update(state: newState) synchronously |
| AppDelegate.swift | AppCoordinator.swift | AppCoordinator() init + all 6 deps wired | WIRED | coordinator = AppCoordinator() at line 31; all 6 dependencies assigned including permissionsManager |
| AppDelegate.swift | PermissionsManager.swift | checkAllOnLaunch() in applicationDidFinishLaunching | WIRED | Called at line 23; early return guard at lines 24-28 |
| PermissionsManager.swift | PermissionBlockedView.swift | showPermissionBlockedWindow calls PermissionBlockedView | WIRED | AppDelegate.showPermissionBlockedWindow instantiates PermissionBlockedView |
| AppCoordinator.swift | TextInjector.swift | textInjector?.inject("Texto de prueba") in handleHotkey | WIRED | Line 38 in AppCoordinator.handleHotkey() |
| AppCoordinator.swift | AudioRecorder.swift | audioRecorder?.startStub/stopStub/cancelStub | WIRED | All three calls present in handleHotkey() and handleEscape() |
| AppCoordinator.swift | OverlayWindowController.swift | overlayController?.show/hide | WIRED | show() called on recording start; hide() on stop and escape |
| AppCoordinator.handleHotkey() case .idle | PermissionsManager.requestMicrophone() | await permissionsManager?.requestMicrophone() | WIRED | Line 22 of AppCoordinator.swift: `let granted = await pm.requestMicrophone()` — was NOT_WIRED in initial verification, now confirmed WIRED via commit ca03b44 |
| AppDelegate.applicationDidFinishLaunching | AppCoordinator.permissionsManager | coordinator.permissionsManager = permissionsManager | WIRED | Line 46 of AppDelegate.swift — was MISSING in initial verification, now confirmed WIRED via commit 5adadc2 |

---

## Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|-------------|--------|----------|
| MAC-01 | 01-01 | App runs as menubar application with state icon | SATISFIED | NSStatusItem in MenubarController; setActivationPolicy(.accessory); LSUIElement=true |
| MAC-02 | 01-02, 01-04 | App prompts for Accessibility and Microphone permissions on first launch; on-the-fly mic request before first recording | SATISFIED | Health-check blocking path: checkAllOnLaunch() + showPermissionBlockedWindow(). On-the-fly path: requestMicrophone() called in handleHotkey() case .idle before startStub(); denied -> .error("microphone"); granted -> .recording. Both paths fully wired and tested (7 AppCoordinatorTests, all passing). |
| MAC-03 | 01-02 | App checks permission health on every launch | SATISFIED | checkAllOnLaunch() called as first action in applicationDidFinishLaunching |
| MAC-06 | 01-01 | App requires macOS 14+ on Apple Silicon | SATISFIED | MACOSX_DEPLOYMENT_TARGET=14.0 in project.pbxproj; ARCHS=arm64 |
| PRV-01 | 01-01, 01-03 | Audio transcribed 100% locally — raw audio never leaves machine | SATISFIED | AudioRecorder.startStub() installTap with empty closure discards all audio; no network imports; comment in code confirms "PRV-01: audio never leaves the device" |
| PRV-02 | 01-02, 01-03 | Only transcribed text (not audio) sent to Haiku API | TRACEABILITY NOTE | REQUIREMENTS.md maps PRV-02 to Phase 3, but Plans 02 and 03 both list it in their requirements. In Phase 1 there is no Haiku API at all. The constraint is trivially satisfied (nothing is sent to any API), but the full requirement is a Phase 3 concern. No gap in implementation — flagged as traceability inconsistency only. |
| REC-01 | 01-01, 01-03 | User can press global hotkey to start recording from any app | SATISFIED | HotkeyMonitor registers Carbon hotkey for Option+Space globally via HotKey library |
| REC-04 | 01-01, 01-03 | User can press Escape to cancel recording without pasting text | SATISFIED | EscapeMonitor.startMonitoring() called on recording start; handleEscape() verified not to call textInjector |
| OUT-01 | 01-03 | Clean text automatically pasted at cursor via Cmd+V simulation | SATISFIED | TextInjector: NSPasteboard.setString + CGEventPost keycode 0x09 + .maskCommand |
| OUT-02 | 01-03 | Auto-paste works system-wide in any macOS app | SATISFIED | CGEventPost to .cgSessionEventTap is system-wide; OverlayWindowController uses orderFront (not makeKeyAndOrderFront) so target app focus is preserved |

### Orphaned Requirements Check

REQUIREMENTS.md Phase 1 traceability lists: MAC-01, MAC-02, MAC-03, MAC-06, PRV-01, OUT-01, OUT-02, REC-01, REC-04.
All Phase 1 requirements are claimed by at least one plan. PRV-02 is claimed by Phase 1 plans but REQUIREMENTS.md maps it to Phase 3 — this is a mismatch but not an orphan.

---

## Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| AppCoordinator.swift | 37 | `// Phase 1: inject placeholder text; Phase 2+ replaces this` | Info | Expected — the "Texto de prueba" placeholder is intentional for Phase 1 foundation |
| TextInjector.swift | 47 | `// Phase 1: use simple NSAlert as placeholder; Phase 4 can upgrade to toast` | Info | Fallback notification path is functional; NSAlert works correctly as placeholder |
| OverlayView.swift | 3 | `// Phase 1: Animated placeholder — three bars pulsing at different rates.` | Info | Expected — waveform placeholder is intentional until Phase 2 audio meters |
| StatusMenuView.swift | 29 | `@objc private func openSettings() { // Phase 4 — stub }` | Warning | Settings menu item appears in UI but does nothing. Not visible to casual users but present in menu. |

No blockers found. No regressions from plan 01-04 changes. All "placeholder" comments are intentional Phase 1 design decisions.

---

## Human Verification Required

### 1. Menubar Icon Color Rendering

**Test:** Launch the app, observe the menubar icon. Press Option+Space and observe the transition. Press again and observe processing then idle.
**Expected:** Gray mic icon at idle, red mic icon while recording, brief blue during processing, returns to gray.
**Why human:** NSImage.withSymbolConfiguration paletteColors requires a live NSApplication with an active display to render. The isTemplate=false flag is verified in code but actual color rendering must be visually confirmed.

### 2. Overlay Floats Above Full-Screen Apps

**Test:** Put Safari or another app into full-screen mode. Press Option+Space.
**Expected:** The overlay waveform panel appears above the full-screen app without triggering Mission Control.
**Why human:** NSPanel.collectionBehavior=[.canJoinAllSpaces, .fullScreenAuxiliary] requires live Spaces integration to test.

### 3. Paste Accuracy Across Target Apps

**Test:** Place cursor in TextEdit, VS Code, Slack, and a browser URL bar. Press Option+Space, wait, press again. Verify "Texto de prueba" appears at cursor in each.
**Expected:** Text appears exactly at cursor position in all tested apps without moving focus away.
**Why human:** CGEventPost behavior depends on active Accessibility permission and the focused app's input handling — runtime verification only.

### 4. On-the-Fly Microphone Permission Dialog

**Test:** Reset microphone permission to notDetermined (via `tccutil reset Microphone` in Terminal or a fresh install). Press Option+Space.
**Expected:** macOS system dialog appears asking "MyWhisper would like to access the microphone". After granting, recording starts normally. After denying, nothing happens (state returns to idle via .error("microphone")).
**Why human:** TCC system dialogs cannot be triggered programmatically in tests. The wiring is verified (requestMicrophone() is called, ca03b44), but the actual dialog presentation and user flow requires a live macOS session.

---

## Verification Closure

All automated checks pass. The one functional gap identified in the initial verification (MAC-02 on-the-fly microphone permission) has been fully closed by plan 01-04:

- `PermissionsManaging` protocol extracted and placed in PermissionsManager.swift
- `AppCoordinator.permissionsManager: (any PermissionsManaging)?` property added
- `handleHotkey()` case `.idle` now calls `await pm.requestMicrophone()` before `startStub()`
- Denied path transitions to `.error("microphone")` without starting recording
- Nil path preserves backward compatibility (existing tests unchanged)
- `AppDelegate` wires `coordinator.permissionsManager = permissionsManager`
- 3 new TDD tests verify all branches; total test count: 21

Phase 1 functional requirements are complete. Remaining items are runtime behaviors requiring human verification (visual, system-level, TCC dialogs).

---

_Verified: 2026-03-15T22:00:00Z_
_Verifier: Claude (gsd-verifier)_
_Re-verification: Yes — gap closure plan 01-04_
