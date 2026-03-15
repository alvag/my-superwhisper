---
phase: 1
slug: foundation
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-15
---

# Phase 1 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | XCTest (built into Xcode) + Swift Testing (Xcode 16+) |
| **Config file** | None — Xcode project handles test targets |
| **Quick run command** | `xcodebuild test -scheme MyWhisper -destination 'platform=macOS' -only-testing:MyWhisperTests/AppCoordinatorTests` |
| **Full suite command** | `xcodebuild test -scheme MyWhisper -destination 'platform=macOS'` |
| **Estimated runtime** | ~10 seconds |

---

## Sampling Rate

- **After every task commit:** Run `xcodebuild test -scheme MyWhisper -destination 'platform=macOS' -only-testing:MyWhisperTests/AppCoordinatorTests`
- **After every plan wave:** Run `xcodebuild test -scheme MyWhisper -destination 'platform=macOS'`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 15 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 01-01-01 | 01 | 1 | MAC-01 | unit | `xcodebuild test ... -only-testing:MyWhisperTests/MenubarControllerTests` | ❌ W0 | ⬜ pending |
| 01-01-02 | 01 | 1 | MAC-06 | smoke | Verify `MACOSX_DEPLOYMENT_TARGET = 14.0` in build settings | ❌ W0 | ⬜ pending |
| 01-01-03 | 01 | 1 | REC-01 | unit | `xcodebuild test ... -only-testing:MyWhisperTests/HotkeyMonitorTests` | ❌ W0 | ⬜ pending |
| 01-01-04 | 01 | 1 | REC-01 | unit | `xcodebuild test ... -only-testing:MyWhisperTests/AppCoordinatorTests/testHotkeyStartsRecording` | ❌ W0 | ⬜ pending |
| 01-01-05 | 01 | 1 | REC-01 | unit | `xcodebuild test ... -only-testing:MyWhisperTests/AppCoordinatorTests/testHotkeyStopsRecording` | ❌ W0 | ⬜ pending |
| 01-01-06 | 01 | 1 | REC-01 | unit | `xcodebuild test ... -only-testing:MyWhisperTests/AppCoordinatorTests/testHotkeyIgnoredDuringProcessing` | ❌ W0 | ⬜ pending |
| 01-01-07 | 01 | 1 | REC-04 | unit | `xcodebuild test ... -only-testing:MyWhisperTests/AppCoordinatorTests/testEscapeCancelsRecording` | ❌ W0 | ⬜ pending |
| 01-02-01 | 02 | 1 | MAC-02 | manual | N/A — TCC interaction | N/A | ⬜ pending |
| 01-02-02 | 02 | 1 | MAC-03 | unit | `xcodebuild test ... -only-testing:MyWhisperTests/PermissionsManagerTests` | ❌ W0 | ⬜ pending |
| 01-03-01 | 03 | 2 | OUT-01 | unit | `xcodebuild test ... -only-testing:MyWhisperTests/TextInjectorTests` | ❌ W0 | ⬜ pending |
| 01-03-02 | 03 | 2 | OUT-02 | manual | N/A — cross-app event injection | N/A | ⬜ pending |
| 01-03-03 | 03 | 2 | PRV-01 | unit | `xcodebuild test ... -only-testing:MyWhisperTests/AudioRecorderTests/testNoNetworkCalls` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `MyWhisperTests/AppCoordinatorTests.swift` — stubs for FSM state transitions
- [ ] `MyWhisperTests/HotkeyMonitorTests.swift` — stubs for hotkey registration
- [ ] `MyWhisperTests/MenubarControllerTests.swift` — stubs for icon state changes
- [ ] `MyWhisperTests/PermissionsManagerTests.swift` — stubs for permission health check
- [ ] `MyWhisperTests/TextInjectorTests.swift` — stubs for clipboard write
- [ ] `MyWhisperTests/AudioRecorderTests.swift` — stubs for no-network verification
- [ ] Xcode project test target creation (greenfield project)

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Accessibility permission dialog appears on first paste | MAC-02 | TCC dialogs cannot be scripted in unit tests | 1. Launch app fresh 2. Press Option+Space 3. Press again to stop 4. Verify Accessibility prompt appears |
| Microphone permission dialog appears on first recording | MAC-02 | TCC dialogs cannot be scripted in unit tests | 1. Launch app fresh 2. Press Option+Space 3. Verify Microphone prompt appears |
| Paste simulation works cross-app | OUT-02 | Requires running app + focused target app | 1. Open TextEdit 2. Press Option+Space, wait, press again 3. Verify text appears at cursor in TextEdit |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 15s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
