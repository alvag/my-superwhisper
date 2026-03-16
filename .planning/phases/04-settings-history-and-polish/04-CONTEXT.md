# Phase 4: Settings, History, and Polish - Context

**Gathered:** 2026-03-16
**Status:** Ready for planning

<domain>
## Phase Boundary

Configurable settings UI, transcription history panel, custom vocabulary corrections, and distribution readiness. Delivers a polished v1 experience: users can customize the hotkey, select microphone, review past transcriptions, define word corrections, and the app is signed/notarized for distribution. No new pipeline features — this phase wraps the existing record→transcribe→cleanup→paste pipeline with user-facing configuration and polish.

</domain>

<decisions>
## Implementation Decisions

### Settings UI
- Panel único (no tabs, no sidebar) — una sola ventana con todas las configuraciones visibles
- Contiene: grabador de hotkey, selector de micrófono, clave API (mover desde menú actual), tabla de vocabulario, toggle de inicio al arranque
- Accesible desde "Preferencias..." en el menú del menubar (stub ya existe en StatusMenuView.swift:31)
- Ventana nativa macOS — SwiftUI o AppKit, debe sentirse como app de sistema

### Configuración de Hotkey (REC-05)
- Click-to-record: botón "Grabar", campo muestra "Presiona tu atajo...", usuario presiona combo, campo se actualiza
- Cambio toma efecto inmediatamente — se desregistra el HotKey viejo y se registra el nuevo sin reiniciar
- Default sigue siendo Option+Space (Phase 1)
- Persistir la selección en UserDefaults

### Selector de Micrófono (MAC-04)
- Dropdown con lista de dispositivos de entrada disponibles via AVAudioEngine
- Default: micrófono del sistema (default input device)
- Cambio toma efecto en la siguiente grabación — no requiere reinicio de app

### Historial de Transcripciones (OUT-03, OUT-04)
- Accesible desde item "Historial" en el menú del menubar — abre ventana separada
- Lista de últimas 20 entradas, cada una muestra texto limpio truncado + timestamp
- Click en entrada = copia texto completo al portapapeles + notificación "Texto copiado"
- Almacenado en UserDefaults/plist — suficiente para 20 entradas de texto
- FIFO: al llegar a 20, la más antigua se elimina automáticamente

### Correcciones de Vocabulario (VOC-01, VOC-02)
- Tabla editable de dos columnas (Incorrecto → Correcto) dentro del panel de Preferencias
- Botón [+] agrega fila vacía, [-] elimina fila seleccionada, edición inline
- Case-insensitive: "cluad" matchea "Cluad" y "CLUAD", reemplazo usa la forma definida por el usuario
- Aplicadas DESPUÉS de Haiku cleanup (VOC-02) — evita que Haiku deshaga las correcciones
- Persistidas en UserDefaults como array de pares [incorrecto, correcto]

### Distribución y Polish
- DMG firmado con Developer ID + notarización de Apple
- Ícono de app personalizado
- Ventana "Acerca de" con versión y créditos
- Toggle "Iniciar al arranque" en Preferencias (desactivado por defecto), usa SMAppService
- Presupuesto RAM idle: <200MB (MAC-05 de REQUIREMENTS.md) — el modelo WhisperKit se mantiene en memoria para evitar cold-start

### Claude's Discretion
- Dimensiones exactas de la ventana de Preferencias
- Diseño del DMG (fondo, posición de iconos)
- Estilo del ícono de la app
- Contenido exacto de la ventana "Acerca de"
- Implementación del hotkey recorder (NSEvent monitoring approach)
- Formato del timestamp en el historial
- Simple string replacement vs regex para correcciones de vocabulario

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project Context
- `.planning/PROJECT.md` — Visión del proyecto, constraints (local STT, Apple Silicon, Spanish only v1)
- `.planning/REQUIREMENTS.md` — REC-05, MAC-04, MAC-05, OUT-03, OUT-04, VOC-01, VOC-02 requirements para esta fase
- `.planning/ROADMAP.md` — Phase 4 success criteria y dependencia de Phase 3

### Prior Phase Context
- `.planning/phases/01-foundation/01-CONTEXT.md` — Hotkey behavior (Option+Space), menubar states, overlay, paste mechanism
- `.planning/phases/02-audio-transcription/02-CONTEXT.md` — AudioRecorder, AVAudioEngine setup, WhisperKit integration
- `.planning/phases/03-haiku-cleanup/03-CONTEXT.md` — HaikuCleanupService, Keychain storage, API key modal, error handling

### Architecture
- `.planning/research/ARCHITECTURE.md` — Component architecture, FSM design, data flow
- `.planning/research/STACK.md` — Swift/SwiftUI stack, HotKey library (soffes v0.2.1), AVFoundation

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `StatusMenuView.swift` — "Preferencias..." stub (line 31) listo para implementar. "Clave de API..." ya funciona — mover a Settings
- `HotkeyMonitor.swift` — HotKey(key: .space, modifiers: [.option]) hardcoded. Phase 4 lo hace configurable
- `AudioRecorder.swift` — AVAudioEngine con inputNode. Phase 4 agrega selección de dispositivo de entrada
- `APIKeyWindowController.swift` — Modal de API key existente. Puede reutilizarse o integrarse en Settings
- `HaikuCleanupService.swift` — Pipeline cleanup. Phase 4 agrega paso de vocabulario post-Haiku
- `NotificationHelper.swift` — Notificaciones macOS nativas. Reutilizar para "Texto copiado" del historial

### Established Patterns
- Protocol-based DI (`AudioRecorderProtocol`, `HaikuCleanupProtocol`, `STTEngineProtocol`) — nuevos servicios siguen mismo patrón
- `@Observable` + `@MainActor` en AppCoordinator — state updates reactivos
- UserDefaults para persistencia simple (nuevo patrón en Phase 4, consistente con macOS best practices)
- NSPanel/NSWindow para ventanas auxiliares (APIKeyWindowController como referencia)

### Integration Points
- `AppCoordinator.handleHotkey()` — agregar paso de vocabulario después de Haiku cleanup, antes de inject
- `AppDelegate.applicationDidFinishLaunching` — cargar hotkey desde UserDefaults, inicializar servicios
- `StatusMenuController.buildMenu()` — agregar item "Historial", conectar "Preferencias..."
- `HotkeyMonitor` — refactorizar para aceptar key/modifiers dinámicos

</code_context>

<specifics>
## Specific Ideas

- Settings debe sentirse como app nativa de macOS — no como web form
- Click-to-record para hotkey: mismo patrón que Shortcuts.app de macOS
- Historial es de acceso rápido — click = copiar, sin pasos intermedios
- Vocabulario es para nombres propios y términos técnicos que el STT consistentemente transcribe mal

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 04-settings-history-and-polish*
*Context gathered: 2026-03-16*
