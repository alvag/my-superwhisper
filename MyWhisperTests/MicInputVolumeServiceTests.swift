import XCTest
@testable import MyWhisper

class MicInputVolumeServiceTests: XCTestCase {
    private let testKey = "maximizeMicVolumeEnabled"

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
        let service = MicInputVolumeService()
        XCTAssertTrue(service.isEnabled)
    }

    func testIsEnabledReturnsFalseWhenDisabled() {
        UserDefaults.standard.set(false, forKey: testKey)
        let service = MicInputVolumeService()
        XCTAssertFalse(service.isEnabled)
    }

    func testIsEnabledReturnsTrueWhenExplicitlyEnabled() {
        UserDefaults.standard.set(true, forKey: testKey)
        let service = MicInputVolumeService()
        XCTAssertTrue(service.isEnabled)
    }

    func testConformsToProtocol() {
        let service = MicInputVolumeService()
        // Compiler verifies conformance — this test documents it
        let _: any MicInputVolumeServiceProtocol = service
    }

    func testRestoreIsNoOpWhenNoSavedVolume() {
        let service = MicInputVolumeService()
        // Should not crash or error when restore() called without prior maximize
        service.restore()
        // If we reach here without crash, the guard-let on savedVolume worked
    }

    func testMaximizeAndSaveIsNoOpWhenDisabled() {
        // Set toggle OFF in standard defaults
        UserDefaults.standard.set(false, forKey: testKey)
        let service = MicInputVolumeService()
        service.maximizeAndSave()
        // restore() should be no-op too since nothing was saved
        service.restore()
    }

    func testRestoreClearsStateAfterCall() {
        // Calling restore() twice should be safe (no double-restore crash)
        let service = MicInputVolumeService()
        service.restore()
        service.restore()  // Second call must also be a no-op
    }
}
