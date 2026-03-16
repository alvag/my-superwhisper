import Foundation

final class VocabularyService {
    private let defaultsKey = "vocabularyCorrections"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var entries: [VocabularyEntry] {
        get {
            guard let data = defaults.data(forKey: defaultsKey),
                  let decoded = try? JSONDecoder().decode([VocabularyEntry].self, from: data) else {
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

    func apply(to text: String) -> String {
        var result = text
        for entry in entries where !entry.wrong.isEmpty {
            result = result.replacingOccurrences(
                of: entry.wrong,
                with: entry.correct,
                options: [.caseInsensitive]
            )
        }
        return result
    }
}
