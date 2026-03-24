# Phase 10: Settings SwiftUI UI - Context

**Gathered:** 2026-03-24
**Status:** Ready for planning

<domain>
## Phase Boundary

Migrar todo el contenido de Settings a un SwiftUI Form completo con 4 secciones agrupadas (Grabación, API, Vocabulario, Sistema), estilo System Settings de macOS. El SettingsViewModel y SettingsWindowController ya están implementados (Phase 9) — esta fase es puramente UI: expandir SettingsView.swift con todas las secciones y controles funcionales.

</domain>

<decisions>
## Implementation Decisions

### Organización de secciones
- **D-01:** 4 secciones temáticas: Grabación, API, Vocabulario, Sistema.
- **D-02:** Orden dentro de Grabación: (1) Hotkey recorder, (2) Picker micrófono, (3) Toggle pausar reproducción, (4) Toggle maximizar volumen.
- **D-03:** Sección API: solo botón "Configurar clave API..." que abre el modal existente (APIKeyWindowController). Sin indicador de estado de la clave.
- **D-04:** Sección Vocabulario: lista editable con TextField inline (wrong → correct).
- **D-05:** Sección Sistema: toggle "Iniciar al arranque" (launch at login).

### Idioma de la UI
- **D-06:** Todo en español — nombres de secciones, labels, placeholders. Términos técnicos que no tienen traducción natural (API, hotkey) se mantienen.

### Edición de vocabulario
- **D-07:** Botones +/- explícitos para agregar y eliminar entradas. Botón [+] debajo de la lista agrega fila vacía. Botón [-] al lado de cada fila la elimina. NO depende de Delete key ni swipe-to-delete.
- **D-08:** Entradas con campos vacíos se ignoran silenciosamente en el pipeline (no se aplican como correcciones). No se auto-eliminan — el usuario las limpia manualmente con [-].

### Estilo visual
- **D-09:** SF Symbols como iconos en los headers de sección (Label con systemImage). Ej: mic.fill, key.fill, textformat, gear.
- **D-10:** Auto-sizing de ventana — NSHostingController calcula fittingSize automáticamente. Sin dimensiones fijas.
- **D-11:** `.formStyle(.grouped)` ya establecido en Phase 9 — se mantiene.

### Presentación de API key
- **D-12:** Botón simple "Configurar clave API..." que llama `viewModel.openAPIKey()`. Sin indicador de estado visible. El modal existente (APIKeyWindowController/NSPanel) se mantiene sin cambios.

### Claude's Discretion
- SF Symbols exactos para cada sección (sugeridos: mic.fill, key.fill, textformat.abc, gear)
- Placeholders de los TextFields de vocabulario
- Spacing y padding dentro del Form
- Label exacto del Picker de micrófono
- Estilo del botón [-] en cada fila de vocabulario (destructive, plain, icon-only, etc.)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Current Implementation
- `MyWhisper/Settings/SettingsView.swift` — SwiftUI Form actual con 1 sección placeholder (Grabación con hotkey + 1 toggle). ESTE es el archivo principal a expandir.
- `MyWhisper/Settings/SettingsViewModel.swift` — @Observable VM completo con todas las propiedades: pausePlaybackEnabled, maximizeMicVolumeEnabled, launchAtLoginEnabled, selectedMicID, vocabularyEntries, openAPIKey, availableMics.
- `MyWhisper/Settings/SettingsWindowController.swift` — NSWindow + NSHostingController, lifecycle resuelto. NO requiere cambios en Phase 10.

### Data Types
- `MyWhisper/Vocabulary/VocabularyEntry.swift` — `struct VocabularyEntry: Codable, Equatable { var wrong: String; var correct: String }`
- `MyWhisper/Audio/MicrophoneDeviceService.swift` — `struct AudioDeviceInfo: Identifiable { let id: AudioDeviceID; let name: String }`

### API Key Modal
- `MyWhisper/UI/APIKeyWindowController.swift` — NSPanel modal existente. Se abre via `viewModel.openAPIKey()` closure. NO requiere cambios.

### Prior Phase Context
- `.planning/phases/09-window-lifecycle-foundation/09-CONTEXT.md` — Decisiones de window lifecycle, NSHostingController pattern, @Observable + didSet
- `.planning/REQUIREMENTS.md` — UI-01 a UI-07 requirements para esta fase

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `SettingsViewModel` — VM completo, listo para bindear. Todas las propiedades expuestas con `@Bindable`.
- `KeyboardShortcuts.Recorder` — Ya integrado en SettingsView (Phase 9). Solo moverlo a su posición final dentro de la sección Grabación.
- `VocabularyEntry` — Struct simple Codable/Equatable. Bindeable via `$viewModel.vocabularyEntries`.
- `AudioDeviceInfo` — Identifiable, listo para Picker SwiftUI.
- `openAPIKey` closure — Ya wired desde SettingsWindowController al APIKeyWindowController.

### Established Patterns
- `@Observable` + `didSet` + `UserDefaults.standard.set` para persistencia (NO @AppStorage).
- `.formStyle(.grouped)` para layout inset-grouped estilo System Settings.
- `@Bindable var viewModel` para two-way binding en la View.
- SMAppService.mainApp para launch at login.

### Integration Points
- `SettingsView.swift` es el ÚNICO archivo que necesita cambios significativos — expandir el Form con las 4 secciones.
- `SettingsViewModel.swift` puede necesitar `Identifiable` conformance en `VocabularyEntry` si ForEach lo requiere (validar — actualmente no conforma Identifiable).
- El `minWidth`/`minHeight` del frame puede necesitar ajuste para acomodar el contenido expandido.

</code_context>

<specifics>
## Specific Ideas

- El Form debe verse como System Settings de macOS — agrupado, limpio, nativo.
- Botones +/- para vocabulario siguen el patrón de listas editables de System Settings.
- Los toggles deben ser Toggles nativos de SwiftUI (no switches custom).
- El Picker de micrófono debe mostrar los nombres de los dispositivos de audio disponibles.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 10-settings-swiftui-ui*
*Context gathered: 2026-03-24*
