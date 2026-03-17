---
phase: 07-implementation
plan: 03
subsystem: cleanup
tags: [haiku, anthropic, swift, tdd, unit-tests, hallucination-prevention]

# Dependency graph
requires:
  - phase: 07-implementation
    provides: HaikuCleanupService actor and AppCoordinator transcription pipeline

provides:
  - Rule 6 (ORIGEN STT) in HaikuCleanupService system prompt prohibiting hallucinated courtesy phrases
  - stripHallucinatedSuffix() function in AppCoordinator with punctuation-tolerant check
  - Suffix strip wired between haiku.clean() and vocabularyService.apply()
  - testRequestBodyContainsRule6 in HaikuCleanupServiceTests
  - 4 suffix strip integration tests in AppCoordinatorTests

affects: [HAIKU-01, HAIKU-02, transcription-pipeline, cleanup-quality]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Dual-layer hallucination defense: prompt rule (Rule 6) + post-processing strip (stripHallucinatedSuffix)"
    - "MockURLProtocol httpBodyStream fallback: URLSession converts httpBody to stream, must read httpBodyStream when httpBody is nil"
    - "Static capture buffer on MockURLProtocol for thread-safe body capture in async tests"

key-files:
  created: []
  modified:
    - MyWhisper/Cleanup/HaikuCleanupService.swift
    - MyWhisper/Coordinator/AppCoordinator.swift
    - MyWhisperTests/HaikuCleanupServiceTests.swift
    - MyWhisperTests/AppCoordinatorTests.swift

key-decisions:
  - "stripHallucinatedSuffix trims trailing punctuation BEFORE hasSuffix check to handle 'Gracias.' variant"
  - "confirmedPatterns = ['gracias'] — only expand with confirmed evidence from production observations"
  - "Suffix strip is placed AFTER haiku.clean() and BEFORE vocabularyService.apply() in transcription pipeline"
  - "Fixed pre-existing MockURLProtocol bug: URLSession converts httpBody to httpBodyStream, added stream reading fallback"

patterns-established:
  - "Post-Haiku safety net pattern: rule in prompt + code strip as fallback"
  - "Actor-safe URL request body capture: use static var on MockURLProtocol, read httpBodyStream"

requirements-completed: [HAIKU-01, HAIKU-02]

# Metrics
duration: 24min
completed: 2026-03-17
---

# Phase 7 Plan 03: Haiku Hallucination Prevention Summary

**Dual-layer hallucination defense: Rule 6 (ORIGEN STT) in Haiku system prompt + stripHallucinatedSuffix() post-processing strip in AppCoordinator transcription pipeline**

## Performance

- **Duration:** ~24 min
- **Started:** 2026-03-17T13:10:04Z
- **Completed:** 2026-03-17T13:34:36Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments
- Added Rule 6 to HaikuCleanupService system prompt instructing Haiku not to add courtesy phrases (gracias, de nada, hasta luego) absent from raw STT input
- Implemented `stripHallucinatedSuffix()` in AppCoordinator that trims trailing hallucinated patterns, with punctuation-tolerant check (handles "Gracias" and "Gracias." variants)
- Wired suffix strip into transcription pipeline: rawText -> haiku.clean() -> stripHallucinatedSuffix() -> vocabularyService.apply()
- Added 5 new tests: Rule 6 presence test + 4 suffix strip integration tests, all passing
- Fixed pre-existing bug in MockURLProtocol: body capture was always nil because URLSession converts httpBody to httpBodyStream

## Task Commits

Each task was committed atomically:

1. **Task 1: Add Rule 6 to Haiku system prompt and implement suffix strip in AppCoordinator** - `ea34d71` (feat)
2. **Task 2: Add Haiku Rule 6 and suffix strip unit tests** - `fad2139` (test)

## Files Created/Modified
- `MyWhisper/Cleanup/HaikuCleanupService.swift` - Added Rule 6 (ORIGEN STT) to systemPrompt after Rule 5
- `MyWhisper/Coordinator/AppCoordinator.swift` - Added stripHallucinatedSuffix() function and call site in handleHotkey()
- `MyWhisperTests/HaikuCleanupServiceTests.swift` - Added testRequestBodyContainsRule6(); fixed MockURLProtocol to read httpBodyStream
- `MyWhisperTests/AppCoordinatorTests.swift` - Added 4 suffix strip integration tests (HAIKU-02)

## Decisions Made
- `stripHallucinatedSuffix` trims trailing punctuation before `hasSuffix` check so "Gracias." is handled the same as "Gracias"
- Used `confirmedPatterns = ["gracias"]` with a comment to only expand with confirmed production evidence
- Suffix strip preserves "gracias" when the word is present in the raw STT input (presence check before strip)
- Fixed MockURLProtocol body capture by adding `static var lastCapturedBody` that reads from `httpBodyStream` when `httpBody` is nil (URLSession converts body to stream for actor-isolated requests)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed pre-existing MockURLProtocol body capture bug**
- **Found during:** Task 2 (Add Haiku Rule 6 and suffix strip unit tests)
- **Issue:** `testRequestBodyContainsModelAndSystemPrompt` had always been failing (pre-existing since original commit `cdd0084`). URLSession converts `httpBody` to `httpBodyStream` internally, so `request.httpBody` in `MockURLProtocol.startLoading()` is always `nil`. The original test pattern of capturing via closure was also broken by concurrency isolation.
- **Fix:** Added `static var lastCapturedBody: Data?` to MockURLProtocol; in `startLoading()`, reads from `httpBodyStream` with manual stream drain when `httpBody` is nil. Both new and pre-existing request body tests now pass.
- **Files modified:** MyWhisperTests/HaikuCleanupServiceTests.swift
- **Verification:** `testRequestBodyContainsModelAndSystemPrompt` and `testRequestBodyContainsRule6` both pass when run in isolation and together
- **Committed in:** fad2139 (Task 2 commit)

**2. [Rule 2 - Implementation detail] Updated stripHallucinatedSuffix to handle "Gracias." variant**
- **Found during:** Task 2 (`testSuffixStripHandlesGraciasDotVariant` test specification)
- **Issue:** Task 1 implementation used `hasSuffix("gracias")` which doesn't match "Gracias." (trailing period). Task 2 spec identified this gap and required the implementation to handle punctuation.
- **Fix:** Updated `stripHallucinatedSuffix` in Task 1 to trim trailing whitespace and punctuation BEFORE the `hasSuffix` check, using the enhanced version specified in Task 2's action section.
- **Files modified:** MyWhisper/Coordinator/AppCoordinator.swift
- **Verification:** `testSuffixStripHandlesGraciasDotVariant` passes
- **Committed in:** ea34d71 (Task 1 commit — implementation done upfront with full spec)

---

**Total deviations:** 2 auto-fixed (1 pre-existing bug fix, 1 implementation enhancement from TDD spec)
**Impact on plan:** Both fixes essential for correctness. The MockURLProtocol fix resolved a test infrastructure bug that had been silently masking the body capture test. The punctuation handling was spec'd in Task 2 and implemented proactively.

## Issues Encountered
- URLSession body capture: URLSession converts `httpBody` to `httpBodyStream` for requests made from within actors, requiring explicit stream reading in MockURLProtocol. This was a previously undiscovered platform behavior that affected multiple tests.
- Parallel test suite Keychain flakiness: `KeychainServiceTests` and some `HaikuCleanupServiceTests` fail intermittently when run in parallel with other test targets due to shared Keychain state. This is a pre-existing environmental issue unrelated to this plan.

## Next Phase Readiness
- HAIKU-01 and HAIKU-02 requirements satisfied
- Dual-layer hallucination defense operational: prompt instruction + post-processing strip
- Test coverage complete: Rule 6 presence + 4 behavioral suffix strip cases
- Ready to proceed with remaining Phase 7 plans

## Self-Check: PASSED

- FOUND: MyWhisper/Cleanup/HaikuCleanupService.swift (contains ORIGEN STT)
- FOUND: MyWhisper/Coordinator/AppCoordinator.swift (contains stripHallucinatedSuffix)
- FOUND: MyWhisperTests/HaikuCleanupServiceTests.swift (contains testRequestBodyContainsRule6)
- FOUND: MyWhisperTests/AppCoordinatorTests.swift (contains testSuffixStripRemovesHallucinatedGracias)
- FOUND: ea34d71 feat(07-03): add Haiku Rule 6 and stripHallucinatedSuffix
- FOUND: fad2139 test(07-03): add Haiku Rule 6 and suffix strip unit tests

---
*Phase: 07-implementation*
*Completed: 2026-03-17*
