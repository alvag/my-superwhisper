import XCTest
@testable import MyWhisper

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
}
