# Phase 10: Settings SwiftUI UI - Research

**Researched:** 2026-03-24
**Domain:** SwiftUI Form (macOS), @Observable bindings, inline editable list, SF Symbols
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** 4 secciones temáticas: Grabación, API, Vocabulario, Sistema.
- **D-02:** Orden dentro de Grabación: (1) Hotkey recorder, (2) Picker micrófono, (3) Toggle pausar reproducción, (4) Toggle maximizar volumen.
- **D-03:** Sección API: solo botón "Configurar clave API..." que abre el modal existente (APIKeyWindowController). Sin indicador de estado de la clave.
- **D-04:** Sección Vocabulario: lista editable con TextField inline (wrong → correct).
- **D-05:** Sección Sistema: toggle "Iniciar al arranque" (launch at login).
- **D-06:** Todo en español — nombres de secciones, labels, placeholders. Términos técnicos sin traducción natural (API, hotkey) se mantienen.
- **D-07:** Botones +/- explícitos para agregar y eliminar entradas. Botón [+] debajo de la lista agrega fila vacía. Botón [-] al lado de cada fila la elimina. NO depende de Delete key ni swipe-to-delete.
- **D-08:** Entradas con campos vacíos se ignoran silenciosamente en el pipeline. No se auto-eliminan.
- **D-09:** SF Symbols como iconos en los headers de sección (Label con systemImage). Ej: mic.fill, key.fill, textformat, gear.
- **D-10:** Auto-sizing de ventana — NSHostingController calcula fittingSize automáticamente. Sin dimensiones fijas.
- **D-11:** `.formStyle(.grouped)` ya establecido en Phase 9 — se mantiene.
- **D-12:** Botón simple "Configurar clave API..." que llama `viewModel.openAPIKey()`. Sin indicador de estado visible.

### Claude's Discretion

- SF Symbols exactos para cada sección (sugeridos: mic.fill, key.fill, textformat.abc, gear)
- Placeholders de los TextFields de vocabulario
- Spacing y padding dentro del Form
- Label exacto del Picker de micrófono
- Estilo del botón [-] en cada fila de vocabulario (destructive, plain, icon-only, etc.)

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| UI-01 | Settings usa SwiftUI Form con `.formStyle(.grouped)` como layout principal | Ya establecido en Phase 9; investigación confirma que es la API correcta en macOS |
| UI-02 | Settings agrupados en secciones lógicas: Grabación, Transcripción, Vocabulario, Sistema | Pattern SwiftUI `Section` con header `Label(systemImage:)` — confirmado HIGH confidence |
| UI-03 | El hotkey recorder usa `KeyboardShortcuts.Recorder` nativo de SwiftUI | Recorder.swift en el checkout local confirma la API: `KeyboardShortcuts.Recorder("label", name: .name)` |
| UI-04 | El selector de micrófono funciona como `Picker` SwiftUI con los dispositivos disponibles | `AudioDeviceInfo` ya es `Identifiable`; Picker con optional `AudioDeviceID?` requiere `.tag(nil as AudioDeviceID?)` para la opción "ninguno" |
| UI-05 | Las correcciones de vocabulario son editables en una `List` con `TextField` inline | `ForEach($viewModel.vocabularyEntries)` con binding syntax requiere que `VocabularyEntry` sea `Identifiable` — GAP identificado |
| UI-06 | Los toggles (launch at login, pause playback, maximize volume) funcionan y persisten estado | Todos los toggles ya wired en `SettingsViewModel` con `didSet + UserDefaults`; solo falta agregarlos a la View |
| UI-07 | El botón de API key abre el panel existente de ingreso de clave | `viewModel.openAPIKey()` ya está wired desde `SettingsWindowController`; solo falta el botón `Button` en la View |
</phase_requirements>

---

## Summary

Esta fase es puramente UI. El ViewModel completo (`SettingsViewModel`) y el WindowController ya existen desde Phase 9. El único archivo que requiere cambios significativos es `SettingsView.swift` — expandirlo de 1 sección placeholder a 4 secciones completas.

El principal hallazgo técnico es que `VocabularyEntry` actualmente **no conforma `Identifiable`**, lo que bloquea el uso de `ForEach($viewModel.vocabularyEntries)` con binding syntax. La solución es agregar `id: UUID` y conformance `Identifiable` al struct, o usar `ForEach(indices)`. La opción con UUID es más limpia y es compatible con el pipeline existente (Codable no se rompe al agregar un campo nuevo con valor por defecto).

El segundo hallazgo es que el `Picker` de micrófono trabaja con `AudioDeviceID?` (opcional), lo que requiere una fila con `.tag(nil as AudioDeviceID?)` para representar "sin selección". `AudioDeviceInfo` ya conforma `Identifiable`, por lo que el ForEach dentro del Picker no tiene problemas.

**Primary recommendation:** Expandir `SettingsView.swift` en un único task; el prerequisito es agregar `Identifiable` a `VocabularyEntry` (puede ser en el mismo task o en uno previo muy pequeño).

---

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| SwiftUI Form + `.formStyle(.grouped)` | macOS 13+ | Layout de settings estilo System Settings | API nativa de Apple, ya en uso desde Phase 9 |
| `KeyboardShortcuts.Recorder` | 2.4.0 (checkout local) | Recorder de hotkey SwiftUI-nativo | Ya integrado, funciona en NSWindow con NSHostingController |
| `SMAppService.mainApp` | macOS 13+ | Launch at login | API moderna de Apple, ya en SettingsViewModel |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| SF Symbols | Built-in | Iconos en section headers | `Label("Titulo", systemImage: "mic.fill")` en el argumento `header:` de `Section` |
| `ForEach($collection) { $item in }` | Swift 5.5+ | Binding syntax para listas editables | Cuando se necesita mutar elementos del array inline con TextField |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `ForEach($array)` con Identifiable | `ForEach(array.indices, id: \.self)` | El binding por índice funciona pero es frágil si el array cambia durante la iteración; la conformance Identifiable es más segura |
| `Button("Configurar clave API...")` plain | Botón con icono key | El diseño decidido (D-12) es botón simple sin indicador de estado; agregar icono es discreción de Claude |

**Installation:** No se requieren nuevas dependencias. Todas las herramientas necesarias ya están en el proyecto.

---

## Architecture Patterns

### Archivo modificado

Solo un archivo requiere cambios sustanciales:

```
MyWhisper/
├── Settings/
│   ├── SettingsView.swift          ← ÚNICO archivo con cambios grandes (expandir Form)
│   ├── SettingsViewModel.swift     ← Cambio mínimo: agregar Identifiable a VocabularyEntry
│   └── SettingsWindowController.swift  ← Sin cambios
├── Vocabulary/
│   └── VocabularyEntry.swift       ← Cambio: agregar id: UUID + Identifiable conformance
```

### Pattern 1: Form con Section y Label header

**What:** Cada sección del Form usa `Section { ... } header: { Label(...) }` con SF Symbol.
**When to use:** Siempre para las 4 secciones de Settings (D-09).

```swift
// Source: SwiftUI Documentation + local KeyboardShortcuts checkout
Section {
    KeyboardShortcuts.Recorder("Atajo de grabación:", name: .toggleRecording)
    // más controles...
} header: {
    Label("Grabación", systemImage: "mic.fill")
}
```

### Pattern 2: Picker con opcional AudioDeviceID?

**What:** El `selectedMicID` en ViewModel es `AudioDeviceID?` (nil = usar default del sistema). El Picker necesita un tag especial para nil.
**When to use:** Para el selector de micrófono en la sección Grabación (UI-04).

```swift
// Source: useyourloaf.com/blog/swiftui-picker-with-optional-selection/
Picker("Micrófono:", selection: $viewModel.selectedMicID) {
    Text("Predeterminado del sistema")
        .tag(nil as AudioDeviceID?)
    ForEach(viewModel.availableMics) { device in
        Text(device.name)
            .tag(device.id as AudioDeviceID?)
    }
}
```

**Pitfall crítico:** Si los tags no son del mismo tipo opcional que la binding (`AudioDeviceID?`), el Picker no seleccionará visualmente el item correcto aunque la lógica funcione. El cast `.tag(device.id as AudioDeviceID?)` es obligatorio.

### Pattern 3: ForEach con binding para lista editable inline

**What:** `ForEach($viewModel.vocabularyEntries)` provee un `$entry` binding a cada elemento, permitiendo TextField inline que muta directamente el array.
**When to use:** Para la sección Vocabulario (UI-05, D-04, D-07).

**Prerequisito:** `VocabularyEntry` DEBE conformar `Identifiable`. Actualmente no lo hace — es el GAP más importante de esta fase.

```swift
// Source: swiftbysundell.com/articles/building-editable-swiftui-lists/
// + hackingwithswift.com/quick-start/swiftui/how-to-create-a-list-or-a-foreach-from-a-binding

// En VocabularyEntry.swift (cambio requerido):
struct VocabularyEntry: Codable, Equatable, Identifiable {
    var id: UUID = UUID()   // valor default para compatibilidad con datos guardados
    var wrong: String
    var correct: String
}

// En SettingsView.swift:
Section {
    ForEach($viewModel.vocabularyEntries) { $entry in
        HStack {
            TextField("Incorrecto", text: $entry.wrong)
            Image(systemName: "arrow.right")
                .foregroundColor(.secondary)
            TextField("Correcto", text: $entry.correct)
            Button(action: { removeEntry(entry) }) {
                Image(systemName: "minus.circle.fill")
                    .foregroundColor(.red)
            }
            .buttonStyle(.plain)
        }
    }
    Button(action: addEntry) {
        Label("Agregar corrección", systemImage: "plus")
    }
} header: {
    Label("Vocabulario", systemImage: "textformat.abc")
}
```

**Nota sobre Codable y UUID:** Agregar `var id: UUID = UUID()` con valor por defecto es compatible con la decodificación de datos existentes en UserDefaults — los registros viejos sin `id` reciben un UUID nuevo al decodificarse. No es necesario una migración de datos.

### Pattern 4: Botón para abrir panel API

**What:** Un `Button` simple que llama a la closure ya wired.
**When to use:** Sección API (UI-07, D-12).

```swift
// Source: código existente en SettingsWindowController.swift
Section {
    Button("Configurar clave API...") {
        viewModel.openAPIKey()
    }
} header: {
    Label("API", systemImage: "key.fill")
}
```

### Anti-Patterns a Evitar

- **No usar `onDelete`/swipe-to-delete:** D-07 lo excluye explícitamente. Usar botón [-] explícito.
- **No usar `EditButton`:** El modo de edición de SwiftUI List no aplica aquí; los botones +/- son siempre visibles.
- **No usar `@AppStorage`:** El proyecto ya decidió (Phase 09) que `@AppStorage` es incompatible con `@Observable`. Todos los bindings van a través de `$viewModel` con `@Bindable`.
- **No poner dimensiones fijas en el frame:** D-10 indica auto-sizing. El `.frame(minWidth: 420, minHeight: 200)` actual puede permanecer como mínimo, pero sin `maxWidth`/`maxHeight` fijos — el contenido determina el tamaño.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Keyboard shortcut recording | Custom NSEvent monitor + HUD | `KeyboardShortcuts.Recorder` | Maneja conflictos del sistema, storage en UserDefaults, accesibilidad — ya en uso |
| Launch at login | LSSharedFileList (deprecated) o plist manual | `SMAppService.mainApp.register()` | API oficial moderna de Apple, ya en SettingsViewModel |
| Picker con optional | Wrapper custom o conversion manual de AudioDeviceID | SwiftUI Picker con `.tag(nil as T?)` | El Picker nativo maneja el binding correctamente con el tag cast correcto |
| Lista editable inline | NSTableView via NSViewRepresentable | `ForEach($array) { $item in ... }` con Identifiable | Desde iOS 15 / macOS 12, el binding syntax nativo funciona bien |

**Key insight:** Esta fase es enteramente UI de composición — no hay lógica nueva que construir. Todas las piezas complejas (persistencia, servicios, microphone API, SMAppService) ya existen. El trabajo es conectar los controles SwiftUI con los bindings ya expuestos por `SettingsViewModel`.

---

## Common Pitfalls

### Pitfall 1: VocabularyEntry no es Identifiable — ForEach($array) no compila

**What goes wrong:** `ForEach($viewModel.vocabularyEntries) { $entry in ... }` produce error de compilación porque `VocabularyEntry` no conforma `Identifiable`.
**Why it happens:** El binding syntax de ForEach requiere que el elemento sea `Identifiable` para que SwiftUI pueda rastrear cambios por identity, no por índice.
**How to avoid:** Agregar `var id: UUID = UUID()` y `Identifiable` conformance al struct ANTES de implementar la view. Verificar que los datos existentes en UserDefaults se decodifiquen correctamente (el valor default en `var id` garantiza compatibilidad hacia atrás).
**Warning signs:** Error del compilador `type 'Binding<VocabularyEntry>' does not conform to 'Identifiable'`.

### Pitfall 2: Picker no selecciona visualmente el device correcto

**What goes wrong:** El Picker muestra los dispositivos pero ninguno aparece como seleccionado aunque `selectedMicID` tenga un valor.
**Why it happens:** Los tags son `AudioDeviceID` (no opcional) pero el binding es `AudioDeviceID?`. El tipo del tag y el tipo del binding deben coincidir exactamente.
**How to avoid:** Usar `.tag(device.id as AudioDeviceID?)` — el cast a tipo opcional es obligatorio. Y agregar una fila "Predeterminado" con `.tag(nil as AudioDeviceID?)`.
**Warning signs:** El Picker compila pero en runtime no muestra selección activa aunque el valor esté guardado.

### Pitfall 3: Window no auto-dimensiona con contenido expandido

**What goes wrong:** La ventana mantiene el tamaño pequeño del placeholder (minHeight: 200) aunque ahora haya 4 secciones.
**Why it happens:** `NSHostingController` calcula `fittingSize` al crearse la primera vez; si el Form crece, la ventana no se recalcula automáticamente a menos que se fuerce.
**How to avoid:** Remover el `.frame(minWidth: 420, minHeight: 200)` o reemplazar con `.frame(minWidth: 420)` sin altura mínima, dejando que el SwiftUI layout propague el ideal size a `NSHostingController`. Verificar que `SettingsWindowController.show()` no llame a `window.setContentSize()` con valor fijo.
**Warning signs:** La ventana se abre muy pequeña y el contenido se trunca o tiene scrollbar inesperado.

### Pitfall 4: macOS 15 GroupedFormStyle limita ancho a 600pt

**What goes wrong:** En macOS 15 (Sequoia), el `GroupedFormStyle` aplica un límite de ancho de ~600pt al contenido. Una `List` o `ForEach` dentro del Form no se expande al ancho total.
**Why it happens:** Cambio de comportamiento introducido en macOS 15. El proyecto compila con Xcode 26 (macOS 26 target), pero el comportamiento exacto en macOS 26/Tahoe no está documentado aún.
**How to avoid:** Verificar visualmente en macOS 26. Si la lista de vocabulario se trunca, la mitigación es establecer un `minWidth` explícito en el Form o usar `.frame(maxWidth: .infinity)` en los HStack de cada fila. Esta es la única limitación que requiere validación en runtime.
**Warning signs:** Las columnas de vocabulario se ven estrechas o truncadas en comparación con el System Settings real.

### Pitfall 5: Botón [-] estilo .destructive dentro de Form grouped

**What goes wrong:** Un `Button` con `role: .destructive` dentro de un Form `.grouped` puede renderizarse con texto rojo prominente que ocupa demasiado espacio visual.
**Why it happens:** En macOS, el rol destructive en Form cells es más visible que en iOS.
**How to avoid:** Usar `Image(systemName: "minus.circle.fill")` con `.buttonStyle(.plain)` en lugar de un Button con label de texto y role destructive. Esto da el look de System Settings (icono circulo rojo).
**Warning signs:** El botón [-] aparece como texto rojo en lugar de un ícono compacto.

---

## Code Examples

### Estructura completa del Form expandido

```swift
// Source: synthesis de patrones confirmados + código existente del proyecto
import SwiftUI
import KeyboardShortcuts

struct SettingsView: View {
    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        Form {
            // SECCIÓN 1: GRABACIÓN
            Section {
                KeyboardShortcuts.Recorder("Atajo de grabación:", name: .toggleRecording)
                Picker("Micrófono:", selection: $viewModel.selectedMicID) {
                    Text("Predeterminado del sistema")
                        .tag(nil as AudioDeviceID?)
                    ForEach(viewModel.availableMics) { device in
                        Text(device.name)
                            .tag(device.id as AudioDeviceID?)
                    }
                }
                Toggle("Pausar reproducción al grabar", isOn: $viewModel.pausePlaybackEnabled)
                Toggle("Maximizar volumen del micrófono", isOn: $viewModel.maximizeMicVolumeEnabled)
            } header: {
                Label("Grabación", systemImage: "mic.fill")
            }

            // SECCIÓN 2: API
            Section {
                Button("Configurar clave API...") {
                    viewModel.openAPIKey()
                }
            } header: {
                Label("API", systemImage: "key.fill")
            }

            // SECCIÓN 3: VOCABULARIO
            Section {
                ForEach($viewModel.vocabularyEntries) { $entry in
                    HStack {
                        TextField("Incorrecto", text: $entry.wrong)
                        Image(systemName: "arrow.right")
                            .foregroundColor(.secondary)
                        TextField("Correcto", text: $entry.correct)
                        Button {
                            viewModel.vocabularyEntries.removeAll { $0.id == entry.id }
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundColor(.red)
                        }
                        .buttonStyle(.plain)
                    }
                }
                Button {
                    viewModel.vocabularyEntries.append(VocabularyEntry(wrong: "", correct: ""))
                } label: {
                    Label("Agregar corrección", systemImage: "plus")
                }
            } header: {
                Label("Vocabulario", systemImage: "textformat.abc")
            }

            // SECCIÓN 4: SISTEMA
            Section {
                Toggle("Iniciar al arranque", isOn: $viewModel.launchAtLoginEnabled)
            } header: {
                Label("Sistema", systemImage: "gear")
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 420)  // Solo minWidth, sin minHeight fijo para auto-sizing
    }
}
```

### VocabularyEntry con Identifiable

```swift
// Source: código actual del proyecto + cambio requerido
// Archivo: MyWhisper/Vocabulary/VocabularyEntry.swift
import Foundation

struct VocabularyEntry: Codable, Equatable, Identifiable {
    var id: UUID = UUID()   // default UUID — compatibilidad con datos existentes al decodificar
    var wrong: String
    var correct: String
}
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `NSPreferencePane` + XIB | SwiftUI Form `.formStyle(.grouped)` | macOS 13+ | Layout nativo idéntico a System Settings sin código AppKit |
| `@AppStorage` en @Observable | `didSet + UserDefaults.standard.set` | macOS 14 (@Observable) | @AppStorage no funciona en clases @Observable — ya resuelto en Phase 09 |
| `ForEach(array.indices)` | `ForEach($array) { $item in }` | Swift 5.5 / iOS 15 / macOS 12 | Binding-based ForEach más seguro y directo que index-based |
| `SwiftUI Settings scene` | `NSWindow + NSHostingController` | Decisión del proyecto (macOS 26 roto) | Ya implementado en Phase 09 |

---

## Open Questions

1. **Comportamiento exacto de GroupedFormStyle en macOS 26 (Tahoe)**
   - What we know: En macOS 15 se introdujo un límite de ancho de ~600pt. El proyecto compila target macOS 26.
   - What's unclear: Si el límite persiste, fue corregido, o cambió en macOS 26/Tahoe.
   - Recommendation: Verificar visualmente durante la ejecución. Si se trunca, agregar `.frame(maxWidth: .infinity)` a los HStack de vocabulario.

2. **¿Necesita UUID en el CodingKeys de VocabularyEntry?**
   - What we know: Agregar `var id: UUID = UUID()` con valor default no rompe la decodificación de JSON existente (el campo se ignora si no está en el JSON guardado, y se genera uno nuevo).
   - What's unclear: Si el VocabularyService que escribe al UserDefaults necesita también persistir el UUID. Para la UI no importa (el UUID es efímero por sesión).
   - Recommendation: No persistir el UUID — es solo para la identity de SwiftUI. Si se necesita edición persistente por ID en el futuro, se puede agregar entonces.

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Xcode | Compilación Swift/SwiftUI | ✓ | 26.3 | — |
| Swift | Compilación | ✓ | 6.2.4 | — |
| KeyboardShortcuts | UI-03 hotkey recorder | ✓ | 2.4.0 (checkout local) | — |
| SMAppService | UI-06 launch at login | ✓ | Built-in macOS 13+ | — |
| SF Symbols | D-09 section icons | ✓ | Built-in | — |

No hay dependencias faltantes ni bloqueantes.

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | XCTest (integrado en Xcode) |
| Config file | MyWhisper.xcodeproj scheme MyWhisperTests |
| Quick run command | `xcodebuild test -project MyWhisper.xcodeproj -scheme MyWhisper -destination 'platform=macOS' -only-testing:MyWhisperTests/VocabularyServiceTests 2>&1 \| tail -5` |
| Full suite command | `xcodebuild test -project MyWhisper.xcodeproj -scheme MyWhisper -destination 'platform=macOS' 2>&1 \| tail -20` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| UI-01 | Form usa `.formStyle(.grouped)` | Visual/smoke | Build + launch manual | ❌ No test automatizado posible para estilo visual |
| UI-02 | 4 secciones en la vista | Visual/smoke | Build + launch manual | ❌ No test automatizado posible para layout |
| UI-03 | KeyboardShortcuts.Recorder funcional | Manual-only | N/A — requiere interacción de usuario | ❌ No automatizable |
| UI-04 | Picker de micrófono muestra devices | Manual-only | N/A — requiere hardware de audio | ❌ No automatizable |
| UI-05 | VocabularyEntry editable inline + persistencia | unit (indirecto) | `xcodebuild test ... -only-testing:MyWhisperTests/VocabularyServiceTests` | ✅ `VocabularyServiceTests.swift` existe |
| UI-06 | Toggles persisten estado | unit (indirecto vía ViewModel) | Requiere SettingsViewModelTests | ❌ Wave 0 gap |
| UI-07 | Botón API key abre panel | Manual-only | N/A — requiere WindowController lifecycle | ❌ No automatizable |

**Nota:** La mayoría de requisitos de esta fase son UI visual que no tiene cobertura automatizada viable. Los criterios de validación serán principalmente verificación manual en la app corriendo.

### Sampling Rate

- **Por task:** Build success (`xcodebuild build` sin errores)
- **Por wave:** Tests existentes verdes: `xcodebuild test -only-testing:MyWhisperTests/VocabularyServiceTests`
- **Phase gate:** Build success + verificación manual de las 4 secciones en pantalla

### Wave 0 Gaps

- [ ] `MyWhisperTests/SettingsViewModelTests.swift` — cubre UI-06 (toggles persistencia). Crear con tests para `pausePlaybackEnabled`, `maximizeMicVolumeEnabled`, `launchAtLoginEnabled` via mocked UserDefaults.

*(El test de VocabularyService ya existe y cubre la capa de persistencia de UI-05)*

---

## Sources

### Primary (HIGH confidence)

- Código fuente local: `MyWhisper/Settings/SettingsView.swift`, `SettingsViewModel.swift`, `SettingsWindowController.swift` — estado actual de implementación
- Código fuente local: `.build/checkouts/KeyboardShortcuts/Sources/KeyboardShortcuts/Recorder.swift` — API verificada del Recorder SwiftUI
- Código fuente local: `MyWhisper/Vocabulary/VocabularyEntry.swift` — confirmado que NO tiene Identifiable (gap)
- Código fuente local: `MyWhisper/Audio/MicrophoneDeviceService.swift` — `AudioDeviceInfo: Identifiable` confirmado

### Secondary (MEDIUM confidence)

- [useyourloaf.com — SwiftUI Picker With Optional Selection](https://useyourloaf.com/blog/swiftui-picker-with-optional-selection/) — patrón `.tag(nil as T?)` verificado con múltiples fuentes
- [swiftbysundell.com — Building editable SwiftUI lists](https://www.swiftbysundell.com/articles/building-editable-swiftui-lists/) — patrón `ForEach($array) { $item in }` con Identifiable
- [hackingwithswift.com — ForEach from a binding](https://www.hackingwithswift.com/quick-start/swiftui/how-to-create-a-list-or-a-foreach-from-a-binding) — binding syntax confirmado

### Tertiary (LOW confidence)

- [Apple Developer Forums — SwiftUI Form Grouped with Table macOS 15](https://developer.apple.com/forums/thread/764602) — pitfall de ancho 600pt en macOS 15. No verificado para macOS 26 — marcar para validación en runtime.

---

## Metadata

**Confidence breakdown:**

- Standard stack: HIGH — todas las librerías verificadas en código local o docs oficiales
- Architecture: HIGH — el ViewModel ya existe; los patrones SwiftUI usados están bien documentados
- Pitfalls: MEDIUM-HIGH — pitfalls 1-3 y 5 son HIGH (verificados en docs/código); pitfall 4 (macOS 26 width) es LOW (solo macOS 15 documentado, no macOS 26)

**Research date:** 2026-03-24
**Valid until:** 2026-06-24 (APIs estables; macOS 26 podría traer cambios de comportamiento en beta)
