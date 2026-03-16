---
phase: 04-settings-history-and-polish
plan: 02
subsystem: ui
tags: [AppKit, NSPanel, NSTableView, NSPopUpButton, KeyboardShortcuts, ServiceManagement, CoreAudio]

# Dependency graph
requires:
  - phase: 04-01-services-foundation
    provides: VocabularyService, TranscriptionHistoryService, MicrophoneDeviceService, KeyboardShortcuts dependency
  - phase: 03-haiku-cleanup
    provides: APIKeyWindowController, HaikuCleanupProtocol

provides:
  - SettingsWindowController: single-panel NSPanel with hotkey recorder, mic selector, API key button, vocab table, launch-at-login
  - HistoryWindowController: NSTableView with transcription history, click-to-copy, clear button
  - AudioRecorder.microphoneService: applies selected device before engine.start()

affects: [any future UI panels, testing UI panels]

# Tech tracking
tech-stack:
  added: []
  patterns: [NSPanel window controller pattern (show/reuse), NSTableViewDataSource/Delegate inline on controller, CoreAudio device selection before engine.start()]

key-files:
  created:
    - MyWhisper/Settings/SettingsWindowController.swift
    - MyWhisper/History/HistoryWindowController.swift
  modified:
    - MyWhisper/UI/StatusMenuView.swift
    - MyWhisper/Audio/AudioRecorder.swift
    - MyWhisper/App/AppDelegate.swift
    - MyWhisper.xcodeproj/project.pbxproj

key-decisions:
  - "SettingsWindowController creates its own APIKeyWindowController internally — avoids passing it from AppDelegate which already owns one"
  - "NSPopUpButton tag stores AudioDeviceID as Int; tag=-1 means system default (selectedDeviceID=nil)"
  - "HistoryWindowController.show() calls refresh() on re-open to pick up new entries without recreating the panel"
  - "Date.historyDisplayString uses RelativeDateTimeFormatter for <24h, DateFormatter for older entries — Spanish locale throughout"

patterns-established:
  - "Window controller pattern: check for existing panel first (makeKeyAndOrderFront+return), create on first call, nil on windowWillClose"
  - "NSApp.setActivationPolicy(.regular) before makeKeyAndOrderFront, .accessory in windowWillClose"

requirements-completed: [REC-05, MAC-04, OUT-03, OUT-04]

# Metrics
duration: 9min
completed: 2026-03-16
---

# Phase 4 Plan 02: Settings and History Windows Summary

**NSPanel Settings window (hotkey recorder, mic dropdown, API key, vocab table, launch-at-login) and History window (click-to-copy transcriptions) wired into menubar via StatusMenuController; microphone selection applied to AudioRecorder before engine.start()**

## Performance

- **Duration:** 9 min
- **Started:** 2026-03-16T13:15:22Z
- **Completed:** 2026-03-16T13:24:19Z
- **Tasks:** 2
- **Files modified:** 6

## Accomplishments
- SettingsWindowController with all 5 sections: KeyboardShortcuts.RecorderCocoa for hotkey, NSPopUpButton for mic selection, API key button delegating to APIKeyWindowController, editable NSTableView for vocabulary corrections, SMAppService checkbox for launch at login
- HistoryWindowController with NSTableView, click-to-copy to NSPasteboard.general, NotificationHelper "Texto copiado", deselect-after-copy for re-clicking, clear button, Spanish-locale relative date formatting
- AudioRecorder.microphoneService property wires mic device selection before engine.start()
- StatusMenuController updated: Historial item added, standalone Clave de API item removed (moved to Settings panel)

## Task Commits

1. **Task 1: SettingsWindowController + StatusMenuController wiring** - `1a5daee` (feat)
2. **Task 2: HistoryWindowController + AudioRecorder mic selection** - `dd20864` (feat)

## Files Created/Modified
- `MyWhisper/Settings/SettingsWindowController.swift` - New: single-panel Settings NSPanel with all 5 sections
- `MyWhisper/History/HistoryWindowController.swift` - New: History NSPanel with NSTableView, click-to-copy, Date extension
- `MyWhisper/UI/StatusMenuView.swift` - Updated: adds Historial item, removes Clave de API, wires Settings/History controllers
- `MyWhisper/Audio/AudioRecorder.swift` - Updated: microphoneService property + setInputDevice before engine.start()
- `MyWhisper/App/AppDelegate.swift` - Updated: creates HistoryWindowController, wires mic to recorder, wires both to StatusMenuController
- `MyWhisper.xcodeproj/project.pbxproj` - Updated: Settings group, HistoryWindowController added to History group, both in Sources build phase

## Decisions Made
- SettingsWindowController creates its own APIKeyWindowController internally rather than receiving it from AppDelegate — cleaner ownership since Settings owns that button
- NSPopUpButton tag stores AudioDeviceID as Int (tag=-1 = system default, nil selectedDeviceID)
- HistoryWindowController reuses existing panel on re-open and calls refresh() to reload table data
- Date.historyDisplayString uses RelativeDateTimeFormatter for entries <24h old, DateFormatter for older entries, both with Spanish locale

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed UserDefaults.suiteName compilation errors in test tearDown**
- **Found during:** Task 2 (running xcodebuild test)
- **Issue:** `UserDefaults.suiteName` property does not exist in macOS SDK — test tearDown in VocabularyServiceTests, TranscriptionHistoryServiceTests, MicrophoneDeviceServiceTests all failed to compile
- **Fix:** Store suite name in a separate `suiteName: String!` property set in setUp, use it directly in `removePersistentDomain(forName:)`
- **Files modified:** MyWhisperTests/VocabularyServiceTests.swift, MyWhisperTests/TranscriptionHistoryServiceTests.swift, MyWhisperTests/MicrophoneDeviceServiceTests.swift
- **Verification:** All 17 affected tests now compile and pass
- **Committed in:** dd20864 (Task 2 commit)

**2. [Rule 3 - Blocking] Added CoreAudio import to SettingsWindowController**
- **Found during:** Task 1 (first build attempt)
- **Issue:** `AudioDeviceID` type not in scope — CoreAudio not imported
- **Fix:** Added `import CoreAudio` to SettingsWindowController.swift
- **Files modified:** MyWhisper/Settings/SettingsWindowController.swift
- **Verification:** Build passes
- **Committed in:** 1a5daee (Task 1 commit)

---

**Total deviations:** 2 auto-fixed (1 bug, 1 blocking import)
**Impact on plan:** Both auto-fixes necessary for compilation. No scope creep.

## Issues Encountered
- Pre-existing test failures in KeychainServiceTests, MenubarControllerTests, HaikuCleanupServiceTests are out of scope and not caused by this plan's changes

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- All Phase 4 features are now functional: hotkey, microphone selection, vocabulary corrections, history, API key management
- Phase 4 is complete — all plans in 04-settings-history-and-polish finished
- App is feature-complete for v1.0 milestone

---
*Phase: 04-settings-history-and-polish*
*Completed: 2026-03-16*

## Self-Check: PASSED
- SettingsWindowController.swift: FOUND
- HistoryWindowController.swift: FOUND
- 04-02-SUMMARY.md: FOUND
- Commit 1a5daee: FOUND
- Commit dd20864: FOUND
