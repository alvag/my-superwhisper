import XCTest
@testable import MyWhisper

final class VADTests: XCTestCase {
    func testEmptyBufferReturnsFalse() {
        XCTAssertFalse(VAD.hasSpeech(in: []))
    }

    func testSilentBufferReturnsFalse() {
        // All zeros = 0 RMS, well below threshold
        let silence = [Float](repeating: 0.0, count: 16000)
        XCTAssertFalse(VAD.hasSpeech(in: silence))
    }

    func testLowNoiseReturnsFalse() {
        // 0.005 amplitude = ~0.005 RMS, below default 0.01 threshold
        let noise = (0..<16000).map { _ in Float.random(in: -0.005...0.005) }
        XCTAssertFalse(VAD.hasSpeech(in: noise, threshold: 0.01))
    }

    func testSpeechLevelReturnsTrue() {
        // 0.1 amplitude sine wave = ~0.07 RMS, well above threshold
        let speech = (0..<16000).map { i in
            Float(sin(Double(i) * 2.0 * .pi * 440.0 / 16000.0)) * 0.1
        }
        XCTAssertTrue(VAD.hasSpeech(in: speech))
    }

    func testCustomThresholdRespected() {
        // Buffer with RMS ~0.005, test with threshold 0.003 (should pass)
        let buffer = [Float](repeating: 0.005, count: 16000)
        XCTAssertTrue(VAD.hasSpeech(in: buffer, threshold: 0.003))
        XCTAssertFalse(VAD.hasSpeech(in: buffer, threshold: 0.01))
    }

    func testDefaultThresholdValue() {
        XCTAssertEqual(VAD.defaultThreshold, 0.01)
    }
}
