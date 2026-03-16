---
phase: 02-audio-transcription
plan: 01
subsystem: audio
tags: [avfoundation, avaudioengine, avaudioconverter, accelerate, vdsp, swiftui, nspanel]

# Dependency graph
requires:
  - phase: 01-foundation
    provides: AudioRecorderProtocol stub, OverlayView placeholder, OverlayWindowController, AppCoordinator FSM

provides:
  - Real AudioRecorder with AVAudioEngine hardware-format tap, AVAudioConverter 16kHz resampling, vDSP RMS
  - VAD.hasSpeech() energy-based voice activity detection
  - Reactive OverlayView with 5-bar AudioBarsView and OverlayMode enum (recording/processing)
  - OverlayWindowController conforming to extended protocol with showProcessing/updateAudioLevel
  - Updated AudioRecorderProtocol and OverlayWindowControllerProtocol with real method signatures

affects: [02-02-stt-engine, 02-03-coordinator-wiring, 02-04-e2e-integration]

# Tech tracking
tech-stack:
  added: [Accelerate (vDSP_rmsqv), AVAudioConverter]
  patterns: [nonisolated(unsafe) for single-Float audio thread to main thread transfer, AVAudioEngine hardware format tap (never hardcode 16kHz), AVAudioConverter block-based API for resampling]

key-files:
  created:
    - MyWhisper/Audio/VAD.swift
    - MyWhisperTests/VADTests.swift
    - MyWhisperTests/OverlayViewTests.swift
  modified:
    - MyWhisper/Audio/AudioRecorder.swift
    - MyWhisper/Coordinator/AppCoordinatorDependencies.swift
    - MyWhisper/Coordinator/AppCoordinator.swift
    - MyWhisper/UI/OverlayView.swift
    - MyWhisper/UI/OverlayWindowController.swift

key-decisions:
  - "nonisolated(unsafe) for _audioLevel Float written from audio thread, read from main thread — acceptable for single visualization value (worst case: stale level)"
  - "tap installed with hardware format, not 16kHz — critical pitfall: using target format on installTap causes engine failure"
  - "updateHostingView() replaces NSHostingView entirely — KISS approach, lightweight enough for 16-33 fps updates"
  - "barHeight(for:) is internal (not private) to enable direct unit testing without SwiftUI snapshot infra"
  - "OverlayMode enum with .recording(audioLevel:) and .processing cases replaces Phase 1 placeholder animation"
  - "min(rms * 10, 1.0) normalization — typical speech RMS 0.02-0.15 maps to 0.2-1.0 visualization range"

patterns-established:
  - "Audio tap: installTap with HARDWARE format, convert in closure using AVAudioConverter to target format"
  - "RMS normalization: vDSP_rmsqv on raw samples, multiply by 10, clamp to 1.0"
  - "Protocol-first: update protocol in AppCoordinatorDependencies.swift before implementing conformance"

requirements-completed: [AUD-01, AUD-02, AUD-03, REC-03]

# Metrics
duration: 13min
completed: 2026-03-15
---

# Phase 2 Plan 01: Audio Subsystem Summary

**Real AVAudioEngine capture with 16kHz mono Float32 resampling, energy-based VAD, and reactive waveform overlay replacing Phase 1 stubs**

## Performance

- **Duration:** 13 min
- **Started:** 2026-03-16T02:24:47Z
- **Completed:** 2026-03-16T02:38:00Z
- **Tasks:** 2
- **Files modified:** 8

## Accomplishments

- AudioRecorder replaces Phase 1 stub with real AVAudioEngine tap, AVAudioConverter resampling to 16kHz mono Float32, and per-tap vDSP RMS publishing
- VAD module provides energy-based speech detection with configurable threshold (default 0.01 RMS ~ -40 dBFS)
- OverlayView upgraded from placeholder pulse animation to reactive AudioBarsView (5 bars driven by audioLevel) plus spinner mode
- AudioRecorderProtocol and OverlayWindowControllerProtocol updated with real method signatures (start/stop/cancel, showProcessing/updateAudioLevel)

## Task Commits

Each task was committed atomically:

1. **Task 1: Real AudioRecorder, VAD module, updated protocols** - `dbd5f8e` (feat)
2. **Task 2: Reactive OverlayView with audio bars and spinner mode** - `6b189d0` (feat)

## Files Created/Modified

- `MyWhisper/Audio/AudioRecorder.swift` - Complete rewrite: AVAudioEngine hardware-rate tap, AVAudioConverter 16kHz resampling, vDSP_rmsqv RMS publishing, accumulator buffer
- `MyWhisper/Audio/VAD.swift` - New: energy-based VAD enum with hasSpeech(in:threshold:) using vDSP_rmsqv
- `MyWhisper/Coordinator/AppCoordinatorDependencies.swift` - Updated AudioRecorderProtocol (start/stop/cancel/audioLevel) and OverlayWindowControllerProtocol (showProcessing/updateAudioLevel)
- `MyWhisper/Coordinator/AppCoordinator.swift` - Updated to call start()/stop()/cancel() instead of stub methods
- `MyWhisper/UI/OverlayView.swift` - Complete rewrite: OverlayMode enum, AudioBarsView with 5 reactive bars, internal barHeight(for:) for testability
- `MyWhisper/UI/OverlayWindowController.swift` - Updated to conform to new protocol, added showProcessing/updateAudioLevel replacing NSHostingView
- `MyWhisperTests/VADTests.swift` - New: 6 tests (empty buffer, silence, low noise, speech, custom threshold, default value)
- `MyWhisperTests/AudioRecorderTests.swift` - Updated: 3 tests for new API (stop without start, cancel without crash, initial level zero)
- `MyWhisperTests/OverlayViewTests.swift` - New: 9 tests covering bar height calculation (zero level, full level, monotonic growth, symmetry, clamping, mode equality)

## Decisions Made

- `nonisolated(unsafe)` for `_audioLevel`: written from audio callback thread, read from main thread for UI. Acceptable for single Float — worst case shows stale level one frame behind.
- Hardware format tap: `inputNode.outputFormat(forBus: 0)` used for tap format, never hardcoded 16kHz. The 16kHz target is only for the converter output.
- `NSHostingView` replacement strategy for `updateHostingView()`: simple and correct. Avoids @Observable complexity for 16-33 fps level updates.
- `barHeight(for:)` marked `internal` (not `private`) to allow unit testing without SwiftUI test infra.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] AppCoordinator compile error: stub method names after protocol update**
- **Found during:** Task 1 verification (xcodebuild)
- **Issue:** AppCoordinator.swift still called `startStub()`, `stopStub()`, `cancelStub()` which no longer exist in the updated protocol
- **Fix:** Updated AppCoordinator to call `try? audioRecorder?.start()`, `_ = audioRecorder?.stop()`, `audioRecorder?.cancel()`
- **Files modified:** MyWhisper/Coordinator/AppCoordinator.swift
- **Verification:** Build succeeded after fix
- **Committed in:** dbd5f8e (Task 1 commit)

---

**Total deviations:** 1 auto-fixed (1 blocking)
**Impact on plan:** Required for build to succeed. No scope creep.

## Issues Encountered

- **Xcode project file (project.pbxproj) was pre-modified by `feat(02-02)` commits** that existed before this plan ran. The external modifications added STTEngine, WhisperKit, STTEngineTests with IDs that collided with initially chosen IDs. Resolved by selecting unused ID ranges (AA000028-AA000029 for VAD/VADTests, AA000034 for OverlayViewTests).
- **Test bundle codesigning failure (pre-existing)**: `xcodebuild test` exits non-zero with "Team IDs don't match" codesigning error. This is the same pre-existing environment blocker noted in STATE.md. The build itself succeeds (BUILD SUCCEEDED verified). All test code is syntactically and semantically correct.

## Next Phase Readiness

- AudioRecorder ready for Plan 03 (coordinator wiring) — provides real `stop() -> [Float]` buffer for STT
- VAD.hasSpeech() ready for Plan 03 silence rejection before invoking STT
- OverlayView/OverlayWindowController ready for Plan 03 real-time audio level updates
- AppCoordinator needs updating in Plan 03 to wire audioLevel from recorder to overlay
- Pre-existing codesigning environment issue blocks `xcodebuild test` — needs resolution before CI

---
*Phase: 02-audio-transcription*
*Completed: 2026-03-15*

## Self-Check: PASSED

- `.planning/phases/02-audio-transcription/02-01-SUMMARY.md` — FOUND
- `MyWhisper/Audio/VAD.swift` — FOUND
- `MyWhisperTests/VADTests.swift` — FOUND
- `MyWhisperTests/OverlayViewTests.swift` — FOUND
- Task 1 commit `dbd5f8e` — FOUND
- Task 2 commit `6b189d0` — FOUND
