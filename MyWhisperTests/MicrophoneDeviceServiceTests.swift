import XCTest
@testable import MyWhisper

final class MicrophoneDeviceServiceTests: XCTestCase {
    var defaults: UserDefaults!
    var service: MicrophoneDeviceService!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        service = MicrophoneDeviceService(defaults: defaults)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: defaults.suiteName ?? "")
        super.tearDown()
    }

    func testAvailableInputDevices() throws {
        let devices = MicrophoneDeviceService().availableInputDevices()
        try XCTSkipIf(devices.isEmpty, "No audio hardware available")
        XCTAssertFalse(devices.isEmpty)
        for device in devices {
            XCTAssertFalse(device.name.isEmpty, "Device name should not be empty")
        }
    }

    func testSelectedDeviceIDDefaultNil() {
        XCTAssertNil(service.selectedDeviceID)
    }

    func testSelectedDeviceIDPersistence() {
        let testID: UInt32 = 42
        service.selectedDeviceID = testID
        let service2 = MicrophoneDeviceService(defaults: defaults)
        XCTAssertEqual(service2.selectedDeviceID, testID)
    }

    func testSelectedDeviceIDCanBeCleared() {
        service.selectedDeviceID = 99
        service.selectedDeviceID = nil
        XCTAssertNil(service.selectedDeviceID)
    }
}
