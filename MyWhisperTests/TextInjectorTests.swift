import XCTest
import AppKit
@testable import MyWhisper

final class TextInjectorTests: XCTestCase {

    func testPasteboardWrite() async {
        let injector = TextInjector() // No permissionsManager = skips permission check
        await injector.inject("Hola mundo")
        let result = NSPasteboard.general.string(forType: .string)
        XCTAssertEqual(result, "Hola mundo", "NSPasteboard should contain injected text")
    }

    func testPasteboardWriteOverwritesPrevious() async {
        let injector = TextInjector()
        await injector.inject("Primera")
        await injector.inject("Segunda")
        let result = NSPasteboard.general.string(forType: .string)
        XCTAssertEqual(result, "Segunda", "Second injection should overwrite first — clipboard not restored per spec")
    }
}
