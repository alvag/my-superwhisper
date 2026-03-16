# Phase 3: Haiku Cleanup - Context

**Gathered:** 2026-03-16
**Status:** Ready for planning

<domain>
## Phase Boundary

Adds Anthropic Haiku API post-processing between WhisperKit transcription and text injection. Delivers clean, well-punctuated Spanish text with filler words removed — the core product promise. No settings UI beyond API key entry, no history, no vocabulary corrections (those are Phase 4).

</domain>

<decisions>
## Implementation Decisions

### API Key Setup & Storage
- API key requested on-the-fly: when user attempts first recording and no key is configured, show modal before recording starts
- Key stored in macOS Keychain — secure, native, survives reinstalls
- UI: small modal window with text field + Save button. Also accessible from menubar dropdown (Settings > API Key)
- Key validated on save: small test request to Anthropic API. If fails, show error and don't save. Prevents errors on first real use

### Cleanup Prompt Design
- Filler removal: only clear muletillas ("eh", "este", "o sea", "bueno pues") and exact repetitions ("yo yo creo"). Preserve expressions that carry coloquial meaning
- Paragraph breaks: Haiku detects topic changes or logical pauses and adds line breaks. No extra breaks for short texts
- Punctuation: Spanish standard per RAE — opening marks (¿¡), commas, periods, capitals after periods. No informal style
- Meaning preservation: Haiku must NOT paraphrase, add content, or restructure. Only clean up (CLN-04)
- Input: only raw transcription text from WhisperKit. No additional context (app name, metadata). Simple, fast, cheap

### Error & Offline Handling
- API failure (network, timeout, 500): paste raw STT text + notification "Texto pegado sin limpiar — error de conexión"
- Invalid key / no credit (401/403): paste raw STT text + notification explaining the error. Next recording attempt shows API key modal again
- Timeout: 5 seconds max for Haiku call. If exceeded, fallback to raw text paste
- Philosophy: user always gets text pasted — degraded quality is better than no output

### Pipeline Integration
- Overlay: same spinner throughout processing. No visual distinction between STT and Haiku phases. "Procesando..." covers both
- Model: claude-haiku-4-5-20251001 — fastest, cheapest, sufficient for text cleanup
- HTTP client: direct URLSession calls to Anthropic Messages API (REST). No SDK dependency
- max_tokens: proportional to input length (input chars * 1.5), prevents unexpectedly long responses
- Flow: record → STT → Haiku cleanup → paste. If Haiku fails at any point, paste raw STT output

### Claude's Discretion
- Exact system prompt wording for Haiku (within the constraints above)
- Keychain service name and access group configuration
- API key modal window dimensions and positioning
- URLSession configuration details (caching, connection pooling)
- Error message wording for specific API error codes
- Token estimation approach for max_tokens calculation

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project Context
- `.planning/PROJECT.md` — Project vision, constraints (local STT + Haiku API cleanup, Apple Silicon, Spanish only v1)
- `.planning/REQUIREMENTS.md` — CLN-01/02/03/04/05, PRV-02/03/04 requirements for this phase
- `.planning/ROADMAP.md` — Phase 3 success criteria and dependency on Phase 2

### Prior Phase Context
- `.planning/phases/01-foundation/01-CONTEXT.md` — Menubar states, overlay design, paste mechanism, notification patterns
- `.planning/phases/02-audio-transcription/02-CONTEXT.md` — Processing flow, spinner during STT, notification patterns, WhisperKit output format

### Architecture (from Phase 1 research)
- `.planning/research/ARCHITECTURE.md` — Component architecture, FSM design, data flow
- `.planning/research/STACK.md` — Swift/SwiftUI stack, existing dependencies

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `AppCoordinator.swift` — FSM with idle/recording/processing/error states. Lines 62-77: after STT, calls `textInjector?.inject(text)`. Phase 3 inserts Haiku cleanup between STT result and inject call
- `TextInjector.swift` — Clipboard + CGEventPost paste. Already works, no changes needed — just pass cleaned text instead of raw
- `NotificationHelper.swift` — macOS native notifications. Reuse for API error notifications
- `STTEngine.swift` — WhisperKit transcription. Output feeds into new HaikuCleanup service

### Established Patterns
- Protocol-based dependency injection (`STTEngineProtocol`, `AudioRecorderProtocol`, etc.) — new HaikuCleanup service should follow same pattern
- `@Observable` + `@MainActor` on AppCoordinator — state updates drive UI reactively
- Error handling via macOS notifications (Phase 2 pattern: "No se detectó voz", "Error de transcripción")

### Integration Points
- `AppCoordinator.handleHotkey()` line 64-68 — insert Haiku cleanup call between `sttEngine?.transcribe(buffer)` and `textInjector?.inject(text)`
- `AppDelegate.applicationDidFinishLaunching` — initialize HaikuCleanup service, check for API key
- `StatusMenuView` — add "API Key" option to menubar dropdown
- `Package.swift` — no new SPM dependencies needed (URLSession is built-in)

</code_context>

<specifics>
## Specific Ideas

- Fallback philosophy: "el usuario siempre recibe texto" — degraded quality beats no output
- Haiku is a text cleanup tool, not a rewriter — the prompt must be strict about preserving original wording
- API key modal should feel native macOS, not like a web form

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 03-haiku-cleanup*
*Context gathered: 2026-03-16*
