import XCTest
@testable import MyWhisper

final class AudioRecorderTests: XCTestCase {
    func testStopWithoutStartReturnsEmptyBuffer() {
        let recorder = AudioRecorder()
        let buffer = recorder.stop()
        XCTAssertTrue(buffer.isEmpty)
    }

    func testCancelWithoutStartDoesNotCrash() {
        let recorder = AudioRecorder()
        recorder.cancel()
        // Should not throw or crash
    }

    func testInitialAudioLevelIsZero() {
        let recorder = AudioRecorder()
        XCTAssertEqual(recorder.audioLevel, 0.0)
    }
}
