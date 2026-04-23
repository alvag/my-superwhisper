import Foundation

actor HaikuCleanupService: HaikuCleanupProtocol {

    // MARK: - Private types

    private struct AnthropicResponse: Decodable {
        struct ContentBlock: Decodable {
            let type: String
            let text: String?
        }
        let content: [ContentBlock]?
    }

    // MARK: - Properties

    private let session: URLSession

    private let systemPrompt = """
Eres un corrector de texto para dictado en español. \
Recibe texto bruto de reconocimiento de voz y devuelve el mismo texto corregido, sin modificar el significado.

Reglas estrictas:
1. PUNTUACIÓN: Añade puntos, comas y signos de interrogación/exclamación (¿? ¡!) según la norma del español de la RAE. Pon mayúscula después de punto.
2. PÁRRAFOS: Si el texto tiene cambios de tema o pausas lógicas claras, añade un salto de línea. Para textos cortos (< 3 oraciones), NO añadas párrafos.
3. MULETILLAS: Elimina únicamente: "eh", "este", "o sea", "bueno pues", "pues este", "o sea que". NO elimines expresiones coloquiales que aporten significado.
4. REPETICIONES: Elimina repeticiones literales de palabras consecutivas (ej. "yo yo creo" → "yo creo"). NO elimines si la repetición es intencional (ej. "muy muy importante").
5. PROHIBIDO: NO parafrasees, NO agregues palabras que no estaban, NO reestructures oraciones, NO cambies el registro ni el tono.
6. ORIGEN STT: El texto viene de reconocimiento de voz (STT) y puede terminar abruptamente. NO completes ni agregues palabras de cortesía al final (gracias, de nada, hasta luego) salvo que estén literalmente en el texto original. Si la oración termina abruptamente, termínala igual de abruptamente.

Devuelve SOLO el texto corregido. Sin explicaciones, sin comillas, sin prefijos.
"""

    // MARK: - Init

    init(session: URLSession? = nil) {
        if let session = session {
            self.session = session
        } else {
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = 5.0
            config.timeoutIntervalForResource = 5.0
            config.requestCachePolicy = .reloadIgnoringLocalCacheData
            self.session = URLSession(configuration: config)
        }
    }

    // MARK: - HaikuCleanupProtocol

    func clean(_ rawText: String) async throws -> String {
        guard let apiKey = KeychainService.load() else {
            throw HaikuCleanupError.noAPIKey
        }

        let url = URL(string: "https://api.anthropic.com/v1/messages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")

        let body: [String: Any] = [
            "model": "claude-haiku-4-5-20251001",
            "max_tokens": estimateMaxTokens(for: rawText),
            "system": systemPrompt,
            "messages": [["role": "user", "content": rawText]]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let urlError as URLError {
            throw HaikuCleanupError.networkError(urlError)
        }

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
    }

    var hasAPIKey: Bool {
        KeychainService.load() != nil
    }

    func saveAPIKey(_ key: String) async throws {
        try await validate(apiKey: key)
        try KeychainService.save(key)
        AppDiagnosticsStore.recordAPIValidation("Válida")
    }

    func validateStoredAPIKey() async throws {
        guard let apiKey = KeychainService.load(), !apiKey.isEmpty else {
            AppDiagnosticsStore.recordAPIValidation("No configurada")
            throw HaikuCleanupError.noAPIKey
        }

        try await validate(apiKey: apiKey)
        AppDiagnosticsStore.recordAPIValidation("Válida")
    }

    func removeAPIKey() async throws {
        try KeychainService.delete()
        AppDiagnosticsStore.recordAPIValidation("Eliminada")
    }

    // MARK: - Private helpers

    func estimateMaxTokens(for text: String) -> Int {
        let estimate = Int(Double(text.count) / 4.0 * 1.5)
        return min(max(estimate, 128), 2048)
    }

    private func validate(apiKey: String) async throws {
        let url = URL(string: "https://api.anthropic.com/v1/messages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")

        let body: [String: Any] = [
            "model": "claude-haiku-4-5-20251001",
            "max_tokens": 5,
            "messages": [["role": "user", "content": "hola"]]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let _: Data
        let response: URLResponse
        do {
            (_, response) = try await session.data(for: request)
        } catch let urlError as URLError {
            AppDiagnosticsStore.recordAPIValidation("Error de red")
            throw HaikuCleanupError.networkError(urlError)
        }

        let httpResponse = response as! HTTPURLResponse
        switch httpResponse.statusCode {
        case 200:
            return
        case 401, 403:
            AppDiagnosticsStore.recordAPIValidation("Inválida o sin crédito")
            throw HaikuCleanupError.authFailed
        case 429:
            AppDiagnosticsStore.recordAPIValidation("Rate limited")
            throw HaikuCleanupError.rateLimited
        default:
            AppDiagnosticsStore.recordAPIValidation("Error servidor (\(httpResponse.statusCode))")
            throw HaikuCleanupError.serverError(httpResponse.statusCode)
        }
    }
}
