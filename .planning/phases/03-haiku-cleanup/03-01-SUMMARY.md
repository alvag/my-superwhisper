---
phase: 03-haiku-cleanup
plan: 01
subsystem: cleanup
tags: [anthropic, haiku, keychain, security, urlsession, actor, tdd]

# Dependency graph
requires:
  - phase: 02-audio-transcription
    provides: STTEngine producing raw Spanish text string
  - phase: 01-foundation
    provides: AppCoordinator DI pattern, NotificationHelper
provides:
  - HaikuCleanupProtocol: DI contract for AppCoordinator integration (Plan 02)
  - HaikuCleanupService: actor sending raw text to Anthropic Messages API
  - KeychainService: save/load/delete API key in macOS Keychain
  - Full unit test coverage with MockURLProtocol (no real network calls)
affects: [03-02-integration, 04-polish]

# Tech tracking
tech-stack:
  added: [Security framework (Keychain), Foundation URLSession async/await]
  patterns: [Actor-backed protocol DI matching STTEngineProtocol, MockURLProtocol for URLSession testing, SecItemDelete-before-add for Keychain overwrites]

key-files:
  created:
    - MyWhisper/System/KeychainService.swift
    - MyWhisper/Cleanup/HaikuCleanupProtocol.swift
    - MyWhisper/Cleanup/HaikuCleanupError.swift
    - MyWhisper/Cleanup/HaikuCleanupService.swift
    - MyWhisperTests/KeychainServiceTests.swift
    - MyWhisperTests/HaikuCleanupServiceTests.swift
  modified:
    - MyWhisper.xcodeproj/project.pbxproj

key-decisions:
  - "HaikuCleanupService uses URLSessionConfiguration with timeoutIntervalForRequest=5 AND timeoutIntervalForResource=5 — both needed to cover DNS hang vs response timeout separately"
  - "saveAPIKey validates with max_tokens=5 tiny request before Keychain.save() — prevents bad keys from being persisted"
  - "HaikuCleanupError conforms to LocalizedError with Spanish error descriptions — matches user-facing notification language"
  - "estimateMaxTokens: min(max(chars/4*1.5, 128), 2048) — proportional with floor and ceiling to prevent starvation and cost spikes"
  - "MockURLProtocol registered via URLSessionConfiguration.ephemeral.protocolClasses — clean per-test isolation, no URLProtocol.registerClass side effects"

requirements-completed: [CLN-01, CLN-02, CLN-03, CLN-04, CLN-05, PRV-02]

# Metrics
duration: 6min
completed: 2026-03-16
---

# Phase 03 Plan 01: HaikuCleanup Service Layer Summary

**HaikuCleanupService actor with Keychain API key storage, URLSession POST to Anthropic Messages API, 5s timeout, Spanish RAE cleanup prompt, and full unit tests via MockURLProtocol**

## Performance

- **Duration:** ~6 min
- **Started:** 2026-03-16
- **Completed:** 2026-03-16
- **Tasks:** 2 of 2 complete
- **Files created/modified:** 7

## Accomplishments

- `KeychainService` enum with `save/load/delete` using `kSecClassGenericPassword` under `com.mywhisper.anthropic-api-key` service name
- `HaikuCleanupProtocol` matching `STTEngineProtocol` DI pattern — ready for AppCoordinator injection in Plan 02
- `HaikuCleanupError` with 6 cases covering all Anthropic API failure modes, Spanish `LocalizedError` descriptions
- `HaikuCleanupService` actor with:
  - 5s request+resource timeout via `URLSessionConfiguration`
  - Spanish RAE punctuation/cleanup system prompt (CLN-01 through CLN-04)
  - HTTP dispatch: 200 → decode AnthropicResponse, 401/403 → authFailed, 429 → rateLimited, 5xx → serverError
  - `saveAPIKey` validates before saving (tiny max_tokens:5 test call)
  - `estimateMaxTokens` proportional formula (CLN-05)
- `KeychainServiceTests`: 5 tests (save/load round-trip, load nil, delete, overwrite)
- `HaikuCleanupServiceTests`: 10 tests with `MockURLProtocol` covering all error paths + PRV-02 body inspection
- All registered in `project.pbxproj` under new Cleanup group (AA000038-043)

## Task Commits

1. **Task 1: KeychainService and tests** - `98488f2` (feat)
2. **Task 2: HaikuCleanupProtocol/Error/Service/Tests** - `cdd0084` (feat)

## Files Created/Modified

- `MyWhisper/System/KeychainService.swift` — Keychain CRUD enum for API key storage
- `MyWhisper/Cleanup/HaikuCleanupProtocol.swift` — DI protocol with clean/hasAPIKey/saveAPIKey/removeAPIKey
- `MyWhisper/Cleanup/HaikuCleanupError.swift` — Error enum with LocalizedError Spanish descriptions
- `MyWhisper/Cleanup/HaikuCleanupService.swift` — Actor: URLSession POST, 5s timeout, system prompt, Keychain integration
- `MyWhisperTests/KeychainServiceTests.swift` — 5 Keychain round-trip tests
- `MyWhisperTests/HaikuCleanupServiceTests.swift` — 10 tests with MockURLProtocol (no real API calls)
- `MyWhisper.xcodeproj/project.pbxproj` — Registered 6 new Swift files + Cleanup group

## Decisions Made

- URLSessionConfiguration timeout (both request+resource at 5s) covers DNS hang scenarios — `URLRequest.timeoutInterval` alone misses DNS failures
- Keychain overwrite: `SecItemDelete` before `SecItemAdd` (vs `SecItemUpdate`) — simpler, handles both first-save and update cases
- `saveAPIKey` validates before storing — prevents 401 errors on first real use
- `HaikuCleanupError.networkError(Error)` wraps `URLError` preserving original error for diagnostics

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Missing `import Foundation` in HaikuCleanupError.swift**
- **Found during:** Task 2 (xcodebuild build-for-testing)
- **Issue:** `LocalizedError` not found in scope without Foundation import — compiler error "cannot find type 'LocalizedError' in scope"
- **Fix:** Added `import Foundation` to HaikuCleanupError.swift
- **Files modified:** MyWhisper/Cleanup/HaikuCleanupError.swift
- **Commit:** cdd0084

## Issues Encountered

- `swift test` does not find tests (project uses Xcode target, not SPM test conventions). Verification uses `xcodebuild build-for-testing` as established in Phase 2. Test execution requires Xcode with proper signing — pre-existing constraint documented in STATE.md.

## User Setup Required

None for this plan. API key configuration UI comes in Plan 02.

## Next Phase Readiness

- `HaikuCleanupProtocol` is ready for injection into `AppCoordinator` (Plan 02)
- `KeychainService` ready for use by `APIKeyWindowController` (Plan 02)
- All error cases handled with fallback-to-raw-text philosophy (PRV-04 service layer)

---
*Phase: 03-haiku-cleanup*
*Completed: 2026-03-16*

## Self-Check: PASSED

- FOUND: MyWhisper/System/KeychainService.swift
- FOUND: MyWhisper/Cleanup/HaikuCleanupProtocol.swift
- FOUND: MyWhisper/Cleanup/HaikuCleanupError.swift
- FOUND: MyWhisper/Cleanup/HaikuCleanupService.swift
- FOUND: MyWhisperTests/KeychainServiceTests.swift
- FOUND: MyWhisperTests/HaikuCleanupServiceTests.swift
- FOUND: .planning/phases/03-haiku-cleanup/03-01-SUMMARY.md
- FOUND: commit 98488f2 (feat(03-01): KeychainService)
- FOUND: commit cdd0084 (feat(03-01): HaikuCleanupService)
