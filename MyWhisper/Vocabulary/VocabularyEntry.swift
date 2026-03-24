import Foundation

struct VocabularyEntry: Codable, Equatable, Identifiable {
    var id: UUID = UUID()
    var wrong: String
    var correct: String
}
