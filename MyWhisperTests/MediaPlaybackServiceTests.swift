import XCTest
@testable import MyWhisper

@MainActor
final class MediaPlaybackServiceTests: XCTestCase {
    private let testKey = "pausePlaybackEnabled"

    override func setUp() {
        super.setUp()
        // Register default (same as AppDelegate does at launch)
        UserDefaults.standard.register(defaults: [testKey: true])
    }

    override func tearDown() {
        // Clean up UserDefaults to avoid test pollution
        UserDefaults.standard.removeObject(forKey: testKey)
        super.tearDown()
    }

    func testIsEnabledDefaultsToTrue() {
        UserDefaults.standard.removeObject(forKey: testKey)
        // With register(defaults:) in setUp, bool(forKey:) returns true
        let service = MediaPlaybackService()
        XCTAssertTrue(service.isEnabled)
    }

    func testIsEnabledReturnsFalseWhenDisabled() {
        UserDefaults.standard.set(false, forKey: testKey)
        let service = MediaPlaybackService()
        XCTAssertFalse(service.isEnabled)
    }

    func testIsEnabledReturnsTrueWhenExplicitlyEnabled() {
        UserDefaults.standard.set(true, forKey: testKey)
        let service = MediaPlaybackService()
        XCTAssertTrue(service.isEnabled)
    }

    func testTogglePersistedInUserDefaults() {
        UserDefaults.standard.set(false, forKey: testKey)
        let service = MediaPlaybackService()
        XCTAssertFalse(service.isEnabled)

        UserDefaults.standard.set(true, forKey: testKey)
        XCTAssertTrue(service.isEnabled, "isEnabled should reflect live UserDefaults changes")
    }
}
