# Phase 3: Haiku Cleanup - Research

**Researched:** 2026-03-16
**Domain:** Anthropic Messages API (REST), macOS Keychain, Swift URLSession, NSPanel modal
**Confidence:** HIGH

## Summary

Phase 3 inserts a single new service — `HaikuCleanup` — between the existing `STTEngine` (which already outputs raw Spanish text) and `TextInjector` (which already pastes text). The integration point in `AppCoordinator.handleHotkey()` is already identified: replace the direct `textInjector?.inject(text)` call with a `haiku?.clean(text) → inject` chain, falling back to raw text on any error.

The Anthropic Messages API is a straightforward REST endpoint (`POST https://api.anthropic.com/v1/messages`) requiring three headers and a JSON body. No SDK is needed — `URLSession` + `JSONDecoder` covers the full use case in ~100 lines of Swift. The 5-second timeout constraint (CLN-05) is well within Haiku 4.5's typical latency for short text cleanup tasks.

API key storage follows the standard macOS pattern: `SecItemAdd` / `SecItemCopyMatching` / `SecItemUpdate` on `kSecClassGenericPassword` items. The key modal uses an `NSPanel` (not `NSWindow`) to prevent focus steal, consistent with the overlay pattern established in Phase 1. On-the-fly key prompting (before first recording when no key is configured) is a new AppCoordinator state check inserted in the `.idle` branch of `handleHotkey`.

**Primary recommendation:** Implement `HaikuCleanupService` as a protocol-backed actor following the `STTEngineProtocol` pattern. Wire it into `AppCoordinator` via dependency injection. Store the API key in Keychain with a dedicated `KeychainService` helper. Keep all error paths falling back to raw STT text — the user always receives output.

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**API Key Setup & Storage**
- API key requested on-the-fly: when user attempts first recording and no key is configured, show modal before recording starts
- Key stored in macOS Keychain — secure, native, survives reinstalls
- UI: small modal window with text field + Save button. Also accessible from menubar dropdown (Settings > API Key)
- Key validated on save: small test request to Anthropic API. If fails, show error and don't save. Prevents errors on first real use

**Cleanup Prompt Design**
- Filler removal: only clear muletillas ("eh", "este", "o sea", "bueno pues") and exact repetitions ("yo yo creo"). Preserve expressions that carry coloquial meaning
- Paragraph breaks: Haiku detects topic changes or logical pauses and adds line breaks. No extra breaks for short texts
- Punctuation: Spanish standard per RAE — opening marks (¿¡), commas, periods, capitals after periods. No informal style
- Meaning preservation: Haiku must NOT paraphrase, add content, or restructure. Only clean up (CLN-04)
- Input: only raw transcription text from WhisperKit. No additional context (app name, metadata). Simple, fast, cheap

**Error & Offline Handling**
- API failure (network, timeout, 500): paste raw STT text + notification "Texto pegado sin limpiar — error de conexión"
- Invalid key / no credit (401/403): paste raw STT text + notification explaining the error. Next recording attempt shows API key modal again
- Timeout: 5 seconds max for Haiku call. If exceeded, fallback to raw text paste
- Philosophy: user always gets text pasted — degraded quality is better than no output

**Pipeline Integration**
- Overlay: same spinner throughout processing. No visual distinction between STT and Haiku phases. "Procesando..." covers both
- Model: claude-haiku-4-5-20251001 — fastest, cheapest, sufficient for text cleanup
- HTTP client: direct URLSession calls to Anthropic Messages API (REST). No SDK dependency
- max_tokens: proportional to input length (input chars * 1.5), prevents unexpectedly long responses
- Flow: record → STT → Haiku cleanup → paste. If Haiku fails at any point, paste raw STT output

### Claude's Discretion
- Exact system prompt wording for Haiku (within the constraints above)
- Keychain service name and access group configuration
- API key modal window dimensions and positioning
- URLSession configuration details (caching, connection pooling)
- Error message wording for specific API error codes
- Token estimation approach for max_tokens calculation

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| CLN-01 | Haiku API adds correct punctuation (periods, commas, question/exclamation marks) | System prompt instructs RAE-standard punctuation; Haiku 4.5 has strong Spanish language capability |
| CLN-02 | Haiku API adds proper capitalization and paragraph breaks | System prompt covers post-period capitalization and topic-change paragraph breaks |
| CLN-03 | Haiku API removes Spanish filler words ("eh", "este", "o sea", "bueno", "pues") and verbal repetitions | System prompt enumerates muletillas list explicitly; Haiku pattern-matches exact repetitions |
| CLN-04 | Haiku API preserves the user's original meaning — no paraphrasing or content addition | System prompt uses explicit negative constraint: "NO parafrasees, NO agregues, NO reestructures" |
| CLN-05 | Haiku API cleanup completes in <2s for typical transcription length | Haiku 4.5 is Anthropic's fastest model; URLSession 5s timeout (decision) is generous; ~100-500 input tokens → <1s typical TTFT |
| PRV-02 | Only transcribed text (not audio) is sent to Anthropic's Haiku API for cleanup | Already satisfied by architecture: STTEngine outputs String, HaikuCleanup receives String only |
| PRV-03 | User can configure their Anthropic API key in settings | KeychainService + API key modal (NSPanel) + StatusMenuView "API Key" menu item |
| PRV-04 | App gracefully handles API errors (network down, invalid key) with clear user feedback | Error dispatch table: 401/403 → show key modal on next attempt; 500/network → raw text fallback + notification |
</phase_requirements>

---

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Foundation.URLSession | macOS system | HTTP calls to Anthropic REST API | Zero dependencies, handles TLS, timeout configuration, async/await support in Swift 5.5+. Decision: no SDK. |
| Security framework | macOS system | Keychain read/write (SecItemAdd, SecItemCopyMatching, SecItemUpdate, SecItemDelete) | Only correct API for storing secrets on macOS. kSecClassGenericPassword for non-credential secrets. |
| AppKit.NSPanel | macOS system | API key entry modal | NSPanel with .nonactivatingPanel style prevents focus steal from target app (same pattern as overlay from Phase 1) |
| UserNotifications | macOS system | Error notifications | Already in use via NotificationHelper.swift. Reuse existing helper. |

### No New SPM Dependencies

The locked decision is explicit: "no new SPM dependencies". URLSession, Security framework, AppKit, and UserNotifications are all system frameworks available on macOS 14+.

## Architecture Patterns

### Recommended Project Structure — New Files

```
MyWhisper/
├── Cleanup/
│   ├── HaikuCleanupService.swift    # Actor: URLSession calls to Anthropic API
│   ├── HaikuCleanupError.swift      # Error enum: network, auth, timeout, invalidResponse
│   └── HaikuCleanupProtocol.swift   # Protocol: HaikuCleanupProtocol (for DI + testing)
├── System/
│   └── KeychainService.swift        # Keychain read/write helper (kSecClassGenericPassword)
├── UI/
│   └── APIKeyWindowController.swift # NSPanel modal: text field + Save + validation
└── Coordinator/
    └── AppCoordinatorDependencies.swift  # MODIFIED: add HaikuCleanupProtocol
```

`AppCoordinator.swift` — modified to add `var haikuCleanup: (any HaikuCleanupProtocol)?` and call it in the `.recording` branch after STT succeeds.

`AppDelegate.swift` — modified to create `HaikuCleanupService`, wire into coordinator, and check for API key at launch.

`StatusMenuView.swift` — modified to add "API Key..." menu item.

### Pattern 1: HaikuCleanupProtocol (mirrors STTEngineProtocol)

**What:** Protocol-backed actor, injected into AppCoordinator via `var haikuCleanup: (any HaikuCleanupProtocol)?`. Follows existing project DI pattern.
**When to use:** Any text that has passed VAD + STT and must be cleaned before pasting.

```swift
// Source: mirrors AppCoordinatorDependencies.swift STTEngineProtocol pattern
protocol HaikuCleanupProtocol: AnyObject, Sendable {
    /// Clean raw transcription text. Returns cleaned text, or throws HaikuCleanupError.
    func clean(_ rawText: String) async throws -> String
    /// Whether a valid API key is stored in Keychain.
    var hasAPIKey: Bool { get async }
    /// Save a new API key (validates first, then stores in Keychain).
    func saveAPIKey(_ key: String) async throws
    /// Remove the stored API key from Keychain.
    func removeAPIKey() async throws
}
```

### Pattern 2: AppCoordinator integration point

**What:** In the `.recording` case of `handleHotkey()`, after STT succeeds, call `haikuCleanup?.clean(text)` and fall back to `text` on any error.
**When to use:** Every transcription that produces non-empty text.

```swift
// Integration point in AppCoordinator.handleHotkey() — .recording branch
// BEFORE (existing, Phase 2):
//   overlayController?.hide()
//   await textInjector?.inject(text)
//   transitionTo(.idle)
//
// AFTER (Phase 3):
do {
    guard let rawText = try await sttEngine?.transcribe(buffer) else {
        throw STTError.notLoaded
    }
    // Haiku cleanup — fallback to raw on any error
    let finalText: String
    if let haiku = haikuCleanup {
        do {
            finalText = try await haiku.clean(rawText)
        } catch HaikuCleanupError.authFailed {
            // 401/403: notify + show key modal on next attempt, paste raw
            NotificationHelper.show(title: "Clave de API inválida — texto pegado sin limpiar")
            markAPIKeyInvalid()     // triggers modal on next idle→recording transition
            finalText = rawText
        } catch {
            // network/timeout/500: paste raw + notify
            NotificationHelper.show(title: "Texto pegado sin limpiar — error de conexión")
            finalText = rawText
        }
    } else {
        finalText = rawText
    }
    overlayController?.hide()
    await textInjector?.inject(finalText)
    transitionTo(.idle)
} catch { ... }
```

### Pattern 3: Anthropic Messages API request (URLSession)

**What:** Single POST to `https://api.anthropic.com/v1/messages` with three headers and JSON body.
**Source:** Verified against official Anthropic docs (platform.claude.com/docs/en/api/messages).

```swift
// Source: https://platform.claude.com/docs/en/api/messages
func clean(_ rawText: String) async throws -> String {
    guard let apiKey = await loadAPIKey() else { throw HaikuCleanupError.noAPIKey }

    let url = URL(string: "https://api.anthropic.com/v1/messages")!
    var request = URLRequest(url: url, timeoutInterval: 5.0)  // CLN-05 / locked decision
    request.httpMethod = "POST"
    request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
    request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
    request.setValue("application/json", forHTTPHeaderField: "content-type")

    // max_tokens = ceil(rawText.count * 1.5 / 4) — chars/4 ≈ tokens, * 1.5 headroom
    let estimatedTokens = max(256, Int(Double(rawText.count) / 4.0 * 1.5))

    let body: [String: Any] = [
        "model": "claude-haiku-4-5-20251001",
        "max_tokens": estimatedTokens,
        "system": systemPrompt,
        "messages": [["role": "user", "content": rawText]]
    ]
    request.httpBody = try JSONSerialization.data(withJSONObject: body)

    let (data, response) = try await URLSession.shared.data(for: request)
    // ... decode and handle HTTP status codes
}
```

### Pattern 4: Keychain storage (kSecClassGenericPassword)

**What:** Read/write an API key string as UTF-8 data under a fixed service name.
**Source:** Apple Developer Documentation - Storing Keys in the Keychain.

```swift
// KeychainService.swift — service name and account are project-specific identifiers
private let service = "com.mywhisper.anthropic-api-key"
private let account = "anthropic"

func save(_ key: String) throws {
    let data = Data(key.utf8)
    let query: [CFString: Any] = [
        kSecClass: kSecClassGenericPassword,
        kSecAttrService: service,
        kSecAttrAccount: account,
        kSecValueData: data
    ]
    SecItemDelete(query as CFDictionary)   // remove any existing item first
    let status = SecItemAdd(query as CFDictionary, nil)
    guard status == errSecSuccess else { throw KeychainError.saveFailed(status) }
}

func load() -> String? {
    let query: [CFString: Any] = [
        kSecClass: kSecClassGenericPassword,
        kSecAttrService: service,
        kSecAttrAccount: account,
        kSecReturnData: true,
        kSecMatchLimit: kSecMatchLimitOne
    ]
    var result: AnyObject?
    let status = SecItemCopyMatching(query as CFDictionary, &result)
    guard status == errSecSuccess, let data = result as? Data else { return nil }
    return String(data: data, encoding: .utf8)
}
```

### Pattern 5: API key modal (NSPanel)

**What:** Small native macOS panel with a secure text field + Save button. `NSPanel` prevents focus steal.
**Source:** Phase 1 overlay pattern — `orderFront(nil)` not `makeKeyAndOrderFront(nil)`.

The key input field uses `NSSecureTextField` so the key is masked. On Save: call `haiku.saveAPIKey(key)` which validates (test Anthropic call), then saves to Keychain if validation passes.

### Anti-Patterns to Avoid

- **Storing the API key in UserDefaults:** UserDefaults is not encrypted. macOS Keychain is the correct secure storage.
- **Blocking the main thread for URLSession:** Always use `async/await URLSession.shared.data(for:)` — never a synchronous call.
- **Using makeKeyAndOrderFront for the modal:** This steals focus from the target app and breaks paste. Use `orderFront(nil)` + `NSApp.activate(ignoringOtherApps: false)`.
- **Using an Anthropic SDK package:** Locked decision — URLSession only. No new SPM dependencies.
- **Making max_tokens a fixed large constant:** Proportional estimation prevents unexpected long responses and cost spikes.
- **Not falling back on timeout:** URLSession timeoutInterval: 5.0 throws `URLError.timedOut` — catch it in the generic error case and paste raw text.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Secure credential storage | Custom file encryption | `Security.SecItemAdd` (Keychain) | Keychain handles encryption, OS integration, user visibility in Keychain Access, and iCloud Keychain sync if desired |
| HTTP networking | Custom socket code | `URLSession.shared.data(for:)` | URLSession handles TLS, redirects, connection pooling, cancellation, async/await |
| JSON encoding/decoding | Manual string building | `JSONSerialization` / `JSONDecoder` (Foundation) | Handles escaping edge cases, Unicode, numeric types |
| Notifications | Custom alert UI | `NotificationHelper.show()` (already exists) | Phase 2 established the pattern — reuse it |

**Key insight:** All infrastructure already exists in macOS system frameworks. The implementation is purely glue code wiring known components together.

---

## Common Pitfalls

### Pitfall 1: API key validation call must use a tiny max_tokens
**What goes wrong:** Validation call during key save sends a normal-sized request, spending real credits.
**Why it happens:** Not scoping the validation request down.
**How to avoid:** Validation request: `max_tokens: 5`, `messages: [{"role": "user", "content": "hola"}]`. Just needs a 200 HTTP response.
**Warning signs:** Console logs showing large token counts on key save.

### Pitfall 2: URLSession timeout not respected on DNS failure
**What goes wrong:** `timeoutInterval: 5.0` on `URLRequest` is the _response_ timeout (time waiting for data after connection). DNS resolution hangs can occur before the timeout starts.
**Why it happens:** Foundation URLSession has separate resource timeout vs request timeout semantics.
**How to avoid:** Also set `URLSessionConfiguration.timeoutIntervalForResource = 5.0` on a custom `URLSessionConfiguration` rather than relying on `URLRequest.timeoutInterval` alone.
**Warning signs:** Haiku call hangs for >5 seconds on airplane mode.

### Pitfall 3: NSSecureTextField in NSPanel returns empty string if panel not shown
**What goes wrong:** Accessing `secureTextField.stringValue` before the panel is shown returns "".
**Why it happens:** NSPanel lazily initializes views.
**How to avoid:** Read `stringValue` only in the Save button action handler (after user interaction).

### Pitfall 4: Anthropic response `content[0].text` may be missing
**What goes wrong:** Parsing assumes `content` array has at least one item of type `"text"`.
**Why it happens:** API can return empty content on stop_reason == "max_tokens" edge cases.
**How to avoid:** Guard on `content.first?.type == "text"` before accessing `.text`. Fallback to raw if guard fails.

### Pitfall 5: AppCoordinator `haikuCleanup` is nil when no key configured — must not paste nothing
**What goes wrong:** `haikuCleanup` optional unwrap fails silently, text is never pasted.
**Why it happens:** `if let haiku = haikuCleanup` pattern with no else branch.
**How to avoid:** Always have an `else { finalText = rawText }` branch — explicitly handle the nil case.

### Pitfall 6: API key modal appears behind other windows on first launch
**What goes wrong:** `orderFront(nil)` without activating the app means the panel may be hidden behind other apps.
**Why it happens:** App runs as `.accessory` (menubar only) — no dock icon, no automatic bring-to-front.
**How to avoid:** Temporarily set `NSApp.setActivationPolicy(.regular)` when showing the key modal (same pattern as `showPermissionBlockedWindow` in AppDelegate). Restore to `.accessory` after panel closes.

---

## Code Examples

### Anthropic Messages API — Full Response Decode

```swift
// Source: https://platform.claude.com/docs/en/api/messages
struct AnthropicResponse: Decodable {
    struct ContentBlock: Decodable {
        let type: String
        let text: String?
    }
    struct ErrorDetail: Decodable {
        let type: String
        let message: String
    }
    struct ErrorWrapper: Decodable {
        let type: String
        let error: ErrorDetail
    }
    let content: [ContentBlock]?
}

// After URLSession.data(for:):
let httpResponse = response as! HTTPURLResponse
switch httpResponse.statusCode {
case 200:
    let decoded = try JSONDecoder().decode(AnthropicResponse.self, from: data)
    guard let text = decoded.content?.first(where: { $0.type == "text" })?.text else {
        throw HaikuCleanupError.invalidResponse
    }
    return text
case 401, 403:
    throw HaikuCleanupError.authFailed
case 429:
    throw HaikuCleanupError.rateLimited
default:
    throw HaikuCleanupError.serverError(httpResponse.statusCode)
}
```

### Haiku Cleanup Error Enum

```swift
enum HaikuCleanupError: Error, LocalizedError {
    case noAPIKey
    case authFailed          // 401 / 403
    case rateLimited         // 429
    case serverError(Int)    // 500 / 529
    case invalidResponse     // could not parse content[0].text
    case networkError(Error) // URLError.timedOut, no connection, etc.

    var errorDescription: String? {
        switch self {
        case .noAPIKey:       return "No hay clave de API configurada"
        case .authFailed:     return "Clave de API inválida o sin crédito"
        case .rateLimited:    return "Límite de solicitudes alcanzado"
        case .serverError(let code): return "Error del servidor Anthropic (\(code))"
        case .invalidResponse: return "Respuesta inesperada de la API"
        case .networkError:   return "Error de red"
        }
    }
}
```

### System Prompt (Claude's Discretion — recommended wording)

```swift
// Strict cleanup-only prompt satisfying CLN-01/02/03/04
private let systemPrompt = """
Eres un corrector de texto para dictado en español. \
Recibe texto bruto de reconocimiento de voz y devuelve el mismo texto corregido, sin modificar el significado.

Reglas estrictas:
1. PUNTUACIÓN: Añade puntos, comas y signos de interrogación/exclamación (¿? ¡!) según la norma del español de la RAE. Pon mayúscula después de punto.
2. PÁRRAFOS: Si el texto tiene cambios de tema o pausas lógicas claras, añade un salto de línea. Para textos cortos (< 3 oraciones), NO añadas párrafos.
3. MULETILLAS: Elimina únicamente: "eh", "este", "o sea", "bueno pues", "pues este", "o sea que". NO elimines expresiones coloquiales que aporten significado.
4. REPETICIONES: Elimina repeticiones literales de palabras consecutivas (ej. "yo yo creo" → "yo creo"). NO elimines si la repetición es intencional (ej. "muy muy importante").
5. PROHIBIDO: NO parafrasees, NO agregues palabras que no estaban, NO reestructures oraciones, NO cambies el registro ni el tono.

Devuelve SOLO el texto corregido. Sin explicaciones, sin comillas, sin prefijos.
"""
```

### Token Estimation

```swift
// Proportional max_tokens: ~4 chars per token, 1.5x headroom for added punctuation/spaces
// Minimum 128 to avoid starving short inputs; maximum 2048 for very long dictations
func estimateMaxTokens(for text: String) -> Int {
    let estimate = Int(Double(text.count) / 4.0 * 1.5)
    return min(max(estimate, 128), 2048)
}
```

### URLSession with resource timeout

```swift
// Source: URLSessionConfiguration — covers DNS + connection + response
private lazy var session: URLSession = {
    let config = URLSessionConfiguration.default
    config.timeoutIntervalForRequest = 5.0   // per-request socket idle timeout
    config.timeoutIntervalForResource = 5.0  // total resource acquisition timeout
    config.requestCachePolicy = .reloadIgnoringLocalCacheData
    return URLSession(configuration: config)
}()
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| claude-3-haiku-20240307 | claude-haiku-4-5-20251001 | Oct 2025 | Old Haiku deprecated Apr 19 2026 — must use new model ID |
| SDK dependency | Direct URLSession REST | Project decision | Zero extra dependencies, full control |
| anthropic-version: (older) | anthropic-version: 2023-06-01 | API version header | Required header for all requests, version has been stable |

**Deprecated/outdated:**
- `claude-3-haiku-20240307`: Deprecated by Anthropic, retirement April 19, 2026. Use `claude-haiku-4-5-20251001` (or alias `claude-haiku-4-5`).

---

## Open Questions

1. **System prompt filler list coverage**
   - What we know: User specified "eh", "este", "o sea", "bueno pues" as the canonical list
   - What's unclear: Whether "pues" alone (without "bueno") should be removed in all contexts, or only as "bueno pues"
   - Recommendation: Use Claude's Discretion — treat standalone "pues" as context-dependent coloquial expression (preserve), but remove "bueno pues" as a phrase. Revisit after real-speech testing (flagged in STATE.md as a known concern).

2. **API key modal first-show activation policy**
   - What we know: AppDelegate already uses `NSApp.setActivationPolicy(.regular)` + `makeKeyAndOrderFront` for the permissions blocked window
   - What's unclear: Whether temporarily switching to `.regular` has UX side effects (dock icon appears) that should be avoided for a quick API key prompt
   - Recommendation: Use `NSApp.setActivationPolicy(.regular)` on show + `NSApp.setActivationPolicy(.accessory)` on close, same as permission window. The Dock icon briefly appears but it is the established project pattern.

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | XCTest (Swift, built-in Xcode) |
| Config file | Package.swift — `.testTarget(name: "MyWhisperTests", dependencies: ["MyWhisper"])` |
| Quick run command | `swift test --filter HaikuCleanup 2>&1` |
| Full suite command | `swift test 2>&1` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| CLN-01 | Cleaned text has correct Spanish punctuation | unit (mock Haiku) | `swift test --filter AppCoordinatorTests 2>&1` | Already exists — needs new mock |
| CLN-02 | Cleaned text has capitalization / paragraph breaks | unit (mock Haiku) | `swift test --filter AppCoordinatorTests 2>&1` | Already exists — needs new mock |
| CLN-03 | Filler words removed from output | unit (mock Haiku) | `swift test --filter HaikuCleanupServiceTests 2>&1` | Wave 0 gap |
| CLN-04 | Cleaned text preserves meaning (no extra words) | unit (mock returns known string) | `swift test --filter HaikuCleanupServiceTests 2>&1` | Wave 0 gap |
| CLN-05 | Cleanup completes in <2s | integration smoke (real Haiku call, skipped in CI) | `swift test --filter HaikuCleanupServiceTests/testCleanCompletes 2>&1` | Wave 0 gap |
| PRV-02 | Only text (not audio) sent to API | unit (inspect URLRequest body) | `swift test --filter HaikuCleanupServiceTests/testRequestBodyContainsOnlyText 2>&1` | Wave 0 gap |
| PRV-03 | User can configure API key | unit (KeychainService + modal) | `swift test --filter KeychainServiceTests 2>&1` | Wave 0 gap |
| PRV-04 | Graceful API error handling — raw text pasted | unit (mock error responses) | `swift test --filter AppCoordinatorTests/testHaikuAuthFailurePastesRawText 2>&1` | Wave 0 gap |

**Note on CLN-01/02/03/04 unit testing:** These requirements are about Haiku's _output quality_ — which can only be validated end-to-end with real API calls. Unit tests should verify: (a) the coordinator calls Haiku, (b) the result is passed to inject, and (c) error paths fall back to raw text. Prompt correctness is a manual/integration-level concern.

### Sampling Rate

- **Per task commit:** `swift test --filter AppCoordinatorTests 2>&1`
- **Per wave merge:** `swift test 2>&1`
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps

- [ ] `MyWhisperTests/HaikuCleanupServiceTests.swift` — covers CLN-03, CLN-04, CLN-05, PRV-02 (with MockHaikuCleanup and a network-skippable integration test)
- [ ] `MyWhisperTests/KeychainServiceTests.swift` — covers PRV-03 (save/load/delete round-trip using a test-specific service name)
- [ ] `MockHaikuCleanup` in `AppCoordinatorTests.swift` — covers PRV-04, CLN-01/02 coordinator-level wiring

---

## Sources

### Primary (HIGH confidence)
- [Anthropic Models Overview](https://platform.claude.com/docs/en/about-claude/models/overview) — confirmed `claude-haiku-4-5-20251001` as current model ID; claude-3-haiku deprecated April 2026
- [Anthropic Messages API](https://platform.claude.com/docs/en/api/messages) — confirmed endpoint URL, required headers (`x-api-key`, `anthropic-version: 2023-06-01`, `content-type`), JSON body structure
- [Anthropic API Errors](https://platform.claude.com/docs/en/api/errors) — confirmed error shape `{"type":"error","error":{"type":"...","message":"..."}}` for 401/403/429/500/529
- [Apple Developer Documentation — Storing Keys in the Keychain](https://developer.apple.com/documentation/security/storing-keys-in-the-keychain) — `SecItemAdd`, `SecItemCopyMatching`, `kSecClassGenericPassword` usage
- Existing codebase — `AppCoordinator.swift`, `AppCoordinatorDependencies.swift`, `STTEngine.swift`, `NotificationHelper.swift`, `AppDelegate.swift` (directly read)

### Secondary (MEDIUM confidence)
- [Kodeco — Keychain Services API Tutorial](https://www.kodeco.com/9240-keychain-services-api-tutorial-for-passwords-in-swift) — Keychain pattern corroborated by Apple docs
- [Advanced Swift — Keychain Examples](https://www.advancedswift.com/secure-private-data-keychain-swift/) — SecItemDelete-before-add pattern for updates

### Tertiary (LOW confidence)
- None flagged — all critical claims verified via primary sources.

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all system frameworks, confirmed in existing Package.swift and macOS 14+ deployment target
- Architecture: HIGH — directly verified against existing source files; integration point is unambiguous
- API patterns: HIGH — verified against official Anthropic documentation on the day of research
- Pitfalls: MEDIUM — URLSession timeout semantics and NSPanel activation policy verified by code reading; filler prompt coverage is MEDIUM (untested against real speech samples, flagged in Open Questions)

**Research date:** 2026-03-16
**Valid until:** 2026-04-16 (stable REST API; model ID pinned with snapshot date so no drift)
