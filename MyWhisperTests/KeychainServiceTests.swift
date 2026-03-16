import XCTest
@testable import MyWhisper

class KeychainServiceTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Clean up any leftover key from a previous test run
        try? KeychainService.delete()
    }

    override func tearDown() {
        // Always clean up after each test to avoid Keychain pollution
        try? KeychainService.delete()
        super.tearDown()
    }

    func testSaveAndLoad() throws {
        let key = "sk-ant-test-key-123"
        try KeychainService.save(key)
        let loaded = KeychainService.load()
        XCTAssertEqual(loaded, key, "Loaded key should match the saved key")
    }

    func testLoadWithNoSavedKeyReturnsNil() {
        // Nothing saved (cleared in setUp)
        let loaded = KeychainService.load()
        XCTAssertNil(loaded, "Load should return nil when no key is stored")
    }

    func testDeleteRemovesKey() throws {
        try KeychainService.save("key-to-delete")
        try KeychainService.delete()
        let loaded = KeychainService.load()
        XCTAssertNil(loaded, "Load should return nil after deleting the key")
    }

    func testDeleteWhenNothingStoredDoesNotThrow() {
        // Should not throw even when there is nothing to delete
        XCTAssertNoThrow(try KeychainService.delete())
    }

    func testSaveOverwritesExistingKey() throws {
        try KeychainService.save("key1")
        try KeychainService.save("key2")
        let loaded = KeychainService.load()
        XCTAssertEqual(loaded, "key2", "Saving a second key should overwrite the first")
    }
}
