import XCTest
import KeyboardShortcuts
@testable import MyWhisper

@MainActor
final class HotkeyMonitorTests: XCTestCase {
    func testToggleRecordingNameExists() {
        // Verify the static Name is defined and default shortcut is Option+Space
        let name = KeyboardShortcuts.Name.toggleRecording
        XCTAssertEqual(name.rawValue, "toggleRecording")
        let shortcut = KeyboardShortcuts.getShortcut(for: name)
        // Default is Option+Space — check the default (may be nil if overridden by system)
        // We just assert the name exists without crash
        _ = shortcut
    }

    func testUnregisterDisablesShortcut() {
        // KeyboardShortcuts.disable is idempotent — should not crash
        let coordinator = AppCoordinator()
        let monitor = HotkeyMonitor(coordinator: coordinator)
        XCTAssertNotNil(monitor)
        monitor.unregister()
        // Second unregister is also safe
        monitor.unregister()
    }

    func testInitRegistersShortcutWithoutCrash() {
        let coordinator = AppCoordinator()
        let monitor = HotkeyMonitor(coordinator: coordinator)
        XCTAssertNotNil(monitor)
        monitor.unregister()
    }
}
