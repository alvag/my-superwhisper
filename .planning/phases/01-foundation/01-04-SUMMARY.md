---
phase: 01-foundation
plan: 04
subsystem: permissions
tags: [swift, avfoundation, permissions, tdd, protocol, microphone]

# Dependency graph
requires:
  - phase: 01-foundation plan 02
    provides: PermissionsManager with requestMicrophone() async -> Bool implementation
  - phase: 01-foundation plan 01
    provides: AppCoordinator FSM and handleHotkey() structure
provides:
  - PermissionsManaging protocol (AnyObject) in PermissionsManager.swift
  - AppCoordinator.permissionsManager weak property (any PermissionsManaging)?
  - On-the-fly mic permission check in handleHotkey() case .idle
  - AppDelegate wires coordinator.permissionsManager = permissionsManager
affects: [02-recording, 03-transcription]

# Tech tracking
tech-stack:
  added: []
  patterns: [protocol-for-testability, weak-injection, tdd-red-green]

key-files:
  created: []
  modified:
    - MyWhisper/System/PermissionsManager.swift
    - MyWhisper/Coordinator/AppCoordinator.swift
    - MyWhisper/App/AppDelegate.swift
    - MyWhisperTests/AppCoordinatorTests.swift

key-decisions:
  - "PermissionsManaging protocol placed in PermissionsManager.swift (not AppCoordinator.swift) to keep protocol near its implementation"
  - "weak var permissionsManager: (any PermissionsManaging)? prevents retain cycle since AppDelegate owns PermissionsManager strongly"
  - "nil permissionsManager guard preserves backward compatibility — existing unit tests with no permissionsManager set still reach .recording"

patterns-established:
  - "Protocol extraction for testability: concrete final class + protocol + mock in tests (PermissionsManaging pattern)"
  - "Weak injection for non-owning coordinator dependencies"

requirements-completed: [MAC-02]

# Metrics
duration: 4min
completed: 2026-03-15
---

# Phase 1 Plan 4: On-the-Fly Mic Permission Wiring Summary

**PermissionsManaging protocol extracted, requestMicrophone() wired into AppCoordinator.handleHotkey() case .idle, closing the MAC-02 on-the-fly permission path with 3 new TDD tests (21 total, all green)**

## Performance

- **Duration:** 4 min
- **Started:** 2026-03-15T21:17:17Z
- **Completed:** 2026-03-15T21:21:00Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments
- Extracted PermissionsManaging protocol from PermissionsManager for testability (Option A from plan)
- Wired on-the-fly mic request in AppCoordinator.handleHotkey() case .idle: denied -> .error("microphone"), nil -> .recording (backward compat)
- AppDelegate now assigns coordinator.permissionsManager = permissionsManager in dependency wiring block
- 3 new tests: denied->error, granted->recording, nil->recording; all 21 tests pass

## Task Commits

Each task was committed atomically:

1. **Task 1: Add permissionsManager to AppCoordinator and wire on-the-fly mic request** - `ca03b44` (feat)
2. **Task 2: Wire coordinator.permissionsManager in AppDelegate** - `5adadc2` (feat)

**Plan metadata:** (docs commit — see below)

_Note: TDD tasks may have multiple commits (test -> feat -> refactor). Task 1 used TDD: RED (build failure confirmed), then GREEN (all 7 tests pass)._

## Files Created/Modified
- `MyWhisper/System/PermissionsManager.swift` - Added PermissionsManaging protocol + extension PermissionsManager: PermissionsManaging {}
- `MyWhisper/Coordinator/AppCoordinator.swift` - Added weak var permissionsManager + permission check in handleHotkey() case .idle
- `MyWhisper/App/AppDelegate.swift` - Added coordinator.permissionsManager = permissionsManager in wiring block
- `MyWhisperTests/AppCoordinatorTests.swift` - Added MockPermissionsManaging + 3 new test methods

## Decisions Made
- PermissionsManaging protocol placed in PermissionsManager.swift (not AppCoordinator.swift) to keep protocol near its implementation
- weak var permissionsManager prevents retain cycle: AppDelegate owns PermissionsManager strongly, AppCoordinator holds weak ref
- nil guard preserves existing test behavior — tests that don't set permissionsManager still proceed to .recording

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- MAC-02 is now fully satisfied: health-check blocking path (launch) + on-the-fly path (first hotkey press) both wired
- Phase 1 gap closure complete — all 01-foundation plans executed
- 21 unit tests all passing, build succeeds
- Ready for Phase 2 recording implementation

---
*Phase: 01-foundation*
*Completed: 2026-03-15*
