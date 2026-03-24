---
gsd_state_version: 1.0
milestone: v1.3
milestone_name: Settings UX
status: v1.3 milestone complete
stopped_at: "checkpoint:human-verify Task 2 in 10-01-PLAN.md"
last_updated: "2026-03-24T19:40:15.667Z"
progress:
  total_phases: 2
  completed_phases: 2
  total_plans: 3
  completed_plans: 3
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-03-24)

**Core value:** Frictionless voice-to-text that produces clean, well-formatted Spanish text — press a key, speak, press again, and polished text appears where you're typing. Local STT + Haiku cleanup.
**Current focus:** Phase 10 — settings-swiftui-ui

## Current Position

Phase: 10
Plan: Not started

## Performance Metrics

**Velocity:**

- Total plans completed: 0 (this milestone)
- Average duration: —
- Total execution time: —

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 9. Window Lifecycle Foundation | TBD | — | — |
| 10. Settings SwiftUI UI | TBD | — | — |
| Phase 09-window-lifecycle-foundation P01 | 6min | 2 tasks | 3 files |
| Phase 09 P02 | 1min | 1 tasks | 1 files |
| Phase 10-settings-swiftui-ui P01 | 2min | 1 tasks | 2 files |

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Recent decisions affecting current work:

- [v1.3 research]: NO usar SwiftUI Settings scene ni openSettings — roto en macOS 26 Tahoe; usar NSWindow + NSHostingController
- [v1.3 research]: NO usar @AppStorage en clase @Observable — unsupported; usar didSet + UserDefaults.standard.set
- [v1.3 research]: NSWindow reemplaza NSPanel (isReleasedWhenClosed = false) — NSPanel.hidesOnDeactivate = true es la causa del bug actual
- [v1.3 research]: Activación: .regular en show(), .accessory en windowWillClose + NSApp.hide(nil)
- [Phase 09-01]: @Observable + didSet pattern for SettingsViewModel (no @AppStorage — incompatible with @Observable)
- [Phase 09-01]: SettingsView uses KeyboardShortcuts.Recorder (SwiftUI variant, not RecorderCocoa) per Pitfall 4
- [Phase 09-01]: Xcodeproj UUID AA000200000/001 for SettingsView — AA000070000 was taken by build config list
- [Phase 09-02]: NSWindow instead of NSPanel: hidesOnDeactivate=true was root cause of WIN-01; NSWindow resolves it
- [Phase 09-02]: windowShouldClose returning false + orderOut(nil): preserves window instance, avoids SettingsView state loss on re-open
- [Phase 09-02]: NSApp.hide(nil) after .accessory restore: required for WIN-03 focus return to previous app
- [Phase 10-settings-swiftui-ui]: CoreAudio debe importarse en SettingsView.swift para usar AudioDeviceID en Picker tags
- [Phase 10-settings-swiftui-ui]: VocabularyEntry.id es UUID efimero: valor default garantiza compatibilidad con datos existentes sin migracion
- [Phase 10-settings-swiftui-ui]: Picker tags deben ser AudioDeviceID? (opcional) para coincidir con el tipo del binding selectedMicID

### Pending Todos

None.

### Blockers/Concerns

- [Phase 9]: Validar que canBecomeKeyWindow funcione — si keyboard input está muerto, llamar makeKeyAndOrderFront via DispatchQueue.main.async
- [Phase 10]: SwiftUI List en macOS no soporta Delete-key nativo — validar en Phase 10; fallback a NSTableView via NSViewRepresentable si es necesario

## Session Continuity

Last session: 2026-03-24T18:55:31.372Z
Stopped at: checkpoint:human-verify Task 2 in 10-01-PLAN.md
Resume file: None
