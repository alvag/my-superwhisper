---
phase: 7
slug: implementation
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-17
---

# Phase 7 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | XCTest (built-in, Xcode) |
| **Config file** | `MyWhisper.xcodeproj` — `MyWhisperTests` target |
| **Quick run command** | `xcodebuild -project MyWhisper.xcodeproj -scheme MyWhisper -destination "platform=macOS" -configuration Debug CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO test 2>&1 \| grep -E "passed\|failed"` |
| **Full suite command** | Same as above |
| **Estimated runtime** | ~15 seconds |

---

## Sampling Rate

- **After every task commit:** Run quick run command
- **After every plan wave:** Run full suite command
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 15 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 07-01-01 | 01 | 1 | VOL-01 | unit | `xcodebuild ... -only-testing:MyWhisperTests/MicInputVolumeServiceTests` | ❌ W0 | ⬜ pending |
| 07-01-02 | 01 | 1 | VOL-04 | unit | `xcodebuild ... -only-testing:MyWhisperTests/MicInputVolumeServiceTests` | ❌ W0 | ⬜ pending |
| 07-01-03 | 01 | 1 | VOL-05 | unit | `xcodebuild ... -only-testing:MyWhisperTests/MicInputVolumeServiceTests` | ❌ W0 | ⬜ pending |
| 07-02-01 | 02 | 1 | VOL-01,02 | unit | `xcodebuild ... -only-testing:MyWhisperTests/AppCoordinatorTests/testVolumeMaximizedOnRecordingStart` | ❌ W0 | ⬜ pending |
| 07-02-02 | 02 | 1 | VOL-03 | unit | `xcodebuild ... -only-testing:MyWhisperTests/AppCoordinatorTests/testVolumeRestoredOnRecordingStop` | ❌ W0 | ⬜ pending |
| 07-02-03 | 02 | 1 | VOL-03 | unit | `xcodebuild ... -only-testing:MyWhisperTests/AppCoordinatorTests/testVolumeRestoredOnEscapeCancel` | ❌ W0 | ⬜ pending |
| 07-02-04 | 02 | 1 | VOL-03 | unit | `xcodebuild ... -only-testing:MyWhisperTests/AppCoordinatorTests/testVolumeRestoredOnStartFailure` | ❌ W0 | ⬜ pending |
| 07-02-05 | 02 | 1 | VOL-06 | unit | `xcodebuild ... -only-testing:MyWhisperTests/AppCoordinatorTests/testVolumeToggleOffSkipsMaximize` | ❌ W0 | ⬜ pending |
| 07-03-01 | 03 | 1 | HAIKU-01 | unit | `xcodebuild ... -only-testing:MyWhisperTests/HaikuCleanupServiceTests/testRequestBodyContainsRule6` | ❌ W0 | ⬜ pending |
| 07-03-02 | 03 | 1 | HAIKU-02 | unit | `xcodebuild ... -only-testing:MyWhisperTests/AppCoordinatorTests/testSuffixStripRemovesHallucinatedGracias` | ❌ W0 | ⬜ pending |
| 07-03-03 | 03 | 1 | HAIKU-02 | unit | `xcodebuild ... -only-testing:MyWhisperTests/AppCoordinatorTests/testSuffixStripPreservesLegitimateGracias` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `MyWhisperTests/MicInputVolumeServiceTests.swift` — stubs for VOL-01/04/05 (new file)
- [ ] `MyWhisperTests/AppCoordinatorTests.swift` — extend with VOL-01/02/03/06 and HAIKU-02 test cases
- [ ] `MyWhisperTests/HaikuCleanupServiceTests.swift` — extend with HAIKU-01 Rule 6 presence check

*Existing infrastructure covers test framework — Wave 0 is additive only.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Mic volume visibly jumps to max in System Settings during recording | VOL-02 | Requires observing macOS System Settings Audio panel | 1. Open System Settings > Sound > Input. 2. Start recording. 3. Verify slider jumps to max. 4. Stop recording. 5. Verify slider returns to original. |
| Built-in Mac mic graceful degradation | VOL-04 | Hardware-dependent, no mock for AudioObjectIsPropertySettable | 1. Select built-in mic in Settings. 2. Start recording. 3. Verify no error shown. 4. Recording proceeds normally. |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 15s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
