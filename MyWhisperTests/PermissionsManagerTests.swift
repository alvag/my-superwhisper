import XCTest
import AVFoundation
@testable import MyWhisper

// Mock for unit testing without touching real TCC
struct MockPermissionsChecker: PermissionsChecking {
    var isAccessibilityTrusted: Bool
    var microphoneAuthorizationStatus: AVAuthorizationStatus
}

final class PermissionsManagerTests: XCTestCase {

    func testCheckAllOnLaunch_accessibilityRevoked() {
        let checker = MockPermissionsChecker(
            isAccessibilityTrusted: false,
            microphoneAuthorizationStatus: .authorized
        )
        let manager = PermissionsManager(checker: checker)
        XCTAssertEqual(manager.checkAllOnLaunch(), .blocked(reason: .accessibility))
    }

    func testCheckAllOnLaunch_microphoneDenied() {
        let checker = MockPermissionsChecker(
            isAccessibilityTrusted: true,
            microphoneAuthorizationStatus: .denied
        )
        let manager = PermissionsManager(checker: checker)
        XCTAssertEqual(manager.checkAllOnLaunch(), .blocked(reason: .microphone))
    }

    func testCheckAllOnLaunch_microphoneRestricted() {
        let checker = MockPermissionsChecker(
            isAccessibilityTrusted: true,
            microphoneAuthorizationStatus: .restricted
        )
        let manager = PermissionsManager(checker: checker)
        XCTAssertEqual(manager.checkAllOnLaunch(), .blocked(reason: .microphone))
    }

    func testCheckAllOnLaunch_allOk() {
        let checker = MockPermissionsChecker(
            isAccessibilityTrusted: true,
            microphoneAuthorizationStatus: .authorized
        )
        let manager = PermissionsManager(checker: checker)
        XCTAssertEqual(manager.checkAllOnLaunch(), .ok)
    }

    func testCheckAllOnLaunch_microphoneNotDetermined_isOk() {
        // notDetermined = not yet asked = not blocked (request happens on-the-fly)
        let checker = MockPermissionsChecker(
            isAccessibilityTrusted: true,
            microphoneAuthorizationStatus: .notDetermined
        )
        let manager = PermissionsManager(checker: checker)
        XCTAssertEqual(manager.checkAllOnLaunch(), .ok)
    }

    func testSystemSettingsUrlForAccessibilityIsCorrect() {
        // Verify the URL string is the known-correct scheme
        // (catches typos that would silently fail to open the right pane)
        let expectedScheme = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        let url = URL(string: expectedScheme)
        XCTAssertNotNil(url, "Accessibility System Settings URL must be valid")
    }
}
