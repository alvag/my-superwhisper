import XCTest
@testable import MyWhisper

final class TranscriptionHistoryServiceTests: XCTestCase {
    var defaults: UserDefaults!
    var service: TranscriptionHistoryService!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        service = TranscriptionHistoryService(defaults: defaults)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: defaults.suiteName ?? "")
        super.tearDown()
    }

    func testAppendAddsEntry() {
        service.append("texto")
        XCTAssertEqual(service.entries.count, 1)
        XCTAssertEqual(service.entries[0].text, "texto")
    }

    func testAppendedEntryHasDate() {
        let before = Date()
        service.append("texto")
        let after = Date()
        let entryDate = service.entries[0].date
        XCTAssertGreaterThanOrEqual(entryDate, before)
        XCTAssertLessThanOrEqual(entryDate, after)
    }

    func testFIFOCapAt20() {
        for i in 1...21 {
            service.append("entry \(i)")
        }
        XCTAssertEqual(service.entries.count, 20)
        // Oldest entry (entry 1) must be removed; newest (entry 21) is at index 0
        XCTAssertEqual(service.entries[0].text, "entry 21")
        XCTAssertFalse(service.entries.contains(where: { $0.text == "entry 1" }))
    }

    func testNewestEntryIsFirst() {
        service.append("first")
        service.append("second")
        XCTAssertEqual(service.entries[0].text, "second")
        XCTAssertEqual(service.entries[1].text, "first")
    }

    func testEntriesPersistToUserDefaults() {
        service.append("persisted entry")
        let service2 = TranscriptionHistoryService(defaults: defaults)
        XCTAssertEqual(service2.entries.count, 1)
        XCTAssertEqual(service2.entries[0].text, "persisted entry")
    }

    func testClearRemovesAllEntries() {
        service.append("entry 1")
        service.append("entry 2")
        service.clear()
        XCTAssertEqual(service.entries.count, 0)
    }

    func testTruncatedComputedProperty() {
        let longText = String(repeating: "a", count: 100)
        service.append(longText)
        let truncated = service.entries[0].truncated
        XCTAssertEqual(truncated, String(repeating: "a", count: 80) + "...")
    }

    func testTruncatedShortTextNoEllipsis() {
        service.append("short text")
        XCTAssertEqual(service.entries[0].truncated, "short text")
    }
}
