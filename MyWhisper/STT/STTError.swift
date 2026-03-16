import Foundation

enum STTError: LocalizedError {
    case notLoaded
    case transcriptionFailed(underlying: Error)
    case emptyResult

    var errorDescription: String? {
        switch self {
        case .notLoaded:
            return "El modelo de transcripcion no esta cargado"
        case .transcriptionFailed(let error):
            return "Error de transcripcion: \(error.localizedDescription)"
        case .emptyResult:
            return "La transcripcion no produjo texto"
        }
    }
}
