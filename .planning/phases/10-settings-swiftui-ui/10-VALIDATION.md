---
phase: 10
slug: settings-swiftui-ui
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-24
---

# Phase 10 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | XCTest (built-in) |
| **Config file** | MyWhisper.xcodeproj |
| **Quick run command** | `cd /Users/max/Personal/repos/my-superwhisper && swift build 2>&1 \| tail -10` |
| **Full suite command** | `cd /Users/max/Personal/repos/my-superwhisper && swift test 2>&1 \| tail -20` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Run `swift build 2>&1 | tail -10`
- **After every plan wave:** Run `swift test 2>&1 | tail -20`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 10-01-01 | 01 | 1 | UI-01, UI-02, UI-03, UI-04, UI-05, UI-06, UI-07 | build | `swift build 2>&1 \| tail -10` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Existing infrastructure covers all phase requirements. SwiftUI UI changes are validated by successful compilation (swift build) and manual visual verification.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| 4 secciones agrupadas visibles | UI-01, UI-02 | Visual layout | Open Settings, verify 4 sections: Grabación, API, Vocabulario, Sistema |
| Hotkey recorder funcional | UI-03 | Hardware interaction | Click recorder, press key combo, verify it registers |
| Micrófono seleccionable | UI-04 | Hardware devices | Open Picker, verify available mics listed, select one |
| Vocabulario add/edit/delete | UI-05 | Interactive UI | Click +, type entries, click -, verify persistence |
| Toggles persisten estado | UI-06 | Persistence | Toggle each, restart app, verify state preserved |
| Botón API key abre modal | UI-07 | Window interaction | Click button, verify NSPanel modal appears |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
