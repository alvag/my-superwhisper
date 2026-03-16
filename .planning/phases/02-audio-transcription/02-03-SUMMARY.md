---
phase: 02-audio-transcription
plan: 03
subsystem: coordinator
tags: [whisperkit, vad, notifications, stt, pipeline, coordinator]

# Dependency graph
requires:
  - phase: 02-audio-transcription
    provides: AudioRecorder, VAD, STTEngine, OverlayWindowController built in plans 01+02
  - phase: 01-foundation
    provides: AppCoordinator FSM, AudioRecorderProtocol, TextInjectorProtocol, OverlayWindowControllerProtocol
provides:
  - Complete recording->VAD->STT->paste pipeline wired in AppCoordinator
  - NotificationHelper for macOS native notifications (silence, errors)
  - STTEngine pre-loaded at app launch via AppDelegate
  - Audio level polling at 30fps for overlay waveform visualization
  - Updated unit tests covering full pipeline with mock STT/VAD/overlay
affects: [03-text-cleanup, 04-polish]

# Tech tracking
tech-stack:
  added: [UserNotifications framework]
  patterns: [Timer-based audio level polling at 30fps, STTEngine actor pre-loaded via background Task at launch]

key-files:
  created:
    - MyWhisper/System/NotificationHelper.swift
  modified:
    - MyWhisper/Coordinator/AppCoordinator.swift
    - MyWhisper/App/AppDelegate.swift
    - MyWhisper/Coordinator/AppCoordinatorDependencies.swift
    - MyWhisper/UI/OverlayView.swift
    - MyWhisper/UI/OverlayWindowController.swift
    - MyWhisper/System/PermissionsManager.swift
    - MyWhisper/MyWhisper.entitlements
    - MyWhisperTests/AppCoordinatorTests.swift
    - MyWhisperTests/STTEngineTests.swift
    - MyWhisper.xcodeproj/project.pbxproj

key-decisions:
  - "Timer-based audio level polling at ~30fps bridges AudioRecorder.audioLevel to OverlayWindowController without reactive framework overhead"
  - "STTEngine pre-loaded in background Task at launch — non-blocking, non-fatal on failure (model loads lazily on first transcription)"
  - "NotificationHelper uses .provisional authorization to avoid blocking permission dialog at launch"
  - "MockSTTEngine in STTEngineTests renamed to MockSTTEngineProtocol to avoid redeclaration conflict with AppCoordinatorTests canonical MockSTTEngine"
  - "OverlayViewModel (ObservableObject) held by OverlayWindowController — NSHostingView created once, mode updates pushed via @Published property"
  - "OverlayWindowControllerProtocol marked @MainActor — required because OverlayViewModel is @MainActor and all overlay calls come from coordinator main thread"
  - "AVAudioApplication.requestRecordPermission() instead of AVCaptureDevice.requestAccess(for: .audio) — correct API for AVAudioEngine-based audio capture"
  - "com.apple.security.device.audio-input entitlement required even for non-sandboxed apps on macOS 14+ for microphone access"

patterns-established:
  - "startAudioLevelPolling/stopAudioLevelPolling: Timer pair manages 30fps overlay updates, invalidated on stop/escape/cancel"
  - "VAD gate pattern: audioRecorder.stop() -> VAD.hasSpeech() check before any async transcription work"

requirements-completed: [REC-02, REC-03, AUD-01, STT-02]

# Metrics
duration: 15min
completed: 2026-03-15
---

# Phase 02 Plan 03: Pipeline Integration Summary

**AppCoordinator wired with real recording->VAD->WhisperKit->paste pipeline, NotificationHelper for silence/error alerts, STTEngine pre-loaded at launch**

## Performance

- **Duration:** ~15 min
- **Started:** 2026-03-15T21:30:00Z
- **Completed:** 2026-03-15T21:45:00Z
- **Tasks:** 3 of 3 complete
- **Files modified:** 10

## Accomplishments
- NotificationHelper.swift delivers macOS native notifications (.provisional, no permission dialog)
- AppCoordinator rewritten: stub methods replaced with real start()/stop()/cancel(), VAD gate, sttEngine.transcribe(), audio level polling at 30fps
- AppDelegate creates STTEngine, wires coordinator.sttEngine, pre-loads model at launch in background Task
- AppCoordinatorTests fully updated with MockAudioRecorder, MockSTTEngine, MockOverlayController, MockTextInjector
- All test code compiles (xcodebuild build-for-testing BUILD SUCCEEDED)

## Task Commits

Each task was committed atomically:

1. **Task 1: NotificationHelper, updated AppCoordinator pipeline, and updated AppDelegate with STT pre-loading** - `5897c46` (feat)
2. **Task 2: Update unit tests for new AppCoordinator pipeline with mock STT** - `ae747d2` (test)
3. **Task 3: Verify end-to-end recording and transcription flow** - `40fd2f0` (fix)

## Files Created/Modified
- `MyWhisper/System/NotificationHelper.swift` - UNUserNotificationCenter wrapper for silence/error macOS notifications
- `MyWhisper/Coordinator/AppCoordinator.swift` - Full pipeline: start()/stop(), VAD gate, sttEngine.transcribe(), 30fps audio level polling, NotificationHelper calls
- `MyWhisper/App/AppDelegate.swift` - STTEngine creation, coordinator.sttEngine wiring, NotificationHelper.requestAuthorization(), background model pre-load Task
- `MyWhisperTests/AppCoordinatorTests.swift` - Complete rewrite with all mock types and pipeline tests
- `MyWhisperTests/STTEngineTests.swift` - Renamed MockSTTEngine to MockSTTEngineProtocol to resolve redeclaration conflict
- `MyWhisper.xcodeproj/project.pbxproj` - Registered NotificationHelper.swift (AA000036)
- `MyWhisper/UI/OverlayView.swift` - Added OverlayViewModel (ObservableObject), OverlayView now takes @ObservedObject viewModel
- `MyWhisper/UI/OverlayWindowController.swift` - Uses OverlayViewModel held as instance property; NSHostingView created once on show(); @MainActor
- `MyWhisper/Coordinator/AppCoordinatorDependencies.swift` - OverlayWindowControllerProtocol marked @MainActor
- `MyWhisper/System/PermissionsManager.swift` - requestMicrophone() uses AVAudioApplication.requestRecordPermission()
- `MyWhisper/MyWhisper.entitlements` - Added com.apple.security.device.audio-input entitlement

## Decisions Made
- Timer-based 30fps audio level polling: bridges AudioRecorder.audioLevel (updated on audio callback thread) to OverlayWindowController without reactive overhead
- STTEngine pre-loading is non-blocking and non-fatal — model loads lazily on first transcription if launch pre-load fails
- NotificationHelper uses .provisional authorization to deliver notifications to Notification Center without a blocking permission dialog

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Resolved MockSTTEngine redeclaration conflict**
- **Found during:** Task 2 (AppCoordinatorTests tests execution)
- **Issue:** STTEngineTests.swift declared `final class MockSTTEngine` which conflicted with the new `MockSTTEngine` in AppCoordinatorTests.swift — Swift test bundle builds as a single module
- **Fix:** Renamed `MockSTTEngine` in STTEngineTests.swift to `MockSTTEngineProtocol`
- **Files modified:** MyWhisperTests/STTEngineTests.swift
- **Verification:** `xcodebuild build-for-testing` BUILD SUCCEEDED
- **Committed in:** ae747d2 (Task 2 commit)

---

**2. [Rule 1 - Bug] OverlayWindowController recreated NSHostingView on every audio level update**
- **Found during:** Task 3 (E2E manual verification)
- **Issue:** Original implementation called `updateHostingView()` replacing the entire NSHostingView at 30fps — caused visible flicker and potential memory pressure
- **Fix:** Added OverlayViewModel (ObservableObject) as instance property; NSHostingView created once in show(); mode updated via @Published property; OverlayView uses @ObservedObject
- **Files modified:** MyWhisper/UI/OverlayView.swift, MyWhisper/UI/OverlayWindowController.swift, MyWhisper/Coordinator/AppCoordinatorDependencies.swift
- **Commit:** 40fd2f0

---

**3. [Rule 2 - Missing] Missing com.apple.security.device.audio-input entitlement**
- **Found during:** Task 3 (E2E manual verification — microphone access denied)
- **Issue:** App could not access microphone; entitlement required even for non-sandboxed apps on macOS 14+
- **Fix:** Added `<key>com.apple.security.device.audio-input</key><true/>` to MyWhisper.entitlements
- **Files modified:** MyWhisper/MyWhisper.entitlements
- **Commit:** 40fd2f0

---

**4. [Rule 1 - Bug] Wrong API for microphone permission request**
- **Found during:** Task 3 (E2E manual verification — TCC dialog did not appear)
- **Issue:** AVCaptureDevice.requestAccess(for: .audio) does not trigger the system TCC dialog for AVAudioEngine-based apps
- **Fix:** Replaced with AVAudioApplication.requestRecordPermission() — correct API for AVAudioEngine audio capture
- **Files modified:** MyWhisper/System/PermissionsManager.swift
- **Commit:** 40fd2f0

---

**Total deviations:** 4 auto-fixed (1 blocking, 3 bugs/missing)
**Impact on plan:** All fixes required for correct E2E operation. No architectural changes. Manual verification confirmed all fixes resolved the issues.

## Issues Encountered
- xcodebuild test execution fails with code signing Team ID mismatch (pre-existing issue documented in STATE.md). `xcodebuild build-for-testing` succeeds, confirming all code compiles correctly. Test execution requires running from Xcode with proper signing configuration.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Complete Phase 2 pipeline verified end-to-end by user (all manual tests pass)
- Phase 3 (text cleanup with Claude Haiku) can begin
- All subsystems built and verified: AudioRecorder, VAD, STTEngine, OverlayWindowController, AppCoordinator pipeline

---
*Phase: 02-audio-transcription*
*Completed: 2026-03-15*

## Self-Check: PASSED

- FOUND: MyWhisper/System/NotificationHelper.swift
- FOUND: MyWhisper/Coordinator/AppCoordinator.swift
- FOUND: MyWhisper/App/AppDelegate.swift
- FOUND: MyWhisper/UI/OverlayView.swift
- FOUND: MyWhisper/UI/OverlayWindowController.swift
- FOUND: MyWhisper/MyWhisper.entitlements
- FOUND: MyWhisperTests/AppCoordinatorTests.swift
- FOUND: .planning/phases/02-audio-transcription/02-03-SUMMARY.md
- FOUND: commit 5897c46 (feat: pipeline wiring)
- FOUND: commit ae747d2 (test: AppCoordinatorTests update)
- FOUND: commit 40fd2f0 (fix: Task 3 E2E verification fixes)
