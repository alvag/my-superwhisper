import Foundation

enum AppState: Equatable {
    case idle
    case recording
    case transcribing
    case cleaning
    case processing
    case error(String)

    var description: String {
        switch self {
        case .idle: return "Listo"
        case .recording: return "Grabando..."
        case .transcribing: return "Transcribiendo..."
        case .cleaning: return "Limpiando..."
        case .processing: return "Procesando..."
        case .error(let msg): return "Error: \(msg)"
        }
    }
}
