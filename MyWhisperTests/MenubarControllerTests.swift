import XCTest
@testable import MyWhisper

final class MenubarControllerTests: XCTestCase {
    func testIdleIconIsTemplate() {
        let img = MenubarController.image(for: .idle)
        XCTAssertNotNil(img)
        XCTAssertTrue(img!.isTemplate, "Idle menubar icon should stay template so macOS can highlight and adapt it")
    }

    func testActiveIconsAreNonTemplate() {
        for state in [AppState.recording, .transcribing, .cleaning, .processing, .error("test")] {
            let img = MenubarController.image(for: state)
            XCTAssertNotNil(img)
            XCTAssertFalse(img!.isTemplate, "Active state \(state) should use an explicit color")
        }
    }

    func testAllStatesProduceImages() {
        for state in [AppState.idle, .recording, .transcribing, .cleaning, .processing, .error("test")] {
            XCTAssertNotNil(MenubarController.image(for: state), "image(for: \(state)) returned nil")
        }
    }
}
