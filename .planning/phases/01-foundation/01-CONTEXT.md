# Phase 1: Foundation - Context

**Gathered:** 2026-03-15
**Status:** Ready for planning

<domain>
## Phase Boundary

macOS app shell with global hotkey, menubar status icon, recording overlay, paste mechanism, and permission management. No ML models — this phase establishes the system integration layer that all subsequent phases build on. Audio capture happens but is discarded (no STT yet).

</domain>

<decisions>
## Implementation Decisions

### Menubar & States
- Microphone icon in menubar that changes color by state: gray (idle), red (recording), blue (processing), green flash (done → returns to gray)
- Dropdown menu contains: current status text, configured hotkey display, Settings option, Quit option
- Recording state also shows a floating overlay window with waveform animation near center of screen (in addition to red menubar icon)
- When processing completes and text is pasted, no explicit feedback — text appearing at cursor is sufficient
- "Done" state: icon does NOT flash green — just returns to idle silently (user said "sin feedback")

### Hotkey Behavior
- Default hotkey: Option+Space (NOT Ctrl+Space — macOS input source conflict)
- Toggle mode: first press starts recording, second press stops and triggers pipeline
- If hotkey pressed during processing state: IGNORED — no action until pipeline completes
- Escape during recording: cancels immediately with a subtle system sound, overlay disappears, icon returns to gray, no text pasted

### Permissions UX
- Permissions requested on-the-fly: microphone permission when first recording starts, accessibility permission when first paste attempt happens
- If user denies any permission: app shows a blocking screen explaining what the permission is for and how to enable it in System Settings (with a "Open System Settings" button)
- Permission health check on every launch: if previously granted permission is revoked (e.g., after OS update), surface the same blocking screen immediately

### Paste & Clipboard
- Paste mechanism: set clipboard to transcribed text, then simulate Cmd+V via CGEventPost
- Clipboard is OVERWRITTEN with transcribed text (not preserved/restored) — user can re-paste the text later
- If paste simulation fails (app blocks it): leave text in clipboard + show macOS notification "Texto copiado — pegá con Cmd+V"
- Non-sandboxed app required for CGEventPost — distribute via Developer ID, not Mac App Store

### Claude's Discretion
- Exact overlay window dimensions and positioning
- Waveform animation style (sine wave, frequency bars, etc.)
- System sound choice for cancel action
- Internal state machine design (FSM states and transitions)
- Code signing and entitlements configuration

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project Context
- `.planning/PROJECT.md` — Project vision, constraints, key decisions (Haiku API for cleanup, local STT)
- `.planning/REQUIREMENTS.md` — Full v1 requirements with REQ-IDs mapped to this phase
- `.planning/ROADMAP.md` — Phase 1 success criteria and requirement mapping

### Research
- `.planning/research/ARCHITECTURE.md` — Component architecture, FSM design, data flow, build order
- `.planning/research/STACK.md` — Swift/SwiftUI stack, HotKey library (soffes v0.2.1), AVFoundation, CGEventPost
- `.planning/research/PITFALLS.md` — Ctrl+Space conflict, sandbox restriction, permission resets, code signing requirement

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- None — greenfield project, no existing code

### Established Patterns
- None yet — this phase establishes the foundational patterns (FSM, menubar, overlay)

### Integration Points
- Phase 2 will connect: AudioRecorder feeding into this phase's state machine
- Phase 3 will connect: Haiku API client wiring into the processing state
- Phase 4 will connect: Settings UI extending the menubar dropdown

</code_context>

<specifics>
## Specific Ideas

- App inspired by SuperWhisper — floating overlay during recording is a key UX reference
- Menubar behavior similar to macOS native apps (not Electron-style tray icons)
- The overlay should feel native and minimal — not flashy or distracting

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 01-foundation*
*Context gathered: 2026-03-15*
