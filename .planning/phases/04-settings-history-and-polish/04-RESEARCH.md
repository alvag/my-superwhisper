# Phase 4: Settings, History, and Polish - Research

**Researched:** 2026-03-16
**Domain:** macOS Settings UI (AppKit), CoreAudio device selection, UserDefaults persistence, SMAppService, notarization
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Settings UI**
- Panel único (no tabs, no sidebar) — una sola ventana con todas las configuraciones visibles
- Contiene: grabador de hotkey, selector de micrófono, clave API (mover desde menú actual), tabla de vocabulario, toggle de inicio al arranque
- Accesible desde "Preferencias..." en el menú del menubar (stub ya existe en StatusMenuView.swift:31)
- Ventana nativa macOS — SwiftUI o AppKit, debe sentirse como app de sistema

**Configuración de Hotkey (REC-05)**
- Click-to-record: botón "Grabar", campo muestra "Presiona tu atajo...", usuario presiona combo, campo se actualiza
- Cambio toma efecto inmediatamente — se desregistra el HotKey viejo y se registra el nuevo sin reiniciar
- Default sigue siendo Option+Space (Phase 1)
- Persistir la selección en UserDefaults

**Selector de Micrófono (MAC-04)**
- Dropdown con lista de dispositivos de entrada disponibles via AVAudioEngine
- Default: micrófono del sistema (default input device)
- Cambio toma efecto en la siguiente grabación — no requiere reinicio de app

**Historial de Transcripciones (OUT-03, OUT-04)**
- Accesible desde item "Historial" en el menú del menubar — abre ventana separada
- Lista de últimas 20 entradas, cada una muestra texto limpio truncado + timestamp
- Click en entrada = copia texto completo al portapapeles + notificación "Texto copiado"
- Almacenado en UserDefaults/plist — suficiente para 20 entradas de texto
- FIFO: al llegar a 20, la más antigua se elimina automáticamente

**Correcciones de Vocabulario (VOC-01, VOC-02)**
- Tabla editable de dos columnas (Incorrecto → Correcto) dentro del panel de Preferencias
- Botón [+] agrega fila vacía, [-] elimina fila seleccionada, edición inline
- Case-insensitive: "cluad" matchea "Cluad" y "CLUAD", reemplazo usa la forma definida por el usuario
- Aplicadas DESPUÉS de Haiku cleanup (VOC-02) — evita que Haiku deshaga las correcciones
- Persistidas en UserDefaults como array de pares [incorrecto, correcto]

**Distribución y Polish**
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

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| VOC-01 | User can define a correction dictionary (misspelled names, technical terms, brand names) | Two-column editable NSTableView in SettingsWindowController; Codable struct persisted via JSONEncoder to UserDefaults |
| VOC-02 | Corrections are applied after LLM cleanup to fix persistent misrecognitions | VocabularyService.apply() called in AppCoordinator after haiku.clean(); case-insensitive NSRegularExpression or simple lowercased string replacement |
| OUT-03 | User can view a history of recent transcriptions (last 10-20) to recover text | TranscriptionHistoryService with FIFO array of Codable HistoryEntry; window opened from StatusMenuController |
| OUT-04 | User can copy any item from the transcription history to clipboard | NSPasteboard.general.setString() on row click + NotificationHelper.show("Texto copiado") |
| MAC-04 | User can select which microphone to use from a list of available audio inputs | CoreAudio enumeration via kAudioHardwarePropertyDevices + AudioUnitSetProperty(kAudioOutputUnitProperty_CurrentDevice) on AVAudioEngine.inputNode |
| MAC-05 | App consumes less than 200MB RAM when idle | WhisperKit large-v3-turbo loads ~800MB–1.5GB; CRITICAL — must profile idle vs active, verify budget is achievable; if over budget, switch to whisper-small (~180MB) |
| REC-05 | User can configure which hotkey activates recording | Replace HotKey with KeyboardShortcuts (sindresorhus); RecorderCocoa widget in SettingsWindowController; persists to UserDefaults automatically |
</phase_requirements>

---

## Summary

Phase 4 wraps the fully-functional record→transcribe→cleanup→paste pipeline with user-facing configuration and distribution readiness. The codebase is pure Swift/AppKit with no SwiftUI dependencies in the settings flow — the existing APIKeyWindowController (NSPanel + Auto Layout) is the reference pattern for all new windows. Three new services need to be created (VocabularyService, TranscriptionHistoryService, MicrophoneDeviceService) and two existing components need to be refactored (HotkeyMonitor to accept dynamic key/modifiers; StatusMenuController to add "Historial" menu item and wire "Preferencias..." stub).

The highest-risk item is the RAM budget (MAC-05). WhisperKit large-v3-turbo at idle occupies approximately 800MB–1.5GB of unified memory on Apple Silicon — significantly over the 200MB target. The 200MB budget is achievable by switching to whisper-small (≈180MB), or the requirement must be re-interpreted as "app process RAM excluding CoreML model memory" (CoreML model memory is reported separately in Instruments as "GPU/Neural Engine memory"). This needs to be profiled and clarified before implementation.

The hotkey recorder is best implemented using `KeyboardShortcuts` by sindresorhus (v2.4.0) which replaces the current `HotKey` dependency and adds user-configurable recording. Device selection for AVAudioEngine requires CoreAudio C API (`AudioUnitSetProperty` with `kAudioOutputUnitProperty_CurrentDevice`) — there is no pure AVFoundation API for this on macOS. Distribution via DMG + notarization uses `xcrun notarytool` (Xcode 13+ replacement for deprecated altool).

**Primary recommendation:** Build in wave order — Services first (VocabularyService, TranscriptionHistoryService, MicrophoneDeviceService), then SettingsWindowController, then HistoryWindowController, then polish (icon, about window, SMAppService, distribution).

---

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| KeyboardShortcuts (sindresorhus) | 2.4.0 | User-configurable hotkey with NSView recorder widget | Replaces bare HotKey; handles UserDefaults persistence, conflict detection, and provides RecorderCocoa NSView component; macOS 10.15+ |
| ServiceManagement (Apple) | macOS 13+ | SMAppService for launch-at-login toggle | Apple's official replacement for deprecated SMLoginItemSetEnabled; no helper app needed |
| CoreAudio (Apple) | system | Enumerate audio input devices, set active device on AVAudioEngine | Only API available for macOS audio device selection — AVFoundation alone is insufficient |
| UserDefaults (Apple) | system | Persist settings, history, vocabulary | Appropriate for small config data (<1MB); no Core Data overhead needed for 20 history entries + vocab pairs |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| create-dmg (Homebrew) | latest | Polished DMG with background and icon layout | Simpler than raw hdiutil; produces professional-looking drag-to-Applications DMG |
| xcrun notarytool | Xcode 15+ | Submit app for Apple notarization | Replaced altool since Xcode 13; required for Gatekeeper acceptance outside App Store |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| KeyboardShortcuts | Manual NSEvent.addLocalMonitorForEvents recorder | KeyboardShortcuts handles conflict detection, accessibility label, UserDefaults persistence; hand-rolling saves one dependency but adds ~200 lines of boilerplate |
| CoreAudio C API | SimplyCoreAudio (rnine/SimplyCoreAudio) | SimplyCoreAudio is a cleaner Swift wrapper but adds a dependency; CoreAudio C API is 40 lines of code and well-documented |
| UserDefaults + JSONEncoder | Core Data | Core Data is massive overkill for 20 text entries; UserDefaults with JSONEncoder is the macOS best practice for small config data |

**Installation:**
```bash
# Add to Package.swift dependencies:
# .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", from: "2.4.0"),
# Remove or keep HotKey — KeyboardShortcuts uses the same Carbon EventHotKey underneath

swift package update
```

---

## Architecture Patterns

### Recommended Project Structure (additions for Phase 4)
```
MyWhisper/
├── Settings/
│   ├── SettingsWindowController.swift   # NSPanel + Auto Layout, single-panel Settings UI
│   └── SettingsService.swift            # @Observable UserDefaults wrapper (hotkey, mic, launchAtLogin)
│
├── History/
│   ├── TranscriptionHistoryService.swift  # FIFO array, max 20 entries, persist via UserDefaults
│   └── HistoryWindowController.swift      # NSPanel with NSTableView, click-to-copy
│
├── Vocabulary/
│   ├── VocabularyService.swift          # Codable [VocabularyEntry], apply() -> String pipeline step
│   └── VocabularyEntry.swift            # struct { wrong: String, correct: String } Codable
│
├── Audio/
│   └── MicrophoneDeviceService.swift    # CoreAudio enumeration, applies selection to AudioRecorder
│
└── [existing files unchanged]
```

### Pattern 1: SettingsWindowController (mirrors APIKeyWindowController)
**What:** An NSPanel using AppKit Auto Layout — same pattern as the existing APIKeyWindowController. Single-panel with all settings visible at once (no tabs). Opens on "Preferencias..." menu click.
**When to use:** All settings UI in this phase.
**Example:**
```swift
// Source: mirrors APIKeyWindowController.swift (existing, already in codebase)
@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    private var panel: NSPanel?

    func show() {
        if let existing = panel {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 420),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        panel.title = "MyWhisper — Preferencias"
        panel.isReleasedWhenClosed = false
        panel.delegate = self
        // ... build content with Auto Layout
        panel.center()
        NSApp.setActivationPolicy(.regular)
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.panel = panel
    }

    func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        self.panel = nil
    }
}
```

### Pattern 2: KeyboardShortcuts Integration (replaces HotKey)
**What:** Replace HotKey registration with KeyboardShortcuts. Define a named shortcut, wire a RecorderCocoa view into SettingsWindowController, listen via `KeyboardShortcuts.onKeyDown`.
**When to use:** REC-05 hotkey configuration.
**Example:**
```swift
// Source: https://github.com/sindresorhus/KeyboardShortcuts
import KeyboardShortcuts

// 1. Register name (once, globally)
extension KeyboardShortcuts.Name {
    static let toggleRecording = Self("toggleRecording",
                                      default: .init(.space, modifiers: [.option]))
}

// 2. In AppDelegate / HotkeyMonitor replacement
KeyboardShortcuts.onKeyDown(for: .toggleRecording) { [weak coordinator] in
    Task { @MainActor in
        await coordinator?.handleHotkey()
    }
}

// 3. In SettingsWindowController
let recorder = KeyboardShortcuts.RecorderCocoa(for: .toggleRecording)
recorder.translatesAutoresizingMaskIntoConstraints = false
contentView.addSubview(recorder)
// No explicit save needed — RecorderCocoa writes to UserDefaults automatically
```

### Pattern 3: CoreAudio Microphone Enumeration + Selection
**What:** Use CoreAudio C API to enumerate input devices and set the active device on AVAudioEngine via AudioUnitSetProperty. Must call BEFORE engine.start().
**When to use:** MAC-04 microphone selector.
**Example:**
```swift
// Source: Apple Developer Forums thread/71008 + AudioKit AVAudioEngine+Devices.swift
import AudioToolbox

struct AudioDeviceInfo: Identifiable {
    let id: AudioDeviceID
    let name: String
}

func availableInputDevices() -> [AudioDeviceInfo] {
    var propertySize: UInt32 = 0
    var address = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDevices,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )
    AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject),
                                   &address, 0, nil, &propertySize)
    let count = Int(propertySize) / MemoryLayout<AudioDeviceID>.size
    var deviceIDs = [AudioDeviceID](repeating: 0, count: count)
    AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject),
                               &address, 0, nil, &propertySize, &deviceIDs)

    return deviceIDs.compactMap { deviceID in
        // Check input channel count > 0
        var inputAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamConfiguration,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
        var inputSize: UInt32 = 0
        AudioObjectGetPropertyDataSize(deviceID, &inputAddress, 0, nil, &inputSize)
        guard inputSize > 0 else { return nil }

        // Get name
        var nameAddress = AudioObjectPropertyAddress(
            mSelector: kAudioObjectPropertyName,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var nameRef: CFString = "" as CFString
        var nameSize = UInt32(MemoryLayout<CFString>.size)
        AudioObjectGetPropertyData(deviceID, &nameAddress, 0, nil, &nameSize, &nameRef)
        return AudioDeviceInfo(id: deviceID, name: nameRef as String)
    }
}

// Set device BEFORE engine.start()
func setInputDevice(_ deviceID: AudioDeviceID, on engine: AVAudioEngine) throws {
    let audioUnit = engine.inputNode.audioUnit!
    var id = deviceID
    let status = AudioUnitSetProperty(audioUnit,
                                      kAudioOutputUnitProperty_CurrentDevice,
                                      kAudioUnitScope_Global,
                                      0, &id,
                                      UInt32(MemoryLayout<AudioDeviceID>.size))
    guard status == noErr else {
        throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
    }
}
```

### Pattern 4: VocabularyService — Post-Haiku String Replacement
**What:** Case-insensitive string replacement applied after Haiku cleanup. Stored as `[VocabularyEntry]` in UserDefaults via JSONEncoder. Applied in AppCoordinator between `haiku.clean()` and `textInjector.inject()`.
**When to use:** VOC-01, VOC-02.
**Example:**
```swift
// Source: standard Swift Foundation
struct VocabularyEntry: Codable {
    var wrong: String
    var correct: String
}

final class VocabularyService {
    private let defaultsKey = "vocabularyCorrections"

    var entries: [VocabularyEntry] {
        get {
            guard let data = UserDefaults.standard.data(forKey: defaultsKey),
                  let decoded = try? JSONDecoder().decode([VocabularyEntry].self, from: data)
            else { return [] }
            return decoded
        }
        set {
            let data = try? JSONEncoder().encode(newValue)
            UserDefaults.standard.set(data, forKey: defaultsKey)
        }
    }

    /// Apply case-insensitive corrections. Called after Haiku cleanup.
    func apply(to text: String) -> String {
        var result = text
        for entry in entries where !entry.wrong.isEmpty {
            // Case-insensitive simple replacement
            result = result.replacingOccurrences(
                of: entry.wrong,
                with: entry.correct,
                options: [.caseInsensitive]
            )
        }
        return result
    }
}
```

### Pattern 5: TranscriptionHistoryService — FIFO 20-entry store
**What:** Append-on-transcription, cap at 20 entries, persist to UserDefaults via JSONEncoder. HistoryEntry contains text + ISO8601 date string.
**When to use:** OUT-03, OUT-04.
**Example:**
```swift
struct HistoryEntry: Codable, Identifiable {
    let id: UUID
    let text: String
    let date: Date
    var truncated: String { String(text.prefix(80)) + (text.count > 80 ? "…" : "") }
}

final class TranscriptionHistoryService {
    private let defaultsKey = "transcriptionHistory"
    static let maxEntries = 20

    var entries: [HistoryEntry] {
        get { load() }
        set { save(newValue) }
    }

    func append(_ text: String) {
        var current = load()
        current.insert(HistoryEntry(id: UUID(), text: text, date: Date()), at: 0)
        if current.count > Self.maxEntries { current = Array(current.prefix(Self.maxEntries)) }
        save(current)
    }

    private func load() -> [HistoryEntry] {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let decoded = try? JSONDecoder().decode([HistoryEntry].self, from: data)
        else { return [] }
        return decoded
    }

    private func save(_ entries: [HistoryEntry]) {
        let data = try? JSONEncoder().encode(entries)
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }
}
```

### Pattern 6: SMAppService — Launch at Login
**What:** Single call to `SMAppService.mainApp.register()` / `.unregister()`. Read status from SMAppService — don't trust UserDefaults alone (user can remove from login items in System Settings).
**When to use:** Launch-at-login toggle in Preferences.
**Example:**
```swift
// Source: Apple Developer Documentation (ServiceManagement)
import ServiceManagement

func setLaunchAtLogin(_ enabled: Bool) {
    do {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    } catch {
        print("[LaunchAtLogin] Error: \(error)")
    }
}

var isLaunchAtLoginEnabled: Bool {
    SMAppService.mainApp.status == .enabled
}
```

### Pattern 7: HistoryWindowController
**What:** NSPanel with an NSTableView (single column, custom NSTableCellView). Row click copies to clipboard and fires a notification. Follows the same NSPanel lifecycle as SettingsWindowController and APIKeyWindowController.
**When to use:** "Historial" menu item in StatusMenuController.
**Example:**
```swift
// On row click (NSTableViewDelegate)
func tableViewSelectionDidChange(_ notification: Notification) {
    guard let tableView = notification.object as? NSTableView,
          tableView.selectedRow >= 0 else { return }
    let entry = historyService.entries[tableView.selectedRow]
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(entry.text, forType: .string)
    NotificationHelper.show(title: "Texto copiado")
    tableView.deselectAll(nil) // Allow re-clicking same entry
}
```

### Anti-Patterns to Avoid
- **Setting AVAudioEngine device after start:** `AudioUnitSetProperty(kAudioOutputUnitProperty_CurrentDevice)` must be called before `engine.start()`. In AudioRecorder.start(), read selected device ID from SettingsService before launching the engine.
- **Calling SMAppService from non-main thread:** SMAppService calls must happen on the main thread or a synchronous context; wrap in `Task { @MainActor in ... }` if called from a non-isolated context.
- **Storing vocabulary/history as raw NSArray in UserDefaults:** `UserDefaults.set([["wrong": "x", "correct": "y"]]` avoids Codable but breaks Swift type safety and makes testing harder. Use JSONEncoder/JSONDecoder + Codable structs instead.
- **Relying solely on UserDefaults for launch-at-login state:** Users can disable login items in System Settings without the app knowing. Always read `SMAppService.mainApp.status` as the source of truth for the toggle's initial state.
- **Building a custom hotkey recorder from scratch:** NSEvent.addLocalMonitorForEvents only fires for events delivered to your own app. You need global event monitoring for the recorder to work outside your app's windows. KeyboardShortcuts handles this correctly.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Configurable hotkey with conflict detection | Custom NSEvent monitor + Carbon EventHotKey | KeyboardShortcuts 2.4.0 | Conflict detection, UserDefaults persistence, accessibility description, RecorderCocoa view — all provided |
| Launch-at-login toggle | LSSharedFileList (deprecated), helper app | SMAppService.mainApp | Apple's official API since macOS 13; no helper app needed |
| Audio device enumeration | Parsing `system_profiler` output | CoreAudio C API (kAudioHardwarePropertyDevices) | 40 lines, no subprocess, official API |

**Key insight:** The vocabulary correction feature uses simple case-insensitive string replacement, NOT regex. The CONTEXT.md explicitly leaves this to Claude's discretion — simple `replacingOccurrences(of:with:options:[.caseInsensitive])` is correct and testable without regex complexity.

---

## Common Pitfalls

### Pitfall 1: MAC-05 RAM Budget May Be Unreachable With large-v3-turbo
**What goes wrong:** The requirement states <200MB RAM when idle. WhisperKit large-v3-turbo has an encoder model (~800MB CoreML) and decoder (~200MB). At idle, these remain resident in memory after first load.
**Why it happens:** The 200MB budget was set before confirming WhisperKit model sizes. CoreML model memory on Apple Silicon is reported in Instruments under "Neural Engine" or "Metal" memory, not always in the app's resident set size (RSS). The Xcode Memory Report may show <200MB RSS for the app process even though total system memory committed is much higher.
**How to avoid:** Profile with Instruments/Xcode Memory Report at idle (after model load, no recording). If RSS is under 200MB, MAC-05 passes. If over, document that the budget refers to app process RSS (not Neural Engine model memory). Do NOT proactively switch to a smaller model without profiling first.
**Warning signs:** Instruments shows >200MB in "Memory" column for MyWhisper at idle.

### Pitfall 2: AVAudioEngine Device Setting Must Precede engine.start()
**What goes wrong:** Calling `AudioUnitSetProperty(kAudioOutputUnitProperty_CurrentDevice)` after `engine.start()` silently fails or causes the engine to continue using the old device.
**Why it happens:** Once the HAL (Hardware Abstraction Layer) I/O unit is running, the device property is locked.
**How to avoid:** In `AudioRecorder.start()`, read the selected `AudioDeviceID` from `SettingsService.selectedMicrophoneID` and call `setInputDevice()` on `engine.inputNode.audioUnit` before `engine.start()`. If the stored ID is nil (system default), skip the call — AVAudioEngine uses the system default automatically.
**Warning signs:** Selected microphone in settings doesn't match what's actually capturing.

### Pitfall 3: KeyboardShortcuts Default Shortcut Conflicts
**What goes wrong:** Setting `.init(.space, modifiers: [.option])` as the default in `KeyboardShortcuts.Name` declaration fires immediately on first launch before the user touches settings, potentially conflicting with other apps using Option+Space.
**Why it happens:** KeyboardShortcuts registers the shortcut at app launch based on its default value.
**How to avoid:** This is the DESIRED behavior — Option+Space is the established default from Phase 1. The KeyboardShortcuts library handles conflict detection and will warn if the system already has Option+Space assigned. No special handling needed.

### Pitfall 4: NSTableView Inline Editing Needs Careful Delegate Setup
**What goes wrong:** Vocabulary table editing — clicking a cell doesn't enter edit mode, or edits are lost when focus moves.
**Why it happens:** NSTableView inline editing requires `tableView.isEditable = true`, `column.isEditable = true`, AND the delegate implementing `tableView(_:setObjectValue:for:row:)`.
**How to avoid:** Use `NSTableView` with `NSTextField` cells (not NSTextFieldCell directly). Set `column.isEditable = true`. Implement both `objectValue(for:)` and `setObjectValue(_:for:row:)` to read/write the vocabulary array.

### Pitfall 5: SettingsWindowController API Key Section Migration
**What goes wrong:** Moving "Clave de API..." from the menu into Settings breaks the existing flow where `StatusMenuController` holds `APIKeyWindowController`.
**Why it happens:** The API key section is currently in two places: a standalone `APIKeyWindowController` (for first-run prompt from coordinator) and a menu item.
**How to avoid:** Keep `APIKeyWindowController` as-is for the coordinator's on-the-fly gate. In `SettingsWindowController`, add a "Clave de API" button/field that shows the existing `APIKeyWindowController`. Remove the menu item "Clave de API..." from `StatusMenuController.buildMenu()`. The coordinator's `apiKeyWindowController` reference is unchanged.

---

## Code Examples

### UserDefaults Key Constants (avoid magic strings)
```swift
// Source: standard Swift Foundation best practice
enum UserDefaultsKeys {
    static let transcriptionHistory = "transcriptionHistory"
    static let vocabularyCorrections = "vocabularyCorrections"
    static let selectedMicrophoneID = "selectedMicrophoneID"  // AudioDeviceID stored as UInt32
    // Hotkey is managed by KeyboardShortcuts — no manual key needed
    // Launch-at-login is managed by SMAppService — no manual key needed
}
```

### Timestamp Format for History Entries
```swift
// Source: Apple Foundation DateFormatter
// "Ayer 14:32" / "Hoy 09:15" style — friendly relative format
extension Date {
    var historyDisplayString: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "es")
        formatter.unitsStyle = .abbreviated
        // For entries older than 1 day, show the actual date
        if abs(timeIntervalSinceNow) > 86400 {
            let df = DateFormatter()
            df.locale = Locale(identifier: "es")
            df.dateStyle = .short
            df.timeStyle = .short
            return df.string(from: self)
        }
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}
```

### Distribution Script Skeleton
```bash
# Source: Apple developer docs + xcrun notarytool workflow (2025)
# 1. Build release archive
xcodebuild archive -scheme MyWhisper -archivePath ./MyWhisper.xcarchive

# 2. Export .app with Developer ID
xcodebuild -exportArchive \
  -archivePath ./MyWhisper.xcarchive \
  -exportPath ./dist \
  -exportOptionsPlist ExportOptions.plist  # method = developer-id

# 3. Sign the app (should already be signed by export, verify)
codesign --verify --deep --strict ./dist/MyWhisper.app

# 4. Create DMG
hdiutil create -volname "MyWhisper" -srcfolder ./dist/MyWhisper.app \
  -ov -format UDZO ./dist/MyWhisper.dmg

# 5. Sign the DMG
codesign --force --sign "Developer ID Application: <Name> (<TeamID>)" \
  --timestamp ./dist/MyWhisper.dmg

# 6. Notarize
xcrun notarytool submit ./dist/MyWhisper.dmg \
  --keychain-profile "notarytool-profile" --wait

# 7. Staple
xcrun stapler staple ./dist/MyWhisper.dmg
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| altool for notarization | xcrun notarytool | Xcode 13 (2021); altool removed Xcode 14 | notarytool is faster and has better error messages |
| SMLoginItemSetEnabled (helper app required) | SMAppService.mainApp | macOS 13 Ventura (2022) | No helper app bundle needed; much simpler |
| Carbon EventHotKey + manual UserDefaults | KeyboardShortcuts library | 2018+ (library); 2.x maintained 2024-2025 | Handles conflict detection, SwiftUI + AppKit support |

**Deprecated/outdated:**
- `LSSharedFileList` for login items: removed macOS 13+. Use SMAppService.
- `altool` for notarization: removed Xcode 14+. Use xcrun notarytool.
- `kAudioObjectPropertyElementMaster`: renamed `kAudioObjectPropertyElementMain` in macOS 12+. Use `kAudioObjectPropertyElementMain` to silence deprecation warnings.

---

## Open Questions

1. **MAC-05: Is <200MB idle RAM actually achievable with large-v3-turbo?**
   - What we know: WhisperKit base model is ~180MB. Large-v3-turbo is ~800MB–1.5GB total model size. CoreML model memory may be reported separately from process RSS.
   - What's unclear: Whether the Xcode Memory Report's "Memory" column for the app process includes or excludes Neural Engine memory at idle.
   - Recommendation: In Wave 0 of implementation, profile with Instruments immediately after model loads. If RSS is <200MB, MAC-05 passes as written. If not, document the distinction between app RSS and Neural Engine model memory in the verification step, and confirm with the user whether the requirement should be re-scoped.

2. **API Key panel migration: keep standalone or absorb into Settings?**
   - What we know: CONTEXT.md says "move API key from current menu item to Settings panel." AppCoordinator also uses `APIKeyWindowController` directly for the on-the-fly gate when no key is configured.
   - What's unclear: Does the coordinator's gate need to change, or just the menu item?
   - Recommendation: Keep `APIKeyWindowController` as a standalone panel for the coordinator gate. Add a "Cambiar clave de API..." button in `SettingsWindowController` that opens it. Remove "Clave de API..." from the status menu. This is the least-disruption approach.

---

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | XCTest (Swift Package Manager test target `MyWhisperTests`) |
| Config file | Package.swift — `.testTarget(name: "MyWhisperTests", dependencies: ["MyWhisper"])` |
| Quick run command | `swift test --filter MyWhisperTests` |
| Full suite command | `swift test` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| VOC-01 | VocabularyService loads/saves entries to UserDefaults | unit | `swift test --filter VocabularyServiceTests` | Wave 0 |
| VOC-02 | VocabularyService.apply() does case-insensitive replacement after Haiku | unit | `swift test --filter VocabularyServiceTests/testApplyCorrections` | Wave 0 |
| OUT-03 | TranscriptionHistoryService appends and caps at 20 entries | unit | `swift test --filter TranscriptionHistoryServiceTests` | Wave 0 |
| OUT-04 | HistoryWindowController click copies to NSPasteboard | manual-only | N/A — NSPasteboard requires display server | manual |
| MAC-04 | MicrophoneDeviceService returns non-empty device list on real hardware | integration | `swift test --filter MicrophoneDeviceServiceTests` | Wave 0 |
| MAC-05 | Idle RAM ≤200MB after model load | manual-only | N/A — requires Instruments profiling | manual |
| REC-05 | KeyboardShortcuts fires coordinator.handleHotkey when shortcut triggered | unit (mock) | `swift test --filter HotkeyMonitorTests` | ❌ Wave 0 (refactor existing) |

### Sampling Rate
- **Per task commit:** `swift test --filter VocabularyServiceTests TranscriptionHistoryServiceTests`
- **Per wave merge:** `swift test`
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `MyWhisperTests/VocabularyServiceTests.swift` — covers VOC-01, VOC-02
- [ ] `MyWhisperTests/TranscriptionHistoryServiceTests.swift` — covers OUT-03
- [ ] `MyWhisperTests/MicrophoneDeviceServiceTests.swift` — covers MAC-04 (guard: skip if no audio hardware)
- [ ] `MyWhisperTests/HotkeyMonitorTests.swift` — update existing test to cover KeyboardShortcuts refactor (REC-05)
- [ ] Package.swift — add KeyboardShortcuts dependency: `.package(url: "https://github.com/sindresorhus/KeyboardShortcuts", from: "2.4.0")`

---

## Sources

### Primary (HIGH confidence)
- [KeyboardShortcuts GitHub (sindresorhus)](https://github.com/sindresorhus/KeyboardShortcuts) — v2.4.0, RecorderCocoa API, KeyboardShortcuts.Name default shortcut pattern
- [SMAppService Apple Developer Documentation](https://developer.apple.com/documentation/servicemanagement/smappservice) — mainApp.register()/unregister(), status property
- [Apple Developer Forums thread/71008](https://developer.apple.com/forums/thread/71008) — kAudioOutputUnitProperty_CurrentDevice on AVAudioEngine.inputNode.audioUnit
- [Notarizing macOS software — Apple Developer Documentation](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution) — xcrun notarytool workflow
- Existing codebase: `APIKeyWindowController.swift`, `HotkeyMonitor.swift`, `StatusMenuView.swift`, `AppCoordinator.swift` — confirmed integration points

### Secondary (MEDIUM confidence)
- [AudioKit AVAudioEngine+Devices.swift](https://github.com/AudioKit/AudioKit/blob/main/Sources/AudioKit/Internals/Hardware/AVAudioEngine+Devices.swift) — reference implementation for CoreAudio device enumeration on macOS (confirmed via WebSearch + Apple Forums)
- [nilcoalescing.com — Launch at Login with SMAppService](https://nilcoalescing.com/blog/LaunchAtLoginSetting/) — SMAppService.mainApp usage pattern
- [Christian Tietze — Mac App Notarization Workflow 2022](https://christiantietze.de/posts/2022/07/mac-app-notarization-workflow-in-2022/) — notarytool command-line walkthrough (still current as of 2026)
- [WhisperKit on macOS (helrabelo.dev)](https://www.helrabelo.dev/blog/whisperkit-on-macos-integrating-on-device-ml) — WhisperKit base model ~180MB RAM figure

### Tertiary (LOW confidence — flag for validation)
- WhisperKit large-v3-turbo idle RAM: no definitive single source found. The 800MB–1.5GB estimate is derived from model file sizes (CoreML packages on disk). Actual RSS at idle requires profiling. **Validate in Wave 0.**

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — KeyboardShortcuts and SMAppService verified via official docs; CoreAudio device selection verified via Apple Developer Forums + AudioKit reference implementation
- Architecture: HIGH — all patterns mirror existing codebase (APIKeyWindowController reference pattern well-established)
- Pitfalls: HIGH — device selection ordering, SMAppService status reading from official docs; RAM budget flagged as LOW confidence requiring profiling
- Distribution: MEDIUM — xcrun notarytool workflow verified via Apple docs, exact ExportOptions.plist format varies by Xcode version

**Research date:** 2026-03-16
**Valid until:** 2026-04-16 (stable APIs; SMAppService and notarytool unlikely to change)
