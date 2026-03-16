---
phase: 4
slug: settings-history-and-polish
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-16
---

# Phase 4 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | XCTest (built-in) |
| **Config file** | MyWhisperTests/ directory |
| **Quick run command** | `xcodebuild test -scheme MyWhisper -only-testing:MyWhisperTests -quiet 2>&1 \| tail -5` |
| **Full suite command** | `xcodebuild test -scheme MyWhisper -quiet 2>&1 \| tail -20` |
| **Estimated runtime** | ~15 seconds |

---

## Sampling Rate

- **After every task commit:** Run `xcodebuild test -scheme MyWhisper -only-testing:MyWhisperTests -quiet 2>&1 | tail -5`
- **After every plan wave:** Run `xcodebuild test -scheme MyWhisper -quiet 2>&1 | tail -20`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 04-01-01 | 01 | 1 | REC-05 | unit | `xcodebuild test -only-testing:MyWhisperTests/SettingsServiceTests` | ❌ W0 | ⬜ pending |
| 04-01-02 | 01 | 1 | MAC-04 | unit | `xcodebuild test -only-testing:MyWhisperTests/AudioDeviceTests` | ❌ W0 | ⬜ pending |
| 04-02-01 | 02 | 1 | OUT-03 | unit | `xcodebuild test -only-testing:MyWhisperTests/HistoryServiceTests` | ❌ W0 | ⬜ pending |
| 04-02-02 | 02 | 1 | OUT-04 | unit | `xcodebuild test -only-testing:MyWhisperTests/HistoryServiceTests` | ❌ W0 | ⬜ pending |
| 04-03-01 | 03 | 1 | VOC-01 | unit | `xcodebuild test -only-testing:MyWhisperTests/VocabularyServiceTests` | ❌ W0 | ⬜ pending |
| 04-03-02 | 03 | 1 | VOC-02 | unit | `xcodebuild test -only-testing:MyWhisperTests/VocabularyServiceTests` | ❌ W0 | ⬜ pending |
| 04-04-01 | 04 | 2 | MAC-05 | manual | Instruments profiling | N/A | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `MyWhisperTests/SettingsServiceTests.swift` — stubs for REC-05 hotkey persistence
- [ ] `MyWhisperTests/AudioDeviceTests.swift` — stubs for MAC-04 device selection
- [ ] `MyWhisperTests/HistoryServiceTests.swift` — stubs for OUT-03, OUT-04
- [ ] `MyWhisperTests/VocabularyServiceTests.swift` — stubs for VOC-01, VOC-02

*Existing XCTest infrastructure from Phase 1-3 covers framework needs.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Hotkey works system-wide after change | REC-05 | Requires global event monitor + other app focus | 1. Open Settings, record new hotkey 2. Switch to Safari 3. Press new hotkey 4. Verify recording starts |
| Microphone selection persists across launches | MAC-04 | Requires real audio hardware | 1. Select non-default mic in Settings 2. Quit and relaunch 3. Verify selected mic persists |
| RAM usage at idle | MAC-05 | Requires Instruments profiling | 1. Launch app, wait 30s 2. Check Activity Monitor RSS 3. Must be <200MB |
| DMG notarization | Distribution | Requires Apple notary service | 1. Build DMG 2. `xcrun notarytool submit` 3. Verify staple |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
