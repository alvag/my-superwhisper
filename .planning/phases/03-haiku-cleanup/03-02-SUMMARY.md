---
phase: 03-haiku-cleanup
plan: 02
subsystem: coordinator-integration
tags: [haiku, coordinator, apidelegate, modal, nspanel, appkit, testing]

# Dependency graph
requires:
  - phase: 03-haiku-cleanup plan: 01
    provides: HaikuCleanupProtocol, HaikuCleanupService, HaikuCleanupError
  - phase: 02-audio-transcription plan: 03
    provides: AppCoordinator with STT pipeline
provides:
  - APIKeyWindowController: NSPanel modal for API key entry with validation
  - AppCoordinator: full record->STT->Haiku->paste pipeline with error fallback
  - StatusMenuController: "Clave de API..." menu item
  - AppDelegate: HaikuCleanupService wiring
  - 4 new coordinator integration tests with MockHaikuCleanup
affects: [04-polish]

# Tech tracking
tech-stack:
  added: [NSPanel, NSSecureTextField, NSLayoutConstraint auto-layout, NSObject inheritance for @objc selectors]
  patterns: [MainActor NSPanel lifecycle with activation policy toggle, Task { @MainActor } for @objc method isolation, optional chaining for nil haikuCleanup fallback]

key-files:
  created:
    - MyWhisper/UI/APIKeyWindowController.swift
  modified:
    - MyWhisper/UI/StatusMenuView.swift
    - MyWhisper/Coordinator/AppCoordinator.swift
    - MyWhisper/App/AppDelegate.swift
    - MyWhisperTests/AppCoordinatorTests.swift
    - MyWhisper.xcodeproj/project.pbxproj

key-decisions:
  - "StatusMenuController inherits NSObject to support @objc selectors for NSMenuItem.target actions"
  - "openAPIKeyPanel wrapped in Task { @MainActor } because @objc methods are nonisolated — APIKeyWindowController requires @MainActor"
  - "API key gate runs before audioRecorder.start() in idle case — prevents recording without a working key"
  - "authFailed and noAPIKey set apiKeyMarkedInvalid=true — triggers modal on next hotkey press instead of blocking immediately"
  - "haikuCleanup = nil treated as no-op (paste raw) — preserves backward compat for tests without Haiku wired"

requirements-completed: [PRV-03, PRV-04, CLN-01, CLN-02, CLN-03, CLN-04, CLN-05]

# Metrics
duration: ~6min
completed: 2026-03-16
---

# Phase 03 Plan 02: Coordinator Integration Summary

**AppCoordinator wired with HaikuCleanupService for full record->STT->Haiku->paste pipeline, NSPanel API key modal with NSSecureTextField, "Clave de API..." menu item, and 4 integration tests with MockHaikuCleanup**

## Performance

- **Duration:** ~6 min
- **Started:** 2026-03-16
- **Completed:** 2026-03-16
- **Tasks:** 2 of 2 complete
- **Files created/modified:** 6

## Accomplishments

- `APIKeyWindowController` NSPanel at 400x180 with:
  - `NSSecureTextField` for masked key input
  - `NSButton "Guardar"` with save action (validates via `haikuCleanup.saveAPIKey`)
  - Status label for "Validando..." and error messages
  - `NSApp.setActivationPolicy(.regular)` on show / `.accessory` on close via `NSWindowDelegate`
  - Prevents double-open: reuses existing panel if already visible
- `StatusMenuController` updated:
  - Inherits `NSObject` for `@objc` selector support
  - New `haikuCleanup` property + updated `init(coordinator:haikuCleanup:)` (default nil)
  - "Clave de API..." menu item before "Preferencias..."
  - `openAPIKeyPanel` dispatches via `Task { @MainActor }` (fixes nonisolated @objc context)
- `AppCoordinator` updated:
  - `haikuCleanup`, `apiKeyWindowController`, `apiKeyMarkedInvalid` properties
  - API key gate in `.idle` case: checks `hasAPIKey`, shows modal if missing or `apiKeyMarkedInvalid`
  - `.recording` case: `haiku.clean(rawText)` after STT, fallback to `rawText` on any `HaikuCleanupError`
  - `authFailed`/`noAPIKey` sets `apiKeyMarkedInvalid = true` (modal on next attempt)
  - All other errors show "Texto pegado sin limpiar / Error de conexion" notification
- `AppDelegate` updated:
  - Creates `HaikuCleanupService()` and `APIKeyWindowController(haikuCleanup:)`
  - Wires both into coordinator
  - Passes `haikuCleanup` to `StatusMenuController`
- `AppCoordinatorTests` updated:
  - `MockHaikuCleanup` with `mockCleanedText`, `shouldThrow`, `cleanCalled`, `hasAPIKeyValue`
  - `mockHaiku` wired in `setUp` with `hasAPIKeyValue = true`
  - 4 new integration tests: `testHaikuCleanupCalledAfterTranscription`, `testHaikuAuthFailurePastesRawText`, `testHaikuNetworkErrorPastesRawText`, `testNilHaikuCleanupPastesRawText`
  - `speechBuffer()` helper extracted; inline buffers replaced across all tests
  - `testHotkeyStopsRecordingTranscribesAndPastes` updated to verify cleaned text

## Task Commits

1. **Task 1: APIKeyWindowController + StatusMenuController** - `0d8d468` (feat)
2. **Task 2: AppCoordinator + AppDelegate + Tests** - `de7a292` (feat)

## Files Created/Modified

- `MyWhisper/UI/APIKeyWindowController.swift` — NSPanel modal for API key entry (new)
- `MyWhisper/UI/StatusMenuView.swift` — NSObject inheritance, haikuCleanup property, Clave de API menu item
- `MyWhisper/Coordinator/AppCoordinator.swift` — Haiku pipeline integration with fallback
- `MyWhisper/App/AppDelegate.swift` — HaikuCleanupService creation and coordinator wiring
- `MyWhisperTests/AppCoordinatorTests.swift` — MockHaikuCleanup + 4 integration tests
- `MyWhisper.xcodeproj/project.pbxproj` — APIKeyWindowController.swift registered in UI group + Sources

## Decisions Made

- `StatusMenuController: NSObject` — required for `@objc` NSMenuItem target selectors; previously omitted since menu used first-responder chain
- `Task { @MainActor }` wrapper in `openAPIKeyPanel` — `@objc` methods are implicitly `nonisolated`, so direct call to `@MainActor` init fails
- API key gate position (before `audioRecorder.start()`) — avoids recording audio that will be discarded if no key available
- `apiKeyMarkedInvalid` flag deferred to next hotkey press — avoids disrupting in-flight recording if auth error surfaces during cleanup

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing critical functionality] @objc nonisolated context for openAPIKeyPanel**
- **Found during:** Task 1 (xcodebuild test)
- **Issue:** `openAPIKeyPanel` is `@objc` and therefore `nonisolated`; direct call to `@MainActor init(haikuCleanup:)` fails with "call to main actor-isolated initializer in a synchronous nonisolated context"
- **Fix:** Wrapped body in `Task { @MainActor in ... }` to dispatch to main actor
- **Files modified:** MyWhisper/UI/StatusMenuView.swift
- **Commit:** de7a292

## Issues Encountered

- `swift test` does not find tests (project uses Xcode target, not SPM test conventions). Verification uses `xcodebuild build-for-testing` — pre-existing constraint. Test execution with real signing requires Xcode.

## Next Phase Readiness

- End-to-end pipeline complete: hotkey -> record -> STT -> Haiku cleanup -> paste
- All error paths (auth, network, rate limit, server error) fall back to raw text
- API key management UI accessible from menubar dropdown
- Phase 04 (polish) can build on top without coordinator changes

---
*Phase: 03-haiku-cleanup*
*Completed: 2026-03-16*

## Self-Check: PASSED

- FOUND: MyWhisper/UI/APIKeyWindowController.swift
- FOUND: MyWhisper/UI/StatusMenuView.swift (contains StatusMenuController with haikuCleanup)
- FOUND: MyWhisper/Coordinator/AppCoordinator.swift (contains haikuCleanup integration)
- FOUND: MyWhisper/App/AppDelegate.swift (contains HaikuCleanupService() and wiring)
- FOUND: MyWhisperTests/AppCoordinatorTests.swift (contains MockHaikuCleanup and 4 new tests)
- FOUND: .planning/phases/03-haiku-cleanup/03-02-SUMMARY.md
- FOUND: commit 0d8d468 (feat(03-02): APIKeyWindowController + StatusMenuController)
- FOUND: commit de7a292 (feat(03-02): Haiku wiring + tests)
