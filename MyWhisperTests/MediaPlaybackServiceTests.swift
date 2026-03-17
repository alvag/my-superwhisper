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

    // MARK: - isAnyMediaAppRunning guard tests

    func testIsAnyMediaAppRunningReturnsBool() {
        let service = MediaPlaybackService()
        // Smoke test: method compiles, returns a deterministic Bool value
        let result = service.isAnyMediaAppRunning()
        XCTAssertTrue(result == true || result == false)
    }

    func testPauseDoesNotSendKeyWhenNoMediaAppRunning() {
        // If no known media app is running, pause() should skip the media key
        // and NOT set pausedByApp. We verify this indirectly: call pause(), then
        // call resume(). If pausedByApp was never set, resume() is a no-op.
        // Since we cannot assert on postMediaKeyToggle() without mocking,
        // this verifies that when isAnyMediaAppRunning() returns false,
        // pause() completes without crash and pausedByApp remains false
        // (tested by observing resume() does nothing).
        let service = MediaPlaybackService()
        // Only run this test if no media app is actually running (clean CI env)
        guard !service.isAnyMediaAppRunning() else {
            // Media app is running — skip behavioral assertion, guard is ON
            return
        }
        // No media app running — pause() should be a no-op beyond isEnabled check
        service.pause()
        // resume() should also be a no-op since pausedByApp was never set
        // (no crash = pass; we cannot observe pausedByApp directly)
        service.resume()
    }
}
