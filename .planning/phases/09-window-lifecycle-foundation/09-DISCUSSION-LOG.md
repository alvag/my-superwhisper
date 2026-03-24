# Phase 9: Window Lifecycle Foundation - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-03-24
**Phase:** 09-window-lifecycle-foundation
**Areas discussed:** Cierre de ventana, Foco al cerrar, Contenido placeholder

---

## Cierre de ventana

| Option | Description | Selected |
|--------|-------------|----------|
| Ocultar (orderOut) | La ventana se esconde pero el estado se preserva. Reapertura instantánea. Patrón común en System Preferences | ✓ |
| Destruir (close) | La ventana se destruye y se recrea al reabrir. Estado siempre fresco desde UserDefaults | |

**User's choice:** Ocultar (orderOut)
**Notes:** Patrón recomendado por research — preserva estado SwiftUI, reapertura instantánea.

---

## Foco al cerrar

| Option | Description | Selected |
|--------|-------------|----------|
| Volver a app anterior | NSApp.hide(nil) + .accessory — foco vuelve automáticamente a la app activa antes | ✓ |
| Solo desaparecer | Solo .accessory sin hide — puede dejar ventana en app switcher momentáneamente | |
| Tú decide | Claude elige el approach más robusto | |

**User's choice:** Volver a app anterior
**Notes:** NSApp.hide(nil) necesario para eliminar dock icon y devolver foco limpiamente.

---

## Contenido placeholder

| Option | Description | Selected |
|--------|-------------|----------|
| Form mínimo | Un SwiftUI Form con un TextField y un Toggle de prueba | |
| Settings reales parcial | Empezar migrando 1-2 settings reales (ej: hotkey + un toggle) | ✓ |
| Tú decide | Claude elige lo más pragmático para validar el lifecycle | |

**User's choice:** Settings reales parcial
**Notes:** Adelanta trabajo de Phase 10. Claude decide cuáles 1-2 settings migrar como placeholder.

---

## Claude's Discretion

- Cuáles 1-2 settings específicos migrar como placeholder
- Dimensiones exactas del NSWindow
- Secuencia exacta de activation policy / activate / makeKeyAndOrderFront

## Deferred Ideas

None — discussion stayed within phase scope.
