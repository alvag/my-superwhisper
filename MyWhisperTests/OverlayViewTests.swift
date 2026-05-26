import XCTest
@testable import MyWhisper

final class OverlayViewTests: XCTestCase {

    private let spectralBarCount = 15
    private let minHeight: CGFloat = 4
    private let maxHeight: CGFloat = 24

    // MARK: - Spectral ribbon bar height tests (REC-03)

    func testSpectralRibbonUsesExpectedBarCount() {
        let bars = AudioBarsView(level: 0.5)
        XCTAssertEqual(bars.barCount, spectralBarCount)
    }

    func testBarHeightAtZeroLevel() {
        // At level 0.0, the ribbon should remain visible instead of collapsing.
        let bars = AudioBarsView(level: 0.0)
        for index in 0..<bars.barCount {
            XCTAssertEqual(bars.barHeight(for: index), minHeight,
                           "Bar \(index) should be at minHeight when level is 0")
        }
    }

    func testBarHeightAtFullLevel() {
        // At level 1.0, the ribbon should stay within the compact overlay bounds.
        let bars = AudioBarsView(level: 1.0)
        for index in 0..<bars.barCount {
            XCTAssertGreaterThanOrEqual(bars.barHeight(for: index), minHeight)
            XCTAssertLessThanOrEqual(bars.barHeight(for: index), maxHeight)
        }
        XCTAssertEqual(bars.barHeight(for: 7), maxHeight, accuracy: 0.01)
    }

    func testSpectralRibbonIsNotPerfectlySymmetric() {
        let bars = AudioBarsView(level: 1.0)
        XCTAssertNotEqual(bars.barHeight(for: 0), bars.barHeight(for: 14), accuracy: 0.01)
        XCTAssertNotEqual(bars.barHeight(for: 2), bars.barHeight(for: 12), accuracy: 0.01)
    }

    func testBarHeightClampsNegativeLevel() {
        // Negative level should clamp to 0, producing minHeight.
        let bars = AudioBarsView(level: -0.5)
        for index in 0..<bars.barCount {
            XCTAssertEqual(bars.barHeight(for: index), minHeight,
                           "Bar \(index) should clamp negative level to minHeight")
        }
    }

    func testBarHeightClampsExcessiveLevel() {
        // Level > 1.0 should clamp to 1.0.
        let barsOver = AudioBarsView(level: 2.0)
        let barsMax = AudioBarsView(level: 1.0)
        for index in 0..<barsMax.barCount {
            XCTAssertEqual(barsOver.barHeight(for: index), barsMax.barHeight(for: index),
                           accuracy: 0.01,
                           "Bar \(index) should clamp level > 1.0 to max")
        }
    }

    func testBarHeightIncreasesWithLevel() {
        // Higher level = taller bars (monotonically increasing).
        let barsLow = AudioBarsView(level: 0.2)
        let barsMid = AudioBarsView(level: 0.5)
        let barsHigh = AudioBarsView(level: 0.8)
        for index in 0..<barsLow.barCount {
            XCTAssertLessThan(barsLow.barHeight(for: index), barsMid.barHeight(for: index),
                              "Bar \(index) should grow from low to mid level")
            XCTAssertLessThan(barsMid.barHeight(for: index), barsHigh.barHeight(for: index),
                              "Bar \(index) should grow from mid to high level")
        }
    }

    // MARK: - OverlayMode tests

    func testOverlayModeEquatableRecording() {
        let a = OverlayMode.recording(audioLevel: 0.5)
        let b = OverlayMode.recording(audioLevel: 0.5)
        let c = OverlayMode.recording(audioLevel: 0.3)
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
    }

    func testOverlayModeEquatableProcessing() {
        XCTAssertEqual(OverlayMode.processing, OverlayMode.processing)
        XCTAssertNotEqual(OverlayMode.processing, OverlayMode.recording(audioLevel: 0))
    }
}
