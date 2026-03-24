---
phase: 09-window-lifecycle-foundation
plan: 01
subsystem: settings-ui
tags: [swiftui, observable, viewmodel, settings]
dependency_graph:
  requires:
    - VocabularyService (entries get/set)
    - MicrophoneDeviceService (selectedDeviceID, availableInputDevices)
    - HaikuCleanupProtocol (init param, not stored)
    - KeyboardShortcuts.Name.toggleRecording
  provides:
    - SettingsViewModel (@Observable bridge for all settings state)
    - SettingsView (SwiftUI Form with hotkey recorder and toggle)
  affects:
    - 09-02-PLAN (SettingsWindowController rewrite uses these as NSHostingController content)
tech_stack:
  added:
    - "@Observable macro (Swift 5.9+) for reactive state"
    - "ServiceManagement.SMAppService for launch-at-login"
    - "KeyboardShortcuts.Recorder (SwiftUI variant)"
    - "SwiftUI Form with .formStyle(.grouped)"
  patterns:
    - "didSet -> UserDefaults.standard.set for persistence without @AppStorage"
    - "@Bindable var viewModel for deriving bindings from @Observable class"
    - "Closure injection (openAPIKey) for AppKit decoupling from SwiftUI"
key_files:
  created:
    - MyWhisper/Settings/SettingsViewModel.swift
    - MyWhisper/Settings/SettingsView.swift
  modified:
    - MyWhisper.xcodeproj/project.pbxproj
decisions:
  - "Used @Observable + @MainActor (not ObservableObject) per D-08/D-09 from CONTEXT.md"
  - "All properties included for Phase 9+10 to avoid rewriting the file in next phase"
  - "openAPIKey closure avoids importing AppKit into SettingsViewModel"
  - "Xcodeproj IDs: AA000069000/001 for SettingsViewModel, AA000200000/001 for SettingsView (AA000070000 was taken by build config list)"
metrics:
  duration: "~6 min"
  completed: "2026-03-24"
  tasks: 2
  files: 3
---

# Phase 9 Plan 01: SettingsViewModel and SettingsView Summary

**One-liner:** @Observable SettingsViewModel with didSet UserDefaults bridge and SwiftUI Form with KeyboardShortcuts.Recorder for hotkey recording.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Crear SettingsViewModel con propiedades parciales para Phase 9 | 220f3f1 | MyWhisper/Settings/SettingsViewModel.swift, MyWhisper.xcodeproj/project.pbxproj |
| 2 | Crear SettingsView placeholder con hotkey recorder y toggle | 737e3d2 | MyWhisper/Settings/SettingsView.swift, MyWhisper.xcodeproj/project.pbxproj |

## What Was Built

### SettingsViewModel.swift
`@Observable @MainActor final class SettingsViewModel` — bridge layer between SwiftUI and existing services:

- `pausePlaybackEnabled` / `maximizeMicVolumeEnabled`: Bool toggles with `didSet -> UserDefaults.standard.set`
- `launchAtLoginEnabled`: Bool with `didSet -> SMAppService.mainApp.register/unregister` (with error recovery)
- `selectedMicID`: AudioDeviceID? with `didSet -> microphoneService.selectedDeviceID`
- `vocabularyEntries`: [VocabularyEntry] with `didSet -> vocabularyService.entries`
- `availableMics`: read-only, populated from `microphoneService.availableInputDevices()` at init
- `openAPIKey`: `() -> Void` closure for AppKit decoupling (no AppKit import needed in view layer)
- Init accepts `haikuCleanup` param for API compatibility but does not store it (APIKey accessed via closure)

### SettingsView.swift
`struct SettingsView: View` — SwiftUI Form placeholder for Phase 9 validation:

- `@Bindable var viewModel: SettingsViewModel` for two-way binding
- `KeyboardShortcuts.Recorder("Atajo de grabacion:", name: .toggleRecording)` (SwiftUI variant)
- `Toggle("Pausar reproduccion al grabar", isOn: $viewModel.pausePlaybackEnabled)`
- `.formStyle(.grouped)` matching macOS System Settings style
- `.frame(minWidth: 420, minHeight: 200)` for minimum dimensions

## Verification

- `xcodebuild -scheme MyWhisper -destination 'platform=macOS' build`: BUILD SUCCEEDED
- Both files exist in `MyWhisper/Settings/`
- SettingsViewModel: @Observable, no @AppStorage, all didSet bridges present
- SettingsView: KeyboardShortcuts.Recorder (SwiftUI), @Bindable, no RecorderCocoa, no AppKit

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed conflicting Xcode project UUIDs**
- **Found during:** Task 2 — xcodebuild failed with "Unable to read project" after adding SettingsView to xcodeproj
- **Issue:** UUID `AA000070000` was already used as the build configuration list for the MyWhisper target. Using it as the SettingsView file reference caused Xcode to fail parsing the project.
- **Fix:** Changed SettingsView file reference to `AA000200000` and build file to `AA000200001` (safe range not overlapping with existing 68-100 IDs)
- **Files modified:** MyWhisper.xcodeproj/project.pbxproj
- **Commit:** 737e3d2

## Known Stubs

None — SettingsView intentionally contains only 2 settings for Phase 9 validation. Remaining settings (mic selector, API key, vocabulary, launch at login, maximize volume toggle) will be added in Phase 10 per D-11 from CONTEXT.md.

## Self-Check: PASSED
