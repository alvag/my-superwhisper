---
phase: 2
slug: audio-transcription
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-15
---

# Phase 2 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | XCTest (MyWhisperTests target) |
| **Config file** | MyWhisper.xcodeproj (test target: MyWhisperTests) |
| **Quick run command** | `xcodebuild test -scheme MyWhisper -destination 'platform=macOS' -only-testing:MyWhisperTests/AudioRecorderTests -only-testing:MyWhisperTests/VADTests -only-testing:MyWhisperTests/AppCoordinatorTests` |
| **Full suite command** | `xcodebuild test -scheme MyWhisper -destination 'platform=macOS'` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Run `xcodebuild test -scheme MyWhisper -destination 'platform=macOS' -only-testing:MyWhisperTests/AudioRecorderTests -only-testing:MyWhisperTests/VADTests -only-testing:MyWhisperTests/AppCoordinatorTests`
- **After every plan wave:** Run `xcodebuild test -scheme MyWhisper -destination 'platform=macOS'`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 02-01-01 | 01 | 1 | AUD-01 | unit (mic required) | `xcodebuild test ... -only-testing:MyWhisperTests/AudioRecorderTests/testStartCaptures` | ❌ W0 | ⬜ pending |
| 02-01-02 | 01 | 1 | AUD-02 | unit | `xcodebuild test ... -only-testing:MyWhisperTests/AudioRecorderTests/testBufferFormat` | ❌ W0 | ⬜ pending |
| 02-01-03 | 01 | 1 | AUD-03 | unit | `xcodebuild test ... -only-testing:MyWhisperTests/VADTests/testSilenceDetection` | ❌ W0 | ⬜ pending |
| 02-02-01 | 02 | 1 | STT-01 | integration (manual) | Manual test — requires model download | manual-only | ⬜ pending |
| 02-02-02 | 02 | 1 | STT-02 | unit (mock) | `xcodebuild test ... -only-testing:MyWhisperTests/STTEngineTests/testModelLoads` | ❌ W0 | ⬜ pending |
| 02-02-03 | 02 | 1 | STT-03 | performance (manual) | Manual timing test with stopwatch | manual-only | ⬜ pending |
| 02-03-01 | 03 | 2 | REC-02 | unit | `xcodebuild test ... -only-testing:MyWhisperTests/AppCoordinatorTests/testHotkeyStopsRecordingAndTranscribes` | ❌ W0 | ⬜ pending |
| 02-03-02 | 03 | 2 | REC-03 | unit (SwiftUI) | `xcodebuild test ... -only-testing:MyWhisperTests/OverlayViewTests/testBarsHeightChanges` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `MyWhisperTests/VADTests.swift` — NEW: covers AUD-03 with pure Float32 array tests (no hardware needed)
- [ ] `MyWhisperTests/STTEngineTests.swift` — NEW: covers STT-02 with mock WhisperKit dependency (protocol injection)
- [ ] `MyWhisperTests/OverlayViewTests.swift` — NEW: covers REC-03 (SwiftUI view unit test)
- [ ] `MyWhisperTests/AudioRecorderTests.swift` — extend to cover AUD-01, AUD-02 buffer format tests
- [ ] `MyWhisper/Coordinator/AppCoordinatorDependencies.swift` — add STTEngineProtocol
- [ ] Note: xcodebuild license must be accepted (`sudo xcodebuild -license accept`) before any build/test

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| STT produces correct Spanish text from speech | STT-01 | Requires real microphone input and large-v3 model download | Record 30s of Spanish speech, verify transcription contains expected words |
| Transcription completes within 5s for 30-60s recording | STT-03 | Performance depends on hardware (Apple Silicon variant) | Time from hotkey-stop to text-paste with stopwatch |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
