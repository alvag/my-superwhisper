import XCTest
@testable import MyWhisper

final class MenubarControllerTests: XCTestCase {
    func testIconIsNonTemplate() {
        let img = MenubarController.image(for: .idle)
        XCTAssertNotNil(img)
        XCTAssertFalse(img!.isTemplate, "Menubar icon must not be a template image — color state is required")
    }

    func testAllStatesProduceImages() {
        for state in [AppState.idle, .recording, .processing, .error("test")] {
            XCTAssertNotNil(MenubarController.image(for: state), "image(for: \(state)) returned nil")
        }
    }
}
