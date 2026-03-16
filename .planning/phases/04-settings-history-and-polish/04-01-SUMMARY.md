---
phase: 04-settings-history-and-polish
plan: 01
subsystem: services
tags: [vocabulary, history, microphone, hotkey, keyboardshortcuts]
dependency_graph:
  requires: [03-01, 03-02]
  provides: [VocabularyService, TranscriptionHistoryService, MicrophoneDeviceService, KeyboardShortcuts hotkey]
  affects: [AppCoordinator pipeline, AppDelegate wiring, Package.swift]
tech_stack:
  added: [KeyboardShortcuts 2.4.0]
  removed: [HotKey 0.2.1]
  patterns: [UserDefaults injection for testability, FIFO eviction, CoreAudio enumeration]
key_files:
  created:
    - MyWhisper/Vocabulary/VocabularyEntry.swift
    - MyWhisper/Vocabulary/VocabularyService.swift
    - MyWhisper/History/TranscriptionHistoryService.swift
    - MyWhisper/Audio/MicrophoneDeviceService.swift
    - MyWhisperTests/VocabularyServiceTests.swift
    - MyWhisperTests/TranscriptionHistoryServiceTests.swift
    - MyWhisperTests/MicrophoneDeviceServiceTests.swift
  modified:
    - Package.swift
    - MyWhisper/System/HotkeyMonitor.swift
    - MyWhisper/Coordinator/AppCoordinator.swift
    - MyWhisper/App/AppDelegate.swift
    - MyWhisperTests/HotkeyMonitorTests.swift
    - MyWhisper.xcodeproj/project.pbxproj
decisions:
  - "UserDefaults injectable in all new services via init(defaults:) for test isolation with in-memory suites"
  - "MicrophoneDeviceService tests hardware-guarded with XCTSkipIf to skip gracefully in CI"
  - "KeyboardShortcuts replaces HotKey — pbxproj updated manually since Package.resolved is gitignored"
  - "Vocabulary corrections applied post-Haiku with nil-safe guard preserving existing test behavior"
  - "History saved after correctedText (not rawText) to capture the final pasted value"
metrics:
  duration: 8 min
  completed: "2026-03-16"
  tasks: 2
  files: 11
---

# Phase 04 Plan 01: Services Foundation Summary

**One-liner:** VocabularyService (case-insensitive corrections), TranscriptionHistoryService (FIFO-20), MicrophoneDeviceService (CoreAudio), and HotKey-to-KeyboardShortcuts migration wired into AppCoordinator pipeline.

## What Was Built

### Task 1: New Services (TDD)

**VocabularyEntry + VocabularyService**
- `VocabularyEntry: Codable, Equatable` with `wrong`/`correct` fields
- `VocabularyService.apply(to:)` iterates entries using `.caseInsensitive` `replacingOccurrences`
- Entries persisted to `UserDefaults` via `JSONEncoder`/`JSONDecoder`
- `init(defaults:)` injection for test isolation

**TranscriptionHistoryService**
- `HistoryEntry: Codable, Identifiable` with id, text, date, `truncated` computed var (80 char cap)
- `append(_:)` inserts at index 0, trims to `maxEntries = 20` (FIFO)
- `clear()` empties history
- Persisted to UserDefaults with `init(defaults:)` injection

**MicrophoneDeviceService**
- `AudioDeviceInfo: Identifiable` with `id: AudioDeviceID` and `name: String`
- `availableInputDevices()` uses CoreAudio `kAudioHardwarePropertyDevices` + input channel check
- `setInputDevice(_:on:)` uses `AudioUnitSetProperty` with `kAudioOutputUnitProperty_CurrentDevice`
- `selectedDeviceID` persisted as `UInt32` to UserDefaults; nil = system default

### Task 2: HotKey -> KeyboardShortcuts Migration

- `Package.swift` replaces HotKey with `sindresorhus/KeyboardShortcuts 2.4.0`
- `KeyboardShortcuts.Name.toggleRecording` extension with default `.init(.space, modifiers: [.option])`
- `HotkeyMonitor` rebuilt using `KeyboardShortcuts.onKeyDown(for: .toggleRecording)`
- `unregister()` calls `KeyboardShortcuts.disable(.toggleRecording)` (idempotent)
- pbxproj updated to replace all HotKey references with KeyboardShortcuts; new file references added

### AppCoordinator Pipeline Update

Pipeline order after this plan:
1. Record -> transcribe (WhisperKit)
2. Haiku cleanup (Anthropic)
3. **Vocabulary corrections** (`vocabularyService?.apply(to: finalText)`)
4. Paste corrected text
5. **Save to history** (`historyService?.append(correctedText)`)

### AppDelegate Wiring

Three new services created in `applicationDidFinishLaunching` and wired to coordinator:
- `VocabularyService()` -> `coordinator.vocabularyService`
- `TranscriptionHistoryService()` -> `coordinator.historyService`
- `MicrophoneDeviceService()` stored as strong reference for Plan 02 mic selection

## Deviations from Plan

### Auto-fixed Issues

**[Rule 3 - Blocking] pbxproj required manual update for KeyboardShortcuts**
- **Found during:** Task 2
- **Issue:** `Package.resolved` is in `.gitignore` so the xcodeproj still referenced HotKey in its `XCRemoteSwiftPackageReference` and `XCSwiftPackageProductDependency` entries. xcodebuild kept reverting to HotKey.
- **Fix:** Manually updated `project.pbxproj` to replace all HotKey references with KeyboardShortcuts, add new file references for 7 new source files, and update package reference URL/version.
- **Files modified:** `MyWhisper.xcodeproj/project.pbxproj`
- **Commit:** b39d2ab

## Tests

| Suite | Tests | Status |
|-------|-------|--------|
| VocabularyServiceTests | 5 | Build verified (code sign env constraint prevents run) |
| TranscriptionHistoryServiceTests | 7 | Build verified |
| MicrophoneDeviceServiceTests | 4 | Build verified, hardware-guarded |
| HotkeyMonitorTests | 3 | Build verified (KeyboardShortcuts) |

Note: xcodebuild test execution fails in this environment due to a pre-existing code signature constraint (Team ID mismatch in test bundle loading) — consistent across all previous phases. Build succeeds cleanly with `BUILD SUCCEEDED`.

## Self-Check: PASSED

All 7 new source files exist on disk. All 3 task commits verified in git log (71bfc09, 805f012, b39d2ab).
