---
phase: 6
slug: integration-verification
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-17
---

# Phase 6 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | XCTest (existing) — Phase 6 is primarily manual verification |
| **Config file** | None — Xcode scheme `MyWhisper` |
| **Quick run command** | `xcodebuild test -scheme MyWhisper -only-testing:MyWhisperTests/MediaPlaybackServiceTests -destination 'platform=macOS' 2>&1 \| tail -20` |
| **Full suite command** | `xcodebuild test -scheme MyWhisper -destination 'platform=macOS' 2>&1 \| tail -30` |
| **Estimated runtime** | ~15 seconds |

---

## Sampling Rate

- **Before checklist:** Run full test suite — confirm existing 11 media tests green
- **After NSWorkspace fix (if applied):** Run full suite to verify new guard test passes
- **Phase gate:** Full suite green + VERIFICATION.md completed before v1.1 ships
- **Max feedback latency:** 15 seconds (automated) / varies (manual)

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Scenario | Test Type | Automated Command | Status |
|---------|------|------|----------|-----------|-------------------|--------|
| 06-01-01 | 01 | 1 | Music.app guard (if fix applied) | unit | `xcodebuild test -only-testing:MediaPlaybackServiceTests` | ⬜ pending |
| 06-01-02 | 01 | 1 | Spotify pause/resume | manual | Human observation | ⬜ pending |
| 06-01-03 | 01 | 1 | Apple Music pause/resume | manual | Human observation | ⬜ pending |
| 06-01-04 | 01 | 1 | Nothing playing (Music.app launch) | manual | Human observation | ⬜ pending |
| 06-01-05 | 01 | 1 | YouTube in Safari | manual | Human observation | ⬜ pending |
| 06-01-06 | 01 | 1 | Rapid double-tap | manual | Human observation | ⬜ pending |
| 06-01-07 | 01 | 1 | Toggle OFF | manual | Human observation | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

If NSWorkspace guard fix is applied:
- [ ] New test in `MyWhisperTests/MediaPlaybackServiceTests.swift` — covers `pause()` skips key when no media app running

If no code changes needed:
- Existing infrastructure covers all Phase 5 requirements; Phase 6 is purely manual.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Spotify pause/resume | MEDIA-01/02 | Requires real Spotify + audio | Play music → hotkey → verify pause → hotkey → verify resume |
| Apple Music pause/resume | MEDIA-01/02 | Requires real Apple Music | Same as Spotify |
| Nothing playing scenario | MEDIA-04 | Requires observing Music.app launch | Close all players → hotkey → check if Music.app launches |
| YouTube in Safari | MEDIA-04 | Requires real browser + video | Play YouTube → hotkey → verify pause → hotkey → verify resume |
| Rapid double-tap | Edge case | Timing-dependent human action | Press hotkey twice as fast as possible → observe media state |
| Toggle OFF | SETT-01 | Requires Settings UI interaction | Disable toggle → play music → hotkey → verify no pause |

---

## Validation Sign-Off

- [ ] All manual scenarios executed and documented
- [ ] NSWorkspace fix applied if Music.app launch confirmed
- [ ] Full test suite green after any code changes
- [ ] Limitations documented in VERIFICATION.md
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
