---
phase: 3
slug: haiku-cleanup
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-16
---

# Phase 3 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | XCTest (Swift, built-in Xcode) |
| **Config file** | Package.swift — `.testTarget(name: "MyWhisperTests", dependencies: ["MyWhisper"])` |
| **Quick run command** | `swift test --filter HaikuCleanup 2>&1` |
| **Full suite command** | `swift test 2>&1` |
| **Estimated runtime** | ~15 seconds |

---

## Sampling Rate

- **After every task commit:** Run `swift test --filter AppCoordinatorTests 2>&1`
- **After every plan wave:** Run `swift test 2>&1`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 15 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 03-01-01 | 01 | 0 | CLN-03, CLN-04, CLN-05, PRV-02 | unit | `swift test --filter HaikuCleanupServiceTests 2>&1` | ❌ W0 | ⬜ pending |
| 03-01-02 | 01 | 0 | PRV-03 | unit | `swift test --filter KeychainServiceTests 2>&1` | ❌ W0 | ⬜ pending |
| 03-01-03 | 01 | 0 | PRV-04, CLN-01, CLN-02 | unit | `swift test --filter AppCoordinatorTests 2>&1` | ✅ (needs mock) | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `MyWhisperTests/HaikuCleanupServiceTests.swift` — stubs for CLN-03, CLN-04, CLN-05, PRV-02 (MockHaikuCleanup + network-skippable integration test)
- [ ] `MyWhisperTests/KeychainServiceTests.swift` — save/load/delete round-trip using test-specific service name (PRV-03)
- [ ] `MockHaikuCleanup` in `AppCoordinatorTests.swift` — coordinator-level wiring for PRV-04, CLN-01/02

*Existing infrastructure: XCTest framework and MyWhisperTests target already configured.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Haiku output quality (punctuation accuracy) | CLN-01, CLN-02 | Requires real API call + human judgment of Spanish text quality | Record 30s Spanish speech, verify pasted text has correct ¿¡ marks, periods, capitalization |
| Filler removal preserves meaning | CLN-04 | Semantic meaning preservation requires human review | Dictate text with muletillas, verify cleaned output doesn't change meaning |
| End-to-end latency <5s | CLN-05 | Depends on network + hardware | Time full pipeline with stopwatch on Apple Silicon |
| API key modal UX | PRV-03 | Visual verification needed | Launch without key, attempt recording, verify modal appears |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 15s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
