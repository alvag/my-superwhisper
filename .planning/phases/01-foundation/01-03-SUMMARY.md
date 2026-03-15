---
phase: 01-foundation
plan: 03
subsystem: ui
tags: [swift, swiftui, appkit, avfoundation, coregraphics, nspasteboard, cgeventpost, nspanal, avaudioengine]

# Dependency graph
requires:
  - phase: 01-foundation plan 01
    provides: AppCoordinator FSM with AudioRecorderProtocol, TextInjectorProtocol, OverlayWindowControllerProtocol injection points
  - phase: 01-foundation plan 02
    provides: PermissionsManager for on-the-fly accessibility/microphone requests
provides:
  - TextInjector: NSPasteboard write + CGEventPost Cmd+V with 150ms delay and keycode 0x09
  - AudioRecorder: AVAudioEngine stub that starts/stops/cancels with installTap discarding all audio
  - OverlayWindowController: NSPanel with .nonactivatingPanel floating above all windows
  - OverlayView: SwiftUI 5-bar waveform placeholder with .repeatForever looping animation
  - AppDelegate: fully wired with all 5 coordinator dependencies injected
  - Complete Phase 1 end-to-end flow: Option+Space -> overlay + mic LED -> Option+Space -> "Texto de prueba" pasted at cursor
affects: [02-stt, 03-cleanup, 04-settings]

# Tech tracking
tech-stack:
  added: [AVFoundation (AudioRecorder stub), CoreGraphics (CGEventPost), ApplicationServices (AXIsProcessTrusted)]
  patterns: [CGEventPost Cmd+V paste simulation with 150ms race-condition delay, NSPanel .nonactivatingPanel overlay, AVAudioEngine installTap with empty closure for mic LED without audio processing]

key-files:
  created:
    - MyWhisper/System/TextInjector.swift
    - MyWhisper/Audio/AudioRecorder.swift
    - MyWhisper/UI/OverlayWindowController.swift
    - MyWhisper/UI/OverlayView.swift
    - MyWhisperTests/TextInjectorTests.swift
    - MyWhisperTests/AudioRecorderTests.swift
  modified:
    - MyWhisper/App/AppDelegate.swift
    - MyWhisper.xcodeproj/project.pbxproj

key-decisions:
  - "orderFront(nil) not makeKeyAndOrderFront(nil) for NSPanel overlay — prevents focus steal from target app which would break paste"
  - "AudioRecorder actually starts AVAudioEngine against real mic (validates permission flow + triggers mic LED) rather than simulating state only"
  - "TextInjector falls through clipboard-only path if permissionsManager is nil (enables unit testing without permission check)"
  - "150ms delay between NSPasteboard.setString and CGEventPost to prevent race condition where target app reads stale clipboard"

patterns-established:
  - "Pattern: NSPanel overlay uses [.borderless, .nonactivatingPanel] + [.canJoinAllSpaces, .fullScreenAuxiliary] for full-screen app support"
  - "Pattern: CGEventPost paste uses keycode 0x09 (V), .maskCommand flags, .cgSessionEventTap tap location"
  - "Pattern: AVAudioEngine installTap with empty closure body for hardware validation without audio processing"

requirements-completed: [OUT-01, OUT-02, REC-01, REC-04, PRV-01, PRV-02]

# Metrics
duration: 3min
completed: 2026-03-15
---

# Phase 1 Plan 03: TextInjector, AudioRecorder stub, OverlayWindowController, and full AppDelegate wiring Summary

**NSPasteboard+CGEventPost paste simulation, AVAudioEngine stub with mic LED, NSPanel non-activating overlay, and complete Phase 1 end-to-end flow wired in AppDelegate**

## Performance

- **Duration:** 3 min
- **Started:** 2026-03-15T21:01:27Z
- **Completed:** 2026-03-15T21:04:56Z
- **Tasks:** 2
- **Files modified:** 8

## Accomplishments
- TextInjector writes to NSPasteboard.general and simulates Cmd+V via CGEventPost (keycode 0x09, .maskCommand, .cgSessionEventTap) with 150ms delay to prevent clipboard race condition
- AudioRecorder stub starts AVAudioEngine with installTap (empty closure discards audio) — validates mic permission, triggers macOS mic LED, and prevents AVAudioEngine surprises in Phase 2
- OverlayWindowController creates NSPanel with .nonactivatingPanel + orderFront(nil) to float above all windows without stealing focus from target app
- OverlayView provides SwiftUI 5-bar animated waveform placeholder (no audio data required) using .repeatForever animations
- AppDelegate fully wired: all 5 coordinator dependencies injected (menubarController, escapeMonitor, audioRecorder, textInjector, overlayController)
- Full test suite passes: 15 tests across AppCoordinatorTests, MenubarControllerTests, HotkeyMonitorTests, PermissionsManagerTests, TextInjectorTests, AudioRecorderTests

## Task Commits

Each task was committed atomically:

1. **Task 1: TextInjector (paste simulation) and AudioRecorder stub** - `d35ef83` (feat)
2. **Task 2: OverlayWindowController, OverlayView, and full AppDelegate wiring** - `1f552e3` (feat)

## Files Created/Modified
- `MyWhisper/System/TextInjector.swift` - NSPasteboard write + CGEventPost Cmd+V with 150ms delay, AXIsProcessTrusted check, NSAlert fallback
- `MyWhisper/Audio/AudioRecorder.swift` - AVAudioEngine stub: installTap with empty closure, start/stop/cancel, no network imports
- `MyWhisper/UI/OverlayWindowController.swift` - NSPanel floating overlay, .nonactivatingPanel, orderFront(nil), .canJoinAllSpaces+.fullScreenAuxiliary
- `MyWhisper/UI/OverlayView.swift` - SwiftUI 5-bar waveform placeholder with .repeatForever looping animation
- `MyWhisperTests/TextInjectorTests.swift` - testPasteboardWrite, testPasteboardWriteOverwritesPrevious
- `MyWhisperTests/AudioRecorderTests.swift` - testNoNetworkCalls, testStopWithoutStartDoesNotCrash, testCancelWithoutStartDoesNotCrash
- `MyWhisper/App/AppDelegate.swift` - Added audioRecorder, textInjector, overlayController properties and injection into coordinator
- `MyWhisper.xcodeproj/project.pbxproj` - Added Audio group + 6 new files to build phases

## Decisions Made
- Used `orderFront(nil)` not `makeKeyAndOrderFront(nil)` for the NSPanel overlay — the key distinction that prevents focus theft from the user's active app (which would move the cursor and break paste)
- AudioRecorder actually starts AVAudioEngine against the real microphone rather than just simulating state — validates mic permission flow end-to-end, triggers the macOS mic LED indicator (authentic feedback), and ensures no AVAudioEngine initialization surprises when Phase 2 adds real capture
- TextInjector accepts an optional PermissionsManager (nil default) so unit tests can call inject() without triggering permission dialogs
- NSPanel collectionBehavior includes `.fullScreenAuxiliary` so the overlay appears correctly during full-screen app sessions

## Deviations from Plan

None — plan executed exactly as written. Both source files and test files were implemented as specified in the plan's `<action>` blocks.

## Issues Encountered

None. Build succeeded on first attempt after creating all files. All 15 unit tests pass.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness
- Phase 1 end-to-end flow is complete and functional. User can press Option+Space to start recording (overlay appears, mic LED activates), press again to stop (overlay hides, "Texto de prueba" pasted at cursor), or press Escape to cancel (beep, overlay hides, no paste).
- Phase 2 (STT) can now focus on replacing `audioRecorder.startStub()` with real buffer capture and wiring WhisperKit — the AVAudioEngine foundation is already in place.
- Blocker still active: VAD library selection for Phase 2 unresolved.

---
*Phase: 01-foundation*
*Completed: 2026-03-15*
