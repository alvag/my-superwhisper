import XCTest
@testable import MyWhisper

class KeychainServiceTests: XCTestCase {
    private var configuration: KeychainConfiguration!

    override func setUp() {
        super.setUp()
        configuration = KeychainConfiguration(
            service: "com.mywhisper.tests.keychain.\(UUID().uuidString)",
            account: "anthropic-tests"
        )
        // Clean up any leftover key from a previous test run
        try? KeychainService.delete(configuration: configuration)
    }

    override func tearDown() {
        // Always clean up after each test to avoid Keychain pollution
        try? KeychainService.delete(configuration: configuration)
        configuration = nil
        super.tearDown()
    }

    func testSaveAndLoad() throws {
        let key = "sk-ant-test-key-123"
        try KeychainService.save(key, configuration: configuration)
        let loaded = KeychainService.load(configuration: configuration)
        XCTAssertEqual(loaded, key, "Loaded key should match the saved key")
    }

    func testLoadWithNoSavedKeyReturnsNil() {
        // Nothing saved (cleared in setUp)
        let loaded = KeychainService.load(configuration: configuration)
        XCTAssertNil(loaded, "Load should return nil when no key is stored")
    }

    func testDeleteRemovesKey() throws {
        try KeychainService.save("key-to-delete", configuration: configuration)
        try KeychainService.delete(configuration: configuration)
        let loaded = KeychainService.load(configuration: configuration)
        XCTAssertNil(loaded, "Load should return nil after deleting the key")
    }

    func testDeleteWhenNothingStoredDoesNotThrow() {
        // Should not throw even when there is nothing to delete
        XCTAssertNoThrow(try KeychainService.delete(configuration: configuration))
    }

    func testSaveOverwritesExistingKey() throws {
        try KeychainService.save("key1", configuration: configuration)
        try KeychainService.save("key2", configuration: configuration)
        let loaded = KeychainService.load(configuration: configuration)
        XCTAssertEqual(loaded, "key2", "Saving a second key should overwrite the first")
    }

    func testConfigurationsAreIsolated() throws {
        let first = KeychainConfiguration(
            service: "com.mywhisper.tests.keychain.first.\(UUID().uuidString)",
            account: "anthropic-tests"
        )
        let second = KeychainConfiguration(
            service: "com.mywhisper.tests.keychain.second.\(UUID().uuidString)",
            account: "anthropic-tests"
        )
        defer {
            try? KeychainService.delete(configuration: first)
            try? KeychainService.delete(configuration: second)
        }

        try KeychainService.save("first-key", configuration: first)
        try KeychainService.save("second-key", configuration: second)
        try KeychainService.delete(configuration: second)

        XCTAssertEqual(KeychainService.load(configuration: first), "first-key")
        XCTAssertNil(KeychainService.load(configuration: second))
    }
}
