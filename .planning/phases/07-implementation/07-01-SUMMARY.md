---
phase: 07-implementation
plan: 01
subsystem: audio
tags: [coreAudio, volume, HAL, microphone, protocol, DI]

# Dependency graph
requires: []
provides:
  - MicInputVolumeService: CoreAudio HAL volume read/save/maximize/restore service
  - MicInputVolumeServiceProtocol: Protocol for DI injection in AppCoordinator
  - Unit tests for toggle behavior, protocol conformance, and guard-let no-op paths
affects:
  - 07-02 (AppCoordinator wiring uses MicInputVolumeServiceProtocol)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "CoreAudio HAL volume read/write via AudioObjectGetPropertyData/AudioObjectSetPropertyData"
    - "AudioObjectIsPropertySettable guard before every write (never cached)"
    - "resolveActiveDeviceID checks availableInputDevices before using selectedDeviceID"
    - "savedVolume as instance-scoped Float32? (not UserDefaults) to avoid stale-state on crash"

key-files:
  created:
    - MyWhisper/Audio/MicInputVolumeService.swift
    - MyWhisperTests/MicInputVolumeServiceTests.swift
  modified:
    - MyWhisper/Coordinator/AppCoordinatorDependencies.swift
    - MyWhisper.xcodeproj/project.pbxproj

key-decisions:
  - "savedVolume stored as instance-scoped Float32? not UserDefaults - avoids stale state on crash/relaunch"
  - "restore() does NOT guard on isEnabled - if maximized before toggle-off, must still restore"
  - "resolveActiveDeviceID calls availableInputDevices() at every call, never caches at startup (VOL-05)"
  - "AudioObjectIsPropertySettable checked on every setVolume call, never cached (VOL-04)"
  - "Uses kAudioObjectPropertyElementMain (not deprecated kAudioObjectPropertyElementMaster)"

patterns-established:
  - "Protocol-backed service mirroring MediaPlaybackServiceProtocol: AnyObject pattern"
  - "isEnabled reads live from UserDefaults.standard (same pattern as MediaPlaybackService)"

requirements-completed: [VOL-01, VOL-02, VOL-04, VOL-05]

# Metrics
duration: 9min
completed: 2026-03-17
---

# Phase 7 Plan 01: MicInputVolumeService Summary

**CoreAudio HAL mic input volume service with settability guard, device-validity check, and DI protocol — foundation for AppCoordinator volume wiring in Plan 02**

## Performance

- **Duration:** ~9 min
- **Started:** 2026-03-17T12:50:17Z
- **Completed:** 2026-03-17T12:59:00Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments
- MicInputVolumeService created with CoreAudio HAL volume read/save/maximize/restore capability
- MicInputVolumeServiceProtocol added to AppCoordinatorDependencies.swift for DI injection
- AudioObjectIsPropertySettable guard in setVolume ensures silent no-op on non-settable devices (VOL-04)
- resolveActiveDeviceID validates device still in availableInputDevices() before using it (VOL-05)
- 7 unit tests added covering toggle behavior, protocol conformance, and no-op guard paths

## Task Commits

Each task was committed atomically:

1. **Task 1: Define MicInputVolumeServiceProtocol and create MicInputVolumeService** - `b550da1` (feat)
2. **Task 2: Add MicInputVolumeService unit tests** - `0a5277f` (test)

## Files Created/Modified
- `MyWhisper/Audio/MicInputVolumeService.swift` - CoreAudio HAL volume service implementing MicInputVolumeServiceProtocol
- `MyWhisper/Coordinator/AppCoordinatorDependencies.swift` - Added MicInputVolumeServiceProtocol definition
- `MyWhisperTests/MicInputVolumeServiceTests.swift` - 7 unit tests for toggle, conformance, and guard paths
- `MyWhisper.xcodeproj/project.pbxproj` - Registered both new Swift files in app and test targets

## Decisions Made
- savedVolume stored as instance-scoped `Float32?` not UserDefaults - avoids stale state risk on crash/relaunch
- `restore()` does NOT guard on `isEnabled` — if volume was maximized before toggle was turned off, restore must still fire
- `resolveActiveDeviceID()` called fresh at both maximize and restore time — no app-launch caching (VOL-05)
- `AudioObjectIsPropertySettable` checked every `setVolume()` call — device capability can change (VOL-04)
- `kAudioObjectPropertyElementMain` used throughout (not deprecated `kAudioObjectPropertyElementMaster`)

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

Git stash (from pre-existing validation) temporarily reverted `AppCoordinatorDependencies.swift` and `project.pbxproj` during test verification. Changes were re-applied manually. All file contents verified correct before committing.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- MicInputVolumeService.swift is ready for Plan 02 to wire into AppCoordinator via `var micVolumeService: (any MicInputVolumeServiceProtocol)?`
- Protocol defined at correct location in AppCoordinatorDependencies.swift
- AppDelegate registration of `maximizeMicVolumeEnabled` default still needed (Plan 02 scope)

---
*Phase: 07-implementation*
*Completed: 2026-03-17*
