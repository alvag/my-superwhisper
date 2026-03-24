---
phase: 09-window-lifecycle-foundation
plan: 02
subsystem: settings-ui
tags: [appkit, nswindow, nshostingcontroller, swiftui, activation-policy, lifecycle]
dependency_graph:
  requires:
    - phase: 09-01
      provides: "SettingsViewModel (@Observable) and SettingsView (SwiftUI Form) used as NSHostingController content"
  provides:
    - "SettingsWindowController rewritten: NSWindow + NSHostingController hosting SettingsView"
    - "Activation policy lifecycle: .regular on show, .accessory on windowShouldClose"
    - "NSApp.hide(nil) for focus restoration to previous app"
    - "windowShouldClose returning false + orderOut(nil) for instance preservation"
  affects:
    - "10-settings-full-ui — uses SettingsWindowController.show() and SettingsView expansion"
tech_stack:
  added: []
  patterns:
    - "NSWindow(contentViewController: NSHostingController) for SwiftUI hosting in menubar-only app"
    - "setActivationPolicy(.regular/.accessory) toggle pattern for show/close cycle"
    - "windowShouldClose returning false + orderOut(nil) to hide without destroying instance"
    - "NSApp.hide(nil) after .accessory restore to return focus to previous app"
key_files:
  created: []
  modified:
    - MyWhisper/Settings/SettingsWindowController.swift
key_decisions:
  - "NSWindow instead of NSPanel: NSWindow has no hidesOnDeactivate, resolves WIN-01 (window stays open on click-outside)"
  - "windowShouldClose returning false + orderOut(nil) instead of windowWillClose: preserves window instance for re-show without recreating"
  - "NSApp.hide(nil) in windowShouldClose: returns focus to previously active app (WIN-03)"
  - "viewModel.openAPIKey closure wired in init after super.init(): decouples SettingsView from AppKit"
requirements-completed: [WIN-01, WIN-02, WIN-03, WIN-04]
duration: ~1min
completed: "2026-03-24"
---

# Phase 9 Plan 02: SettingsWindowController NSWindow Rewrite Summary

**NSPanel replaced with NSWindow + NSHostingController in 56 lines — activation policy lifecycle enables dock icon, keyboard input, and focus restoration.**

## Performance

- **Duration:** ~1 min
- **Started:** 2026-03-24T16:07:12Z
- **Completed:** 2026-03-24T16:08:06Z
- **Tasks:** 1 of 2 completed (Task 2 is human-verify checkpoint)
- **Files modified:** 1

## Accomplishments

- Rewrote SettingsWindowController from 305 lines of AppKit imperative UI to 56 lines of NSWindow + NSHostingController
- Removed all NSTableView, NSLayoutConstraint, NSPopUpButton, NSCheckbox, @objc handlers
- Implemented activation policy lifecycle: `.regular` on show, `.accessory` in windowShouldClose
- Added `NSApp.hide(nil)` for WIN-03 focus restoration (was missing from original)
- Used `windowShouldClose` returning `false` + `orderOut(nil)` to preserve window instance across close/reopen

## Task Commits

1. **Task 1: Reescribir SettingsWindowController** - `c4945a7` (feat)

## Files Created/Modified

- `MyWhisper/Settings/SettingsWindowController.swift` - Complete rewrite: NSPanel -> NSWindow + NSHostingController, 56 lines

## Decisions Made

- NSWindow (not NSPanel): NSPanel has `hidesOnDeactivate = true` by default — this is the root cause of WIN-01. NSWindow does not have this behavior.
- `windowShouldClose` returning false + `orderOut(nil)`: Hides window but keeps instance alive, enabling re-show without re-creating NSHostingController (avoids SettingsView state loss).
- `NSApp.hide(nil)` placement after `.accessory` restore: Required for WIN-03 — without it, the app lingers in the foreground even after policy change.
- Init creates `SettingsViewModel` internally: Matches original constructor signature `init(vocabularyService:microphoneService:haikuCleanup:)` so StatusMenuController requires no changes.

## Deviations from Plan

None - plan executed exactly as written. Code matches the plan's Swift blueprint verbatim.

## Issues Encountered

- **Worktree missing Plan 01 files:** The worktree branch `worktree-agent-a1da63ee` did not have `SettingsViewModel.swift` or `SettingsView.swift` (created by Plan 01 agent on `gsd/v1.3-settings-ux`). Resolved by merging `gsd/v1.3-settings-ux` into worktree before Task 1. No code conflict.

## Checkpoint Pending

Task 2 (`checkpoint:human-verify`) requires manual verification of 5 window lifecycle scenarios:
- WIN-01: Click outside does not close Settings
- WIN-02: X button and Cmd+W close Settings
- WIN-03: Dock icon appears/disappears, focus returns to previous app
- WIN-04: Keyboard input works in hotkey recorder
- Re-open without duplicates

## Next Phase Readiness

- SettingsWindowController rewrite complete and compiled
- Ready for human verification of window lifecycle behavior
- Phase 10 can expand SettingsView with remaining settings (mic selector, API key, vocabulary, launch at login, maximize volume)

## Known Stubs

None.

## Self-Check: PASSED
- `MyWhisper/Settings/SettingsWindowController.swift`: FOUND
- Commit c4945a7: FOUND (feat(09-02): rewrite SettingsWindowController)
- Line count 56: FOUND (< 80 lines)
- No NSPanel: FOUND
- No NSTableView: FOUND
- No NSLayoutConstraint: FOUND
- BUILD SUCCEEDED: CONFIRMED

---
*Phase: 09-window-lifecycle-foundation*
*Completed: 2026-03-24*
