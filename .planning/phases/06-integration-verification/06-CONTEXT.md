# Phase 6: Integration Verification - Context

**Gathered:** 2026-03-17
**Status:** Ready for planning

<domain>
## Phase Boundary

Verify that Pause Playback (Phase 5) works correctly across target media players and edge cases before shipping v1.1. No new features — purely validation, documentation of limitations, and potential fix for the Music.app launch issue.

</domain>

<decisions>
## Implementation Decisions

### Test Methodology
- Manual checklist in PLAN.md — user executes step-by-step and marks results
- Checklist queda como evidencia de QA reutilizable para v1.1
- No scripts semi-automatizados ni AppleScript — verificación humana directa
- App ya compilada y corriendo — no incluir build step en la fase

### Player Coverage (Obligatorios)
- Spotify — reproductor principal del usuario, HID media keys confirmados
- Apple Music — app nativa macOS, riesgo de lanzamiento espontáneo
- YouTube en Safari — navegador nativo con media keys activos
- VLC excluido de la matriz obligatoria
- Chrome/Firefox excluidos — documentar como "debería funcionar" sin test formal

### Music.app Launch Issue — CRÍTICO
- Si Music.app se lanza sola al enviar pause sin nada reproduciendo, es un bug que debe resolverse antes de enviar
- Investigar si hay forma de detectar playback activo antes de enviar pause key
- Si se puede detectar: no enviar pause cuando nada suena
- Si macOS no ofrece API: este punto necesita re-evaluación (¿desactivar por defecto? ¿aceptar como limitación?)
- Nota: Phase 5 decidió "no detectar si algo suena" — esta fase puede cambiar esa decisión si Music.app launch es reproducible

### Manejo de Incompatibilidades
- Documentar como limitación en VERIFICATION.md (no archivo separado)
- No bloquea release — solo documenta comportamiento observado
- Excepción: Music.app launch SÍ bloquea release (marcado como crítico)

### Success Criteria Alignment
- Criterio #3 del roadmap dice "minimum-duration guard holds" pero Phase 5 decidió no usar guard
- El criterio real es: "rapid double-tap no deja media en estado incorrecto" — verificar empíricamente sin guard

### Claude's Discretion
- Formato exacto de la tabla de resultados en VERIFICATION.md
- Orden de los escenarios en el checklist
- Si incluir screenshots o logs como evidencia

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase 5 Implementation (lo que se verifica)
- `MyWhisper/System/MediaPlaybackService.swift` — Implementación HID media keys, flags pausedByApp/isEnabled
- `MyWhisper/Coordinator/AppCoordinator.swift` — Integration points: pause, resume, delay 150ms
- `MyWhisper/Settings/SettingsWindowController.swift` — Toggle "Pausar reproducción al grabar"

### Phase 5 Context & Research
- `.planning/phases/05-pause-playback-implementation/05-CONTEXT.md` — Decisiones locked de implementación
- `.planning/phases/05-pause-playback-implementation/05-RESEARCH.md` — Pitfalls conocidos, Music.app edge case
- `.planning/phases/05-pause-playback-implementation/05-VERIFICATION.md` — Human verification items pendientes

### Project
- `.planning/ROADMAP.md` — Phase 6 success criteria
- `.planning/REQUIREMENTS.md` — MEDIA-01..04, SETT-01..02 (Phase 5, verificados aquí)

</canonical_refs>

<code_context>
## Existing Code Insights

### Relevant Implementation
- `MediaPlaybackService.swift` (46 lines) — `pause()` guards on `isEnabled`, `resume()` guards on `pausedByApp`. Ambos envían `NX_KEYTYPE_PLAY` via `CGEventPost(.cghidEventTap)`
- `AppCoordinator.swift` — 1 `pause()` call (idle→recording), 3 `resume()` calls (start failure, recording→processing, escape cancel)
- `SettingsWindowController.swift` — Section 6 checkbox, UserDefaults key `pausePlaybackEnabled`

### Potential Fix Point (Music.app issue)
- `MediaPlaybackService.pause()` — si se implementa detección de playback activo, el guard iría aquí antes de `postMediaKeyToggle()`
- Opciones técnicas para detectar playback: `MRMediaRemoteGetNowPlayingInfo` (broken macOS 15.4+), observar `NSWorkspace.runningApplications` para apps multimedia, o `CGEventTapCreate` para interceptar media key responses

### Test Infrastructure
- `MyWhisperTests/AppCoordinatorTests.swift` — 22 tests incluyendo 7 media playback mocks
- `MyWhisperTests/MediaPlaybackServiceTests.swift` — 4 tests de lógica interna

</code_context>

<specifics>
## Specific Ideas

- Music.app lanzándose sola es el escenario más preocupante — priorizar en la verificación
- El usuario usa Spotify como reproductor principal — debe funcionar perfectamente ahí
- Rapid double-tap es un escenario real (usuario presiona hotkey dos veces rápido por error)

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 06-integration-verification*
*Context gathered: 2026-03-17*
