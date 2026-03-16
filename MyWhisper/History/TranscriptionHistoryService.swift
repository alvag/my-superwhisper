import Foundation

struct HistoryEntry: Codable, Identifiable {
    let id: UUID
    let text: String
    let date: Date

    var truncated: String {
        text.count > 80 ? String(text.prefix(80)) + "..." : text
    }
}

final class TranscriptionHistoryService {
    private let defaultsKey = "transcriptionHistory"
    static let maxEntries = 20
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var entries: [HistoryEntry] {
        get {
            guard let data = defaults.data(forKey: defaultsKey),
                  let decoded = try? JSONDecoder().decode([HistoryEntry].self, from: data) else {
                return []
            }
            return decoded
        }
        set {
            if let encoded = try? JSONEncoder().encode(newValue) {
                defaults.set(encoded, forKey: defaultsKey)
            }
        }
    }

    func append(_ text: String) {
        var current = entries
        let entry = HistoryEntry(id: UUID(), text: text, date: Date())
        current.insert(entry, at: 0)
        if current.count > Self.maxEntries {
            current = Array(current.prefix(Self.maxEntries))
        }
        entries = current
    }

    func clear() {
        entries = []
    }
}
