import XCTest
@testable import MyWhisper

@MainActor
final class HotkeyMonitorTests: XCTestCase {
    func testHotkeyMonitorInitWithoutCrash() {
        // HotKey Carbon registration is system-level — verify init does not throw/crash
        let coordinator = AppCoordinator()
        let monitor = HotkeyMonitor(coordinator: coordinator)
        XCTAssertNotNil(monitor)
        monitor.unregister()
    }
}
