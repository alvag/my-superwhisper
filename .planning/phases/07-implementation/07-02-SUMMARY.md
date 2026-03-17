---
phase: 07-implementation
plan: 02
subsystem: audio
tags: [swift, coreaudio, microphone, volume, appdelegateate, settings, testing]

# Dependency graph
requires:
  - phase: 07-01
    provides: MicInputVolumeService and MicInputVolumeServiceProtocol

provides:
  - Volume service wired into AppCoordinator at all 3 restore exit paths
  - maximizeAndSave() called before audioRecorder.start() in idle case
  - restore() called at recording stop, escape cancel, and start failure
  - UserDefaults default registration for maximizeMicVolumeEnabled=true
  - MicInputVolumeService instantiated and injected in AppDelegate
  - Settings panel volume toggle checkbox persisting to UserDefaults
  - 8 passing unit tests covering all volume service call paths

affects: [08-verification]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Optional service injection via var micVolumeService: (any MicInputVolumeServiceProtocol)?"
    - "restore() placed before audioRecorder.stop() in .recording case to cover all downstream paths"
    - "isEnabled guard lives inside service, not coordinator — coordinator always calls unconditionally"

key-files:
  created: []
  modified:
    - MyWhisper/Coordinator/AppCoordinator.swift
    - MyWhisper/App/AppDelegate.swift
    - MyWhisper/Settings/SettingsWindowController.swift
    - MyWhisperTests/AppCoordinatorTests.swift

key-decisions:
  - "restore() placed BEFORE audioRecorder.stop() in .recording case — single placement covers VAD silence, STT error, Haiku error, and success paths (matches mediaPlayback.resume() pattern)"
  - "coordinator always calls micVolumeService?.maximizeAndSave() and restore() unconditionally — isEnabled guard is inside MicInputVolumeService, not AppCoordinator"

patterns-established:
  - "Volume restore mirrors media resume placement exactly — same line positions in .recording, handleEscape(), and start failure catch block"

requirements-completed: [VOL-03, VOL-06]

# Metrics
duration: 7min
completed: 2026-03-17
---

# Phase 07 Plan 02: Wire MicInputVolumeService into AppCoordinator Summary

**MicInputVolumeService wired into AppCoordinator at all 3 restore paths, Settings toggle added, 8 volume integration tests pass**

## Performance

- **Duration:** 7 min
- **Started:** 2026-03-17T13:37:42Z
- **Completed:** 2026-03-17T13:44:57Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments

- AppCoordinator now calls `micVolumeService?.maximizeAndSave()` after media pause and before `audioRecorder.start()`
- `micVolumeService?.restore()` called at all 3 exit paths: `.recording` case stop, `handleEscape()` cancel, and start failure catch block
- AppDelegate registers `maximizeMicVolumeEnabled: true` default and wires `MicInputVolumeService(microphoneService:)` to coordinator
- SettingsWindowController gains Section 7 "Maximizar volumen al grabar" checkbox with `maximizeMicVolumeEnabled` UserDefaults key, panel height increased to 590
- 8 new AppCoordinator tests cover maximizeAndSave, restore at all exit paths, nil safety, and toggle-off behavior — all pass

## Task Commits

1. **Task 1: Wire MicInputVolumeService into AppCoordinator, AppDelegate, and Settings** - `79f7311` (feat)
2. **Task 2: Add AppCoordinator volume integration tests** - `aea4ffd` (test)

## Files Created/Modified

- `MyWhisper/Coordinator/AppCoordinator.swift` - Added micVolumeService property, maximizeAndSave() before start, restore() at all 3 exit paths
- `MyWhisper/App/AppDelegate.swift` - Added micVolumeService property, instantiation, coordinator injection, UserDefaults default
- `MyWhisper/Settings/SettingsWindowController.swift` - Added Section 7 volume checkbox, action handler, panel height 590
- `MyWhisperTests/AppCoordinatorTests.swift` - Added MockMicInputVolumeService, mockVolume property in setUp, 8 volume test methods

## Decisions Made

- `restore()` placed before `audioRecorder.stop()` in the `.recording` case — this single placement covers all downstream paths (VAD silence, STT error, Haiku error, success), mirroring the same pattern used for `mediaPlayback.resume()`
- Coordinator calls `micVolumeService?.maximizeAndSave()` and `restore()` unconditionally — the `isEnabled` guard lives inside `MicInputVolumeService.maximizeAndSave()`, not in the coordinator

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

Pre-existing flaky test failures in `MenubarControllerTests`, `HaikuCleanupServiceTests`, and `KeychainServiceTests` — confirmed present before this plan's changes (unrelated to volume work, out of scope). All AppCoordinator tests and all 8 new volume tests pass.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- All volume service wiring complete (VOL-03, VOL-06 satisfied)
- 8 tests provide regression coverage for all exit paths
- Ready for phase 08 integration verification

---
*Phase: 07-implementation*
*Completed: 2026-03-17*
