---
status: diagnosed
phase: 03-haiku-cleanup
source: 03-01-SUMMARY.md, 03-02-SUMMARY.md
started: 2026-03-16T11:00:00Z
updated: 2026-03-16T11:10:00Z
---

## Current Test
<!-- OVERWRITE each test - shows where we are -->

[testing complete]

## Tests

### 1. API Key Modal on First Recording
expected: Abrir la app sin API key configurada. Presionar Option+Space para grabar. En lugar de iniciar la grabación, aparece una ventana modal (400x180) con un campo de texto seguro (enmascarado) para ingresar la API key de Anthropic, un botón "Guardar", y una etiqueta de estado. La grabación NO inicia hasta que se configure una key válida.
result: issue
reported: "el dialog para ingresar la clave api no muestra ningun input"
severity: major

### 2. API Key Validation on Save
expected: Ingresar una API key inválida (ej: "sk-invalid-test") y presionar Guardar. La etiqueta de estado muestra un mensaje de error (la key no se guarda). Luego ingresar una key válida de Anthropic y presionar Guardar. La etiqueta muestra "Validando...", la key se valida contra la API, y al confirmar se guarda y la ventana se cierra.
result: skipped
reason: Bloqueado por issue #1 — modal no muestra input field

### 3. API Key Menu Item
expected: Click en el icono de la menubar. En el menú desplegable aparece la opción "Clave de API..." (antes de "Preferencias..."). Al hacer click, se abre la misma ventana modal de configuración de API key.
result: skipped
reason: Bloqueado por issue #1 — modal no muestra input field

### 4. End-to-End Haiku Cleanup
expected: Con la API key configurada, presionar Option+Space, dictar algo en español con muletillas (ej: "eh bueno este yo creo que que la reunión fue fue bastante productiva o sea logramos avanzar en en los temas principales"), presionar Option+Space de nuevo. El spinner aparece durante el procesamiento. El texto pegado tiene puntuación correcta (¿¡ si aplica, puntos, comas), capitalización, las muletillas ("eh", "este", "o sea", "bueno") y repeticiones ("que que", "fue fue", "en en") eliminadas, pero el significado original preservado.
result: skipped
reason: Bloqueado por issue #1 — no se puede configurar API key

### 5. Error Fallback — Raw Text Paste
expected: Desconectar internet (o invalidar la API key). Grabar y dictar algo en español. Al parar, el spinner aparece brevemente, luego el texto crudo (sin limpiar) se pega en el cursor + aparece una notificación macOS indicando que el texto se pegó sin limpiar por error de conexión. El usuario siempre recibe texto.
result: skipped
reason: Bloqueado por issue #1 — no se puede configurar API key

### 6. Auth Failure Recovery
expected: Después de un error de autenticación (key inválida o sin crédito), la próxima vez que se presione Option+Space, en lugar de grabar aparece automáticamente la ventana modal de API key para corregirla. Una vez corregida, el siguiente intento de grabación funciona normalmente.
result: skipped
reason: Bloqueado por issue #1 — no se puede configurar API key

### 7. Keychain Persistence
expected: Configurar la API key, cerrar completamente la app (Cmd+Q), y volver a abrirla. La API key sigue configurada — al presionar Option+Space inicia la grabación directamente sin pedir la key de nuevo. La key se almacena en macOS Keychain.
result: skipped
reason: Bloqueado por issue #1 — no se puede configurar API key

## Summary

total: 7
passed: 0
issues: 1
pending: 0
skipped: 6
skipped: 0

## Gaps

- truth: "API key modal muestra campo de texto seguro (NSSecureTextField) para ingresar la API key"
  status: resolved
  reason: "User reported: el dialog para ingresar la clave api no muestra ningun input"
  severity: major
  test: 1
  root_cause: "contentView.translatesAutoresizingMaskIntoConstraints = false en APIKeyWindowController.swift línea 41 — desactiva el autoresizing del content view del NSPanel, causando tamaño 0x0. Los subviews con constraints relativos al contentView quedan invisibles."
  artifacts:
    - path: "MyWhisper/UI/APIKeyWindowController.swift"
      issue: "translatesAutoresizingMaskIntoConstraints = false en contentView del panel"
  missing:
    - "Remover translatesAutoresizingMaskIntoConstraints = false del contentView (solo aplica a subviews, no al content view del window)"
  debug_session: ""
