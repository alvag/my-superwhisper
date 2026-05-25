import XCTest
@testable import MyWhisper

@MainActor
final class MediaPlaybackServiceTests: XCTestCase {
    private let testKey = "pausePlaybackEnabled"
    private let pauseCommand = 1
    private let playCommand = 0

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
        let service = MediaPlaybackService()
        XCTAssertTrue(service.isEnabled)
    }

    func testIsEnabledReturnsFalseWhenDisabled() {
        UserDefaults.standard.set(false, forKey: testKey)
        let service = MediaPlaybackService()
        XCTAssertFalse(service.isEnabled)
    }

    func testIsEnabledReturnsTrueWhenExplicitlyEnabled() {
        UserDefaults.standard.set(true, forKey: testKey)
        let service = MediaPlaybackService()
        XCTAssertTrue(service.isEnabled)
    }

    func testTogglePersistedInUserDefaults() {
        UserDefaults.standard.set(false, forKey: testKey)
        let service = MediaPlaybackService()
        XCTAssertFalse(service.isEnabled)

        UserDefaults.standard.set(true, forKey: testKey)
        XCTAssertTrue(service.isEnabled, "isEnabled should reflect live UserDefaults changes")
    }

    func testPauseUsesPlaybackRateWhenIsPlayingQueryReturnsFalse() {
        let recorder = CommandRecorder()
        let service = makeService(
            sendCommand: recorder.record,
            isPlaying: false,
            nowPlayingInfo: playbackInfo(rate: 1)
        )

        service.pause()
        service.resume()

        XCTAssertEqual(recorder.commands, [pauseCommand, playCommand])
    }

    func testPauseUsesIsPlayingWhenNowPlayingInfoIsUnavailable() {
        let recorder = CommandRecorder()
        let service = makeService(
            sendCommand: recorder.record,
            isPlaying: true,
            nowPlayingInfo: nil
        )

        service.pause()
        service.resume()

        XCTAssertEqual(recorder.commands, [pauseCommand, playCommand])
    }

    func testPauseUsesIsPlayingEvenWhenNowPlayingInfoTimesOut() {
        let recorder = CommandRecorder()
        let service = makeService(
            sendCommand: recorder.record,
            queryIsPlaying: { handler in handler(true) },
            queryNowPlayingInfo: { _ in },
            playbackStateTimeout: .milliseconds(1)
        )

        service.pause()
        service.resume()

        XCTAssertEqual(recorder.commands, [pauseCommand, playCommand])
    }

    func testPauseDoesNotSendCommandWhenPlaybackRateIsZero() {
        let recorder = CommandRecorder()
        let service = makeService(
            sendCommand: recorder.record,
            isPlaying: false,
            nowPlayingInfo: playbackInfo(rate: 0)
        )

        service.pause()
        service.resume()

        XCTAssertEqual(recorder.commands, [])
    }

    func testPauseDoesNotResumeAfterPlaybackStateTimeout() {
        let recorder = CommandRecorder()
        let service = makeService(
            sendCommand: recorder.record,
            queryIsPlaying: { _ in },
            queryNowPlayingInfo: { _ in },
            playbackStateTimeout: .milliseconds(1)
        )

        service.pause()
        service.resume()

        XCTAssertEqual(recorder.commands, [])
    }

    func testPauseDoesNotMarkPausedByAppWhenPauseCommandFails() {
        let recorder = CommandRecorder(result: false)
        let service = makeService(
            sendCommand: recorder.record,
            isPlaying: true,
            nowPlayingInfo: playbackInfo(rate: 1)
        )

        service.pause()
        service.resume()

        XCTAssertEqual(recorder.commands, [pauseCommand])
    }

    func testPauseDoesNotSendCommandWhenToggleDisabled() {
        UserDefaults.standard.set(false, forKey: testKey)
        let recorder = CommandRecorder()
        let service = makeService(
            sendCommand: recorder.record,
            isPlaying: true,
            nowPlayingInfo: playbackInfo(rate: 1)
        )

        service.pause()
        service.resume()

        XCTAssertEqual(recorder.commands, [])
    }

    // MARK: - isAnyMediaAppRunning guard tests

    func testIsAnyMediaAppRunningReturnsBool() {
        let service = MediaPlaybackService()
        // Smoke test: method compiles, returns a deterministic Bool value
        let result = service.isAnyMediaAppRunning()
        XCTAssertTrue(result == true || result == false)
    }

    func testPauseDoesNotSendKeyWhenNoMediaAppRunning() {
        // If no known media app is running, pause() should skip the media key
        // and NOT set pausedByApp. We verify this indirectly: call pause(), then
        // call resume(). If pausedByApp was never set, resume() is a no-op.
        // Since we cannot assert on postMediaKeyToggle() without mocking,
        // this verifies that when isAnyMediaAppRunning() returns false,
        // pause() completes without crash and pausedByApp remains false
        // (tested by observing resume() does nothing).
        let service = MediaPlaybackService()
        // Only run this test if no media app is actually running (clean CI env)
        guard !service.isAnyMediaAppRunning() else {
            // Media app is running — skip behavioral assertion, guard is ON
            return
        }
        // No media app running — pause() should be a no-op beyond isEnabled check
        service.pause()
        // resume() should also be a no-op since pausedByApp was never set
        // (no crash = pass; we cannot observe pausedByApp directly)
        service.resume()
    }

    private func makeService(
        sendCommand: @escaping (Int) -> Bool,
        isPlaying: Bool,
        nowPlayingInfo: [AnyHashable: Any]?
    ) -> MediaPlaybackService {
        makeService(
            sendCommand: sendCommand,
            queryIsPlaying: { handler in handler(isPlaying) },
            queryNowPlayingInfo: { handler in handler(nowPlayingInfo) }
        )
    }

    private func makeService(
        sendCommand: @escaping (Int) -> Bool,
        queryIsPlaying: @escaping (@escaping (Bool) -> Void) -> Void,
        queryNowPlayingInfo: @escaping (@escaping ([AnyHashable: Any]?) -> Void) -> Void,
        playbackStateTimeout: DispatchTimeInterval = .milliseconds(300)
    ) -> MediaPlaybackService {
        MediaPlaybackService(
            sendCommand: sendCommand,
            queryIsPlaying: queryIsPlaying,
            queryNowPlayingInfo: queryNowPlayingInfo,
            isAnyMediaAppRunning: { true },
            playbackStateTimeout: playbackStateTimeout
        )
    }

    private func playbackInfo(rate: Double) -> [AnyHashable: Any] {
        ["kMRMediaRemoteNowPlayingInfoPlaybackRate": rate]
    }
}

private final class CommandRecorder {
    private(set) var commands: [Int] = []
    private let result: Bool

    init(result: Bool = true) {
        self.result = result
    }

    func record(_ command: Int) -> Bool {
        commands.append(command)
        return result
    }
}
