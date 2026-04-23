import XCTest
@testable import MyWhisper

final class OverlayViewTests: XCTestCase {

    private let barMultipliers: [CGFloat] = [0.32, 0.5, 0.72, 1.0, 0.72, 0.5, 0.32]
    private let minHeight: CGFloat = 6
    private let maxHeight: CGFloat = 26

    // MARK: - AudioBarsView bar height tests (REC-03)

    func testBarHeightAtZeroLevel() {
        // At level 0.0, all bars should be at minimum height (6 pts)
        let bars = AudioBarsView(level: 0.0)
        for index in 0..<barMultipliers.count {
            XCTAssertEqual(bars.barHeight(for: index), minHeight,
                           "Bar \(index) should be at minHeight when level is 0")
        }
    }

    func testBarHeightAtFullLevel() {
        // At level 1.0, bars should reach their max heights per multiplier.
        let bars = AudioBarsView(level: 1.0)
        let range = maxHeight - minHeight
        let expectedHeights = barMultipliers.map { minHeight + range * $0 }

        for index in 0..<barMultipliers.count {
            XCTAssertEqual(bars.barHeight(for: index), expectedHeights[index],
                           accuracy: 0.01,
                           "Bar \(index) height mismatch at full level")
        }
    }

    func testCenterBarIsTallest() {
        // Center bar (index 3, multiplier 1.0) should always be tallest.
        let bars = AudioBarsView(level: 0.5)
        let centerIndex = 3
        let centerHeight = bars.barHeight(for: centerIndex)

        for index in 0..<barMultipliers.count where index != centerIndex {
            XCTAssertGreaterThan(centerHeight, bars.barHeight(for: index),
                                 "Center bar should be taller than bar \(index)")
        }
    }

    func testBarsAreSymmetric() {
        let bars = AudioBarsView(level: 0.7)
        let mirroredPairs = [(0, 6), (1, 5), (2, 4)]

        for (left, right) in mirroredPairs {
            XCTAssertEqual(bars.barHeight(for: left), bars.barHeight(for: right),
                           accuracy: 0.01,
                           "Bars \(left) and \(right) should be symmetric")
        }
    }

    func testBarHeightClampsNegativeLevel() {
        // Negative level should clamp to 0, producing minHeight.
        let bars = AudioBarsView(level: -0.5)
        for index in 0..<barMultipliers.count {
            XCTAssertEqual(bars.barHeight(for: index), minHeight,
                           "Bar \(index) should clamp negative level to minHeight")
        }
    }

    func testBarHeightClampsExcessiveLevel() {
        // Level > 1.0 should clamp to 1.0.
        let barsOver = AudioBarsView(level: 2.0)
        let barsMax = AudioBarsView(level: 1.0)
        for index in 0..<barMultipliers.count {
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
        for index in 0..<barMultipliers.count {
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
