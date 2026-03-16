import Foundation

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
        case .authFailed:     return "Clave de API invalida o sin credito"
        case .rateLimited:    return "Limite de solicitudes alcanzado"
        case .serverError(let code): return "Error del servidor Anthropic (\(code))"
        case .invalidResponse: return "Respuesta inesperada de la API"
        case .networkError:   return "Error de red"
        }
    }
}
