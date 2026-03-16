import XCTest
@testable import MyWhisper

final class VocabularyServiceTests: XCTestCase {
    var defaults: UserDefaults!
    var service: VocabularyService!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        service = VocabularyService(defaults: defaults)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: defaults.suiteName ?? "")
        super.tearDown()
    }

    func testApplyCorrectsSingleEntry() {
        service.entries = [VocabularyEntry(wrong: "cluad", correct: "Claude")]
        let result = service.apply(to: "Hola cluad")
        XCTAssertEqual(result, "Hola Claude")
    }

    func testApplyCaseInsensitive() {
        service.entries = [VocabularyEntry(wrong: "cluad", correct: "Claude")]
        let result = service.apply(to: "CLUAD es bueno")
        XCTAssertEqual(result, "Claude es bueno")
    }

    func testApplyEmptyEntriesReturnsOriginal() {
        service.entries = []
        let original = "texto sin cambios"
        let result = service.apply(to: original)
        XCTAssertEqual(result, original)
    }

    func testEntriesPersistToUserDefaults() {
        let entries = [VocabularyEntry(wrong: "cluad", correct: "Claude"), VocabularyEntry(wrong: "wsp", correct: "WhisperKit")]
        service.entries = entries
        // Re-instantiate with same defaults to verify persistence
        let service2 = VocabularyService(defaults: defaults)
        XCTAssertEqual(service2.entries, entries)
    }

    func testMultipleCorrectionsAppliedInSequence() {
        service.entries = [
            VocabularyEntry(wrong: "cluad", correct: "Claude"),
            VocabularyEntry(wrong: "wsp", correct: "WhisperKit")
        ]
        let result = service.apply(to: "uso cluad con wsp")
        XCTAssertEqual(result, "uso Claude con WhisperKit")
    }
}
