---
phase: 5
slug: pause-playback-implementation
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-17
---

# Phase 5 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | XCTest (existing, no config file needed) |
| **Config file** | None — Xcode scheme `MyWhisper` |
| **Quick run command** | `xcodebuild test -scheme MyWhisper -only-testing:MyWhisperTests/AppCoordinatorTests -destination 'platform=macOS' 2>&1 \| tail -20` |
| **Full suite command** | `xcodebuild test -scheme MyWhisper -destination 'platform=macOS' 2>&1 \| tail -30` |
| **Estimated runtime** | ~15 seconds |

---

## Sampling Rate

- **After every task commit:** Run `xcodebuild test -scheme MyWhisper -only-testing:MyWhisperTests/AppCoordinatorTests -destination 'platform=macOS' 2>&1 | tail -20`
- **After every plan wave:** Run `xcodebuild test -scheme MyWhisper -destination 'platform=macOS' 2>&1 | tail -30`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 15 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 05-01-01 | 01 | 1 | MEDIA-01 | unit | `xcodebuild test -scheme MyWhisper -only-testing:MyWhisperTests/AppCoordinatorTests/testMediaPausedOnRecordingStart` | ❌ W0 | ⬜ pending |
| 05-01-02 | 01 | 1 | MEDIA-02 | unit | `xcodebuild test -scheme MyWhisper -only-testing:MyWhisperTests/AppCoordinatorTests/testMediaResumedOnRecordingStop` | ❌ W0 | ⬜ pending |
| 05-01-03 | 01 | 1 | MEDIA-02 | unit | `xcodebuild test -scheme MyWhisper -only-testing:MyWhisperTests/AppCoordinatorTests/testMediaNotResumedIfNotPaused` | ❌ W0 | ⬜ pending |
| 05-01-04 | 01 | 1 | MEDIA-03 | manual | Manual timing verification + log assertion | N/A | ⬜ pending |
| 05-01-05 | 01 | 1 | MEDIA-04 | manual | Code review (tap constant correctness) | N/A | ⬜ pending |
| 05-01-06 | 01 | 1 | SETT-01 | unit | `xcodebuild test -scheme MyWhisper -only-testing:MyWhisperTests/AppCoordinatorTests/testMediaToggleOffSkipsPauseResume` | ❌ W0 | ⬜ pending |
| 05-01-07 | 01 | 1 | SETT-02 | unit | `xcodebuild test -scheme MyWhisper -only-testing:MyWhisperTests/MediaPlaybackServiceTests/testTogglePersistedInUserDefaults` | ❌ W0 | ⬜ pending |
| 05-01-08 | 01 | 1 | MEDIA-02 | unit | `xcodebuild test -scheme MyWhisper -only-testing:MyWhisperTests/AppCoordinatorTests/testMediaResumedOnEscapeCancel` | ❌ W0 | ⬜ pending |
| 05-01-09 | 01 | 1 | MEDIA-02 | unit | `xcodebuild test -scheme MyWhisper -only-testing:MyWhisperTests/AppCoordinatorTests/testMediaResumedOnTranscriptionError` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `MyWhisperTests/MediaPlaybackServiceTests.swift` — stubs for SETT-02, pausedByApp flag unit tests, isEnabled UserDefaults default
- [ ] `MockMediaPlaybackService` in `MyWhisperTests/AppCoordinatorTests.swift` — covers MEDIA-01, MEDIA-02, SETT-01, escape, error path tests

*Existing `AppCoordinatorTests.swift` will be extended; new `MediaPlaybackServiceTests.swift` will be created*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| 150ms delay before AVAudioEngine start | MEDIA-03 | Timing verification requires real audio pipeline | 1. Play music in Spotify 2. Press hotkey 3. Verify fade-out completes before recording indicator appears |
| CGEventPost uses `.cghidEventTap` | MEDIA-04 | Compile-time constant, code review sufficient | Verify `CGEventPost(.cghidEventTap, event)` in MediaPlaybackService.swift |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 15s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
