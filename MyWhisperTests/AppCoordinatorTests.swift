import XCTest
@testable import MyWhisper

// MARK: - Mock for permission testing

final class MockPermissionsManaging: PermissionsManaging {
    var shouldGrantMicrophone: Bool
    init(grant: Bool) { self.shouldGrantMicrophone = grant }
    func requestMicrophone() async -> Bool { shouldGrantMicrophone }
}

@MainActor
final class AppCoordinatorTests: XCTestCase {
    var coordinator: AppCoordinator!

    override func setUp() {
        super.setUp()
        coordinator = AppCoordinator()
    }

    func testHotkeyStartsRecording() async {
        XCTAssertEqual(coordinator.state, .idle)
        await coordinator.handleHotkey()
        XCTAssertEqual(coordinator.state, .recording)
    }

    func testHotkeyStopsRecordingAndReturnsIdle() async {
        // idle -> recording
        await coordinator.handleHotkey()
        XCTAssertEqual(coordinator.state, .recording)
        // recording -> processing -> idle (textInjector is nil, so processing completes immediately)
        await coordinator.handleHotkey()
        XCTAssertEqual(coordinator.state, .idle)
    }

    func testHotkeyIgnoredDuringProcessing() async {
        // Manually set processing state to test the guard
        coordinator.state = .processing
        await coordinator.handleHotkey()
        XCTAssertEqual(coordinator.state, .processing) // unchanged
    }

    func testEscapeCancelsRecording() async {
        await coordinator.handleHotkey() // start recording
        XCTAssertEqual(coordinator.state, .recording)
        coordinator.handleEscape()
        XCTAssertEqual(coordinator.state, .idle)
    }

    // MARK: - On-the-fly permission tests (MAC-02)

    func testHotkeyDeniedMicrophoneTransitionsToError() async {
        let mock = MockPermissionsManaging(grant: false)
        coordinator.permissionsManager = mock
        await coordinator.handleHotkey()
        XCTAssertEqual(coordinator.state, .error("microphone"))
    }

    func testHotkeyGrantedMicrophoneProceedsToRecording() async {
        let mock = MockPermissionsManaging(grant: true)
        coordinator.permissionsManager = mock
        await coordinator.handleHotkey()
        XCTAssertEqual(coordinator.state, .recording)
    }

    func testHotkeyNilPermissionsManagerProceedsToRecording() async {
        // permissionsManager is nil — existing behavior must not break
        coordinator.permissionsManager = nil
        await coordinator.handleHotkey()
        XCTAssertEqual(coordinator.state, .recording)
    }
}
