# Requirements: My SuperWhisper

**Defined:** 2026-03-17
**Core Value:** Frictionless voice-to-text that produces clean, well-formatted Spanish text

## v1.2 Requirements

Requirements for v1.2 Dictation Quality. Each maps to roadmap phases.

### Haiku Cleanup

- [ ] **HAIKU-01**: Haiku system prompt includes explicit Rule 6 prohibiting addition of words not present in the input (specifically "gracias", "de nada", "hasta luego")
- [ ] **HAIKU-02**: Post-processing suffix strip removes hallucinated courtesy phrases as safety net when not present in raw transcription
- [ ] **HAIKU-03**: Existing cleanup behavior (punctuation, capitalization, filler removal, paragraph breaks) is unaffected by prompt changes — regression verified

### Input Volume

- [ ] **VOL-01**: App saves current mic input volume level before recording starts
- [ ] **VOL-02**: App sets mic input volume to maximum (1.0) when recording starts
- [ ] **VOL-03**: App restores original mic input volume when recording stops (all exit paths: success, cancel, error)
- [ ] **VOL-04**: App silently skips volume control when device does not expose settable input volume (graceful degradation)
- [ ] **VOL-05**: Volume restore works correctly when mic device changes between start and stop

## Future Requirements

### Haiku Cleanup

- **HAIKU-04**: Configurable list of prohibited hallucination phrases (beyond hardcoded list)

## Out of Scope

| Feature | Reason |
|---------|--------|
| Output volume (speakers) control | Only input mic volume is relevant for recording quality |
| AGC (automatic gain control) toggle | Over-engineering for v1.2; max volume is sufficient |
| WhisperKit-level "gracias" filtering | Prompt + post-processing dual-layer is sufficient; WhisperKit config changes are higher risk |
| Multi-channel mic volume control | Defer — most users have single-channel input devices |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| HAIKU-01 | — | Pending |
| HAIKU-02 | — | Pending |
| HAIKU-03 | — | Pending |
| VOL-01 | — | Pending |
| VOL-02 | — | Pending |
| VOL-03 | — | Pending |
| VOL-04 | — | Pending |
| VOL-05 | — | Pending |

**Coverage:**
- v1.2 requirements: 8 total
- Mapped to phases: 0
- Unmapped: 8 ⚠️

---
*Requirements defined: 2026-03-17*
*Last updated: 2026-03-17 after initial definition*
