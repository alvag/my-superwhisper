# Milestones

## v1.2 Dictation Quality (Shipped: 2026-03-17)

**Phases completed:** 2 phases, 5 plans, 0 tasks

**Key accomplishments:**
- (none recorded)

---

## v1.1 Pause Playback (Shipped: 2026-03-17)

**Phases completed:** 2 phases, 4 plans, 8 tasks
**LOC added:** ~150 production + ~200 test Swift

**Key accomplishments:**
- MediaPlaybackService: HID media key pause/resume via CGEventPost(.cghidEventTap) — works with Spotify, Apple Music, YouTube/Safari
- AppCoordinator FSM integration: pause on recording start, resume on stop/escape/error, 150ms delay for Spotify fade-out
- Settings toggle "Pausar reproduccion al grabar" con UserDefaults persistente (default: ON)
- isAnyMediaAppRunning() guard: previene lanzamiento de Music.app cuando no hay reproductor activo
- 11 unit tests (7 coordinator + 4 service) + 14 escenarios QA manual todos PASS
- Verificacion end-to-end: Spotify, Apple Music, YouTube/Safari, double-tap, toggle OFF, Music.app guard

---

## v1.0 MVP (Shipped: 2026-03-16)

**Phases completed:** 4 phases, 13 plans, 2 tasks

**Key accomplishments:**
- (none recorded)

---

