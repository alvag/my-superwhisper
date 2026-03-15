import Foundation

enum AppState: Equatable {
    case idle
    case recording
    case processing
    case error(String)

    var description: String {
        switch self {
        case .idle: return "Listo"
        case .recording: return "Grabando..."
        case .processing: return "Procesando..."
        case .error(let msg): return "Error: \(msg)"
        }
    }
}
