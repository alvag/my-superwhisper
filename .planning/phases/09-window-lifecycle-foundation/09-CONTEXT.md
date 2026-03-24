# Phase 9: Window Lifecycle Foundation - Context

**Gathered:** 2026-03-24
**Status:** Ready for planning

<domain>
## Phase Boundary

Reemplazar NSPanel con NSWindow en SettingsWindowController para que la ventana de Settings permanezca abierta cuando el usuario hace click fuera de ella. Validar el ciclo completo: abrir desde menubar, persistir con foco externo, aceptar keyboard input, cerrar con X/Cmd+W, restaurar activation policy, y devolver foco a la app anterior. Incluir contenido SwiftUI parcial (1-2 settings reales) para validar el hosting y dar ventaja a Phase 10.

</domain>

<decisions>
## Implementation Decisions

### Window Type
- **D-01:** Reemplazar `NSPanel` con `NSWindow` — NSPanel tiene `hidesOnDeactivate = true` por defecto, que es la causa raíz del bug. NSWindow con `[.titled, .closable]` no se cierra al perder foco.
- **D-02:** `isReleasedWhenClosed = false` — la instancia persiste en memoria entre aperturas.

### Window Close Behavior
- **D-03:** Botón X / Cmd+W oculta la ventana con `orderOut(nil)` en lugar de destruirla. El estado SwiftUI se preserva entre aperturas. NO hacer `self.panel = nil` en `windowWillClose` (patrón actual que destruye).
- **D-04:** La ventana reutiliza la misma instancia — `show()` hace `makeKeyAndOrderFront` sobre la ventana existente.

### Activation Policy & Focus
- **D-05:** `NSApp.setActivationPolicy(.regular)` en `show()`, `NSApp.setActivationPolicy(.accessory)` en close handler.
- **D-06:** `NSApp.hide(nil)` después de restaurar `.accessory` para devolver el foco a la app anterior y eliminar el dock icon.
- **D-07:** `NSApp.activate(ignoringOtherApps: true)` antes de `makeKeyAndOrderFront` para garantizar keyboard input.

### SwiftUI Hosting
- **D-08:** Usar `NSHostingController` (no `NSHostingView`) como `contentViewController` del NSWindow — el window auto-dimensiona al `fittingSize` del SwiftUI Form.
- **D-09:** NO usar SwiftUI Settings scene ni `openSettings` environment action — roto en macOS 26 Tahoe y poco fiable en apps `.accessory`.

### Contenido Placeholder (Parcial)
- **D-10:** Phase 9 incluye 1-2 settings reales migrados a SwiftUI (ej: hotkey recorder + un toggle) para validar que el hosting funciona end-to-end y reducir trabajo de Phase 10.
- **D-11:** El resto de settings se migra en Phase 10.

### Claude's Discretion
- Cuáles 1-2 settings migrar como placeholder (idealmente los que mejor validen keyboard input y data binding)
- Dimensiones exactas del NSWindow
- Orden de ejecución de `setActivationPolicy` / `activate` / `makeKeyAndOrderFront`

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Current Implementation
- `MyWhisper/Settings/SettingsWindowController.swift` — 305 líneas AppKit actuales, NSPanel, toda la lógica de lifecycle que se reemplaza
- `MyWhisper/App/AppDelegate.swift` §122-139 — `showPermissionBlockedWindow()` precedente existente de NSWindow + NSHostingView

### Research
- `.planning/research/SUMMARY.md` — Síntesis completa: stack, features, architecture, pitfalls
- `.planning/research/STACK.md` — NSWindow vs NSPanel, Form patterns, KeyboardShortcuts.Recorder
- `.planning/research/ARCHITECTURE.md` — Integration points, SettingsViewModel pattern, build order
- `.planning/research/PITFALLS.md` — 7 pitfalls críticos, especialmente activation policy y window lifecycle

### Project Context
- `.planning/PROJECT.md` — Constraints (macOS only, Apple Silicon, non-sandboxed)
- `.planning/REQUIREMENTS.md` — WIN-01 a WIN-04 requirements para esta fase
- `.planning/ROADMAP.md` — Phase 9 success criteria

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `AppDelegate.showPermissionBlockedWindow()` — Patrón NSWindow + NSHostingView ya funcional en el proyecto. Referencia directa para el approach.
- `OverlayWindowController` — Otro ejemplo de NSPanel + NSHostingView para la visualización de waveform.
- `KeyboardShortcuts.RecorderCocoa` — Actualmente en SettingsWindowController, migrar a `KeyboardShortcuts.Recorder` (SwiftUI variant) en Phase 10.

### Established Patterns
- Activation policy toggle: `show()` cambia a `.regular`, `windowWillClose` restaura `.accessory`. Ya implementado pero con `self.panel = nil` (debe cambiar a `orderOut`).
- Protocol-based DI: `VocabularyService`, `MicrophoneDeviceService`, `HaikuCleanupProtocol` inyectados al controller.

### Integration Points
- `StatusMenuController.openSettings()` — Llama a `SettingsWindowController.show()`. No necesita cambios.
- `AppDelegate` — Crea `SettingsWindowController` con dependencias. La firma del init puede mantenerse.

</code_context>

<specifics>
## Specific Ideas

- La ventana debe comportarse como System Preferences de macOS — persiste hasta cierre explícito
- orderOut en lugar de close para preservar estado SwiftUI
- `NSApp.hide(nil)` para devolver foco limpiamente a la app anterior

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 09-window-lifecycle-foundation*
*Context gathered: 2026-03-24*
