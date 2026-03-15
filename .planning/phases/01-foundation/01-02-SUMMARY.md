---
phase: 01-foundation
plan: 02
subsystem: permissions
tags: [swift, macos, accessibility, microphone, TCC, swiftui, appkit, xcode]

# Dependency graph
requires:
  - phase: 01-01
    provides: AppDelegate scaffold, AppCoordinator FSM, HotkeyMonitor, MenubarController
provides:
  - PermissionsManager with protocol-injected dependencies and health check logic
  - PermissionBlockedView SwiftUI blocking screen with Open System Settings button
  - AppDelegate permission health check guard on every launch
affects:
  - 01-03 (TextInjector will call requestAccessibility() before first paste)
  - future phases needing permission status

# Tech tracking
tech-stack:
  added: []
  patterns:
    - Protocol-injected dependency pattern for testable TCC access (PermissionsChecking protocol)
    - On-the-fly permission requesting vs. launch health check split pattern
    - NSHostingView-wrapped SwiftUI view in NSWindow for blocking modal

key-files:
  created:
    - MyWhisper/System/PermissionsManager.swift
    - MyWhisper/UI/PermissionBlockedView.swift
    - MyWhisperTests/PermissionsManagerTests.swift
  modified:
    - MyWhisper/App/AppDelegate.swift
    - MyWhisper.xcodeproj/project.pbxproj

key-decisions:
  - "PermissionsChecking protocol with SystemPermissionsChecker default allows unit testing health check logic without touching real TCC"
  - "checkAllOnLaunch checks accessibility first, then microphone — accessibility is higher priority since it blocks paste entirely"
  - "notDetermined microphone status is treated as .ok at launch — permission requested on-the-fly on first recording, not blocking"
  - "App switches to .regular activation policy when blocking screen shown — required for user to interact with the window"
  - "Phase 1 simplest approach: no live permission polling — user must restart app after granting permissions"

patterns-established:
  - "Pattern: Protocol injection for system APIs — wrap AXIsProcessTrusted/AVCaptureDevice behind PermissionsChecking for testability"
  - "Pattern: Guard pattern in applicationDidFinishLaunching — return early when blocked, preventing hotkey/menubar setup"

requirements-completed: [MAC-02, MAC-03, PRV-02]

# Metrics
duration: 4min
completed: 2026-03-15
---

# Phase 1 Plan 02: PermissionsManager and Blocking Screen Summary

**TCC health check with protocol-injected PermissionsManager, SwiftUI blocking screen, and AppDelegate launch guard preventing hotkey setup when Accessibility or Microphone is denied**

## Performance

- **Duration:** 4 min
- **Started:** 2026-03-15T20:54:28Z
- **Completed:** 2026-03-15T20:58:28Z
- **Tasks:** 2
- **Files modified:** 5

## Accomplishments
- PermissionsManager with `PermissionsChecking` protocol — all 6 unit tests pass without touching real TCC
- PermissionBlockedView SwiftUI screen with correct Spanish explanations and "Abrir Configuración del Sistema" button
- AppDelegate.applicationDidFinishLaunching now runs permission health check first — returns early (no hotkey/menubar) when blocked
- All new files registered in Xcode project.pbxproj (System/UI/Tests groups and build phases)

## Task Commits

Each task was committed atomically:

1. **Task 1: PermissionsManager with health check and on-the-fly request logic** - `c7ccbcb` (feat + test, TDD)
2. **Task 2: PermissionBlockedView SwiftUI screen and AppDelegate launch wiring** - `cd99aea` (feat)

## Files Created/Modified
- `MyWhisper/System/PermissionsManager.swift` - PermissionsChecking protocol, SystemPermissionsChecker, PermissionsManager with checkAllOnLaunch/requestMicrophone/requestAccessibility/openSystemSettings
- `MyWhisper/UI/PermissionBlockedView.swift` - SwiftUI blocking screen with icon, title, explanation, and "Abrir Configuración del Sistema" button for both permission types
- `MyWhisperTests/PermissionsManagerTests.swift` - 6 unit tests using MockPermissionsChecker struct (no system calls)
- `MyWhisper/App/AppDelegate.swift` - Added permission health check guard, showPermissionBlockedWindow helper, permissionsManager property
- `MyWhisper.xcodeproj/project.pbxproj` - Registered PermissionsManager.swift, PermissionBlockedView.swift, PermissionsManagerTests.swift in project

## Decisions Made
- Used `PermissionsChecking` protocol instead of subclassing for dependency injection — structs are sufficient and cleaner for test mocks
- `notDetermined` microphone status treated as `.ok` at launch — consistent with on-the-fly requesting pattern (permission asked when recording first starts)
- No live permission polling in Phase 1 — user restarts app after granting permission, simplest correct approach

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Added new files to Xcode project.pbxproj**
- **Found during:** Task 2 (build verification)
- **Issue:** PermissionsManager.swift and PermissionBlockedView.swift were created as disk files but not registered in the Xcode project target — build failed with "cannot find type 'PermissionsManager' in scope"
- **Fix:** Added PBXBuildFile, PBXFileReference entries and updated PBXGroup and PBXSourcesBuildPhase sections in project.pbxproj for all 3 new Swift files
- **Files modified:** MyWhisper.xcodeproj/project.pbxproj
- **Verification:** `xcodebuild build` exits 0 after changes
- **Committed in:** cd99aea (Task 2 commit)

---

**Total deviations:** 1 auto-fixed (1 blocking — Xcode project registration)
**Impact on plan:** Necessary infrastructure fix. The plan specified file creation but omitted the Xcode project registration step. No scope creep.

## Issues Encountered
- PermissionsManagerTests initially appeared to "pass" without running individual tests — this was because PermissionsManager types didn't exist yet and the build was cached. After adding PermissionsManager.swift and registering files in the project, all 6 tests ran and passed with individual test case output visible.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Plan 01-03 (TextInjector + AudioRecorder stub) can now proceed
- Plan 01-03 should call `permissionsManager.requestAccessibility()` before first paste attempt
- On-the-fly permission requesting methods (`requestMicrophone()`, `requestAccessibility()`) are ready for Plan 01-03 to wire into the recording/paste flow

---
*Phase: 01-foundation*
*Completed: 2026-03-15*
