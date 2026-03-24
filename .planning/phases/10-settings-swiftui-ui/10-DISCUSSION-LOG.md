# Phase 10: Settings SwiftUI UI - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-03-24
**Phase:** 10-settings-swiftui-ui
**Areas discussed:** Organización de secciones, Edición de vocabulario, Estilo visual, Presentación de API key

---

## Organización de secciones

| Option | Description | Selected |
|--------|-------------|----------|
| 4 secciones temáticas | Grabación (hotkey, mic, pausar, volumen), API (botón clave), Vocabulario (lista), Sistema (launch at login) | ✓ |
| 3 secciones (compacto) | Grabación, Vocabulario, General (API + login) | |
| 2 secciones (mínimo) | Grabación (todo menos vocab), Vocabulario | |

**User's choice:** 4 secciones temáticas
**Notes:** Clara separación por dominio. Cada sección tiene un propósito distinto.

### Idioma de la UI

| Option | Description | Selected |
|--------|-------------|----------|
| Español | Todo en español: secciones, labels, placeholders | ✓ |
| Inglés | Todo en inglés | |
| Mixto | Secciones español, términos técnicos inglés | |

**User's choice:** Español
**Notes:** Consistente con que la app es para dictado en español.

### Orden en sección Grabación

| Option | Description | Selected |
|--------|-------------|----------|
| Hotkey → Mic → Pausar → Volumen | Orden propuesto por Claude | ✓ |
| Tú decides | Claude elige | |

**User's choice:** El orden propuesto está bien.

---

## Edición de vocabulario

| Option | Description | Selected |
|--------|-------------|----------|
| Botón + y botón - | Explícitos, no depende de Delete key ni swipe | ✓ |
| Swipe to delete + botón + | onDelete modifier, más limpio pero menos obvio en macOS | |
| Tú decides | Claude elige | |

**User's choice:** Botón + y botón -
**Notes:** Evita la dependencia de Delete key en SwiftUI List (blocker documentado en STATE.md).

### Entradas vacías

| Option | Description | Selected |
|--------|-------------|----------|
| Ignorar silenciosamente | No se aplican en pipeline, no se auto-eliminan | ✓ |
| Auto-eliminar al perder foco | Se borran si ambos campos están vacíos | |
| Tú decides | Claude elige | |

**User's choice:** Ignorar silenciosamente

---

## Estilo visual

### Iconos en secciones

| Option | Description | Selected |
|--------|-------------|----------|
| Sí, con iconos | SF Symbols junto al título de cada sección | ✓ |
| No, solo texto | Texto plano en headers | |
| Tú decides | Claude elige | |

**User's choice:** Sí, con SF Symbols

### Tamaño de ventana

| Option | Description | Selected |
|--------|-------------|----------|
| Auto-sizing | NSHostingController calcula fittingSize | ✓ |
| Tamaño fijo | Dimensiones fijas con scroll | |
| Tú decides | Claude elige | |

**User's choice:** Auto-sizing

---

## Presentación de API key

| Option | Description | Selected |
|--------|-------------|----------|
| Botón simple | Solo botón "Configurar clave API..." que abre modal existente | ✓ |
| Botón + indicador de estado | Botón + checkmark verde/rojo según si hay clave configurada | |
| Tú decides | Claude elige | |

**User's choice:** Botón simple
**Notes:** Sin indicador de estado visible. El modal existente se mantiene.

---

## Claude's Discretion

- SF Symbols exactos para cada sección
- Placeholders de TextFields de vocabulario
- Spacing/padding del Form
- Label del Picker de micrófono
- Estilo del botón [-] en vocabulario

## Deferred Ideas

None — discussion stayed within phase scope.
