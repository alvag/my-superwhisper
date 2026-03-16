import XCTest
@testable import MyWhisper

final class OverlayViewTests: XCTestCase {

    // MARK: - AudioBarsView bar height tests (REC-03)

    func testBarHeightAtZeroLevel() {
        // At level 0.0, all bars should be at minimum height (4 pts)
        let bars = AudioBarsView(level: 0.0)
        for index in 0..<5 {
            XCTAssertEqual(bars.barHeight(for: index), 4.0,
                           "Bar \(index) should be at minHeight when level is 0")
        }
    }

    func testBarHeightAtFullLevel() {
        // At level 1.0, bars should reach their max heights per multiplier
        // multipliers: [0.5, 0.8, 1.0, 0.8, 0.5]
        // minHeight=4, maxHeight=32, range=28
        // height = 4 + 28 * 1.0 * multiplier
        let bars = AudioBarsView(level: 1.0)
        let expectedHeights: [CGFloat] = [
            4 + 28 * 0.5,  // 18
            4 + 28 * 0.8,  // 26.4
            4 + 28 * 1.0,  // 32
            4 + 28 * 0.8,  // 26.4
            4 + 28 * 0.5,  // 18
        ]
        for index in 0..<5 {
            XCTAssertEqual(bars.barHeight(for: index), expectedHeights[index],
                           accuracy: 0.01,
                           "Bar \(index) height mismatch at full level")
        }
    }

    func testCenterBarIsTallest() {
        // Center bar (index 2, multiplier 1.0) should always be tallest
        let bars = AudioBarsView(level: 0.5)
        let centerHeight = bars.barHeight(for: 2)
        for index in [0, 1, 3, 4] {
            XCTAssertGreaterThan(centerHeight, bars.barHeight(for: index),
                                 "Center bar should be taller than bar \(index)")
        }
    }

    func testBarsAreSymmetric() {
        // Bars 0,4 (multiplier 0.5) and bars 1,3 (multiplier 0.8) should match
        let bars = AudioBarsView(level: 0.7)
        XCTAssertEqual(bars.barHeight(for: 0), bars.barHeight(for: 4),
                       accuracy: 0.01, "Outer bars should be symmetric")
        XCTAssertEqual(bars.barHeight(for: 1), bars.barHeight(for: 3),
                       accuracy: 0.01, "Inner bars should be symmetric")
    }

    func testBarHeightClampsNegativeLevel() {
        // Negative level should clamp to 0, producing minHeight
        let bars = AudioBarsView(level: -0.5)
        for index in 0..<5 {
            XCTAssertEqual(bars.barHeight(for: index), 4.0,
                           "Bar \(index) should clamp negative level to minHeight")
        }
    }

    func testBarHeightClampsExcessiveLevel() {
        // Level > 1.0 should clamp to 1.0
        let barsOver = AudioBarsView(level: 2.0)
        let barsMax = AudioBarsView(level: 1.0)
        for index in 0..<5 {
            XCTAssertEqual(barsOver.barHeight(for: index), barsMax.barHeight(for: index),
                           accuracy: 0.01,
                           "Bar \(index) should clamp level > 1.0 to max")
        }
    }

    func testBarHeightIncreasesWithLevel() {
        // Higher level = taller bars (monotonically increasing)
        let barsLow = AudioBarsView(level: 0.2)
        let barsMid = AudioBarsView(level: 0.5)
        let barsHigh = AudioBarsView(level: 0.8)
        for index in 0..<5 {
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
