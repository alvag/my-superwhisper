import Foundation

enum STTError: LocalizedError {
    case notLoaded
    case transcriptionFailed(underlying: Error)
    case emptyResult
    case modelBusy

    var errorDescription: String? {
        switch self {
        case .notLoaded:
            return "El modelo de transcripcion no esta cargado"
        case .transcriptionFailed(let error):
            return "Error de transcripcion: \(error.localizedDescription)"
        case .emptyResult:
            return "La transcripcion no produjo texto"
        case .modelBusy:
            return "El modelo esta ocupado; intenta nuevamente cuando termine la carga o transcripcion"
        }
    }
}
