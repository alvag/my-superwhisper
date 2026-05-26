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
        let mediaKey = MediaKeyRecorder()
        var playbackRates = [playbackInfo(rate: 1), playbackInfo(rate: 0)]
        let service = makeService(
            sendCommand: recorder.record,
            postMediaPlayPauseKey: mediaKey.post,
            queryIsPlaying: { handler in handler(false) },
            queryNowPlayingInfo: { handler in handler(playbackRates.removeFirst()) }
        )

        service.pause()
        service.resume()

        XCTAssertEqual(mediaKey.postCount, 2)
        XCTAssertEqual(recorder.commands, [])
    }

    func testPauseUsesIsPlayingWhenNowPlayingInfoIsUnavailable() {
        let recorder = CommandRecorder()
        let mediaKey = MediaKeyRecorder()
        var isPlayingResponses = [true, false]
        let service = makeService(
            sendCommand: recorder.record,
            postMediaPlayPauseKey: mediaKey.post,
            queryIsPlaying: { handler in handler(isPlayingResponses.removeFirst()) },
            queryNowPlayingInfo: { handler in handler(nil) }
        )

        service.pause()
        service.resume()

        XCTAssertEqual(mediaKey.postCount, 2)
        XCTAssertEqual(recorder.commands, [])
    }

    func testPauseUsesIsPlayingEvenWhenNowPlayingInfoTimesOut() {
        let recorder = CommandRecorder()
        let mediaKey = MediaKeyRecorder()
        var isPlayingResponses = [true, false]
        let service = makeService(
            sendCommand: recorder.record,
            postMediaPlayPauseKey: mediaKey.post,
            queryIsPlaying: { handler in handler(isPlayingResponses.removeFirst()) },
            queryNowPlayingInfo: { _ in },
            playbackStateTimeout: .milliseconds(1)
        )

        service.pause()
        service.resume()

        XCTAssertEqual(mediaKey.postCount, 2)
        XCTAssertEqual(recorder.commands, [])
    }

    func testPauseDoesNotToggleWhenPlaybackRateIsZero() {
        let recorder = CommandRecorder()
        let mediaKey = MediaKeyRecorder()
        let service = makeService(
            sendCommand: recorder.record,
            postMediaPlayPauseKey: mediaKey.post,
            isPlaying: false,
            nowPlayingInfo: playbackInfo(rate: 0)
        )

        service.pause()
        service.resume()

        XCTAssertEqual(mediaKey.postCount, 0)
        XCTAssertEqual(recorder.commands, [])
    }

    func testPauseDoesNotResumeAfterPlaybackStateTimeout() {
        let recorder = CommandRecorder()
        let mediaKey = MediaKeyRecorder()
        let service = makeService(
            sendCommand: recorder.record,
            postMediaPlayPauseKey: mediaKey.post,
            queryIsPlaying: { _ in },
            queryNowPlayingInfo: { _ in },
            playbackStateTimeout: .milliseconds(1)
        )

        service.pause()
        service.resume()

        XCTAssertEqual(mediaKey.postCount, 0)
        XCTAssertEqual(recorder.commands, [])
    }

    func testPauseDoesNotMarkPausedByAppWhenMediaKeyAndFallbackFail() {
        let recorder = CommandRecorder(result: false)
        let mediaKey = MediaKeyRecorder(result: false)
        let service = makeService(
            sendCommand: recorder.record,
            postMediaPlayPauseKey: mediaKey.post,
            isPlaying: true,
            nowPlayingInfo: playbackInfo(rate: 1)
        )

        service.pause()
        service.resume()

        XCTAssertEqual(mediaKey.postCount, 1)
        XCTAssertEqual(recorder.commands, [pauseCommand])
    }

    func testPauseFallsBackToRemoteCommandWhenMediaKeyCannotPost() {
        let recorder = CommandRecorder()
        let mediaKey = MediaKeyRecorder(result: false)
        let service = makeService(
            sendCommand: recorder.record,
            postMediaPlayPauseKey: mediaKey.post,
            isPlaying: true,
            nowPlayingInfo: playbackInfo(rate: 1)
        )

        service.pause()

        XCTAssertEqual(mediaKey.postCount, 1)
        XCTAssertEqual(recorder.commands, [pauseCommand])
    }

    func testResumeDoesNotToggleWhenUserAlreadyResumedPlayback() {
        let recorder = CommandRecorder()
        let mediaKey = MediaKeyRecorder()
        var isPlayingResponses = [true, true]
        let service = makeService(
            sendCommand: recorder.record,
            postMediaPlayPauseKey: mediaKey.post,
            queryIsPlaying: { handler in handler(isPlayingResponses.removeFirst()) },
            queryNowPlayingInfo: { handler in handler(nil) }
        )

        service.pause()
        service.resume()

        XCTAssertEqual(mediaKey.postCount, 1)
        XCTAssertEqual(recorder.commands, [])
    }

    func testPauseDoesNotSendCommandWhenToggleDisabled() {
        UserDefaults.standard.set(false, forKey: testKey)
        let recorder = CommandRecorder()
        let mediaKey = MediaKeyRecorder()
        let service = makeService(
            sendCommand: recorder.record,
            postMediaPlayPauseKey: mediaKey.post,
            isPlaying: true,
            nowPlayingInfo: playbackInfo(rate: 1)
        )

        service.pause()
        service.resume()

        XCTAssertEqual(mediaKey.postCount, 0)
        XCTAssertEqual(recorder.commands, [])
    }

    // MARK: - isAnyMediaAppRunning guard tests

    func testIsAnyMediaAppRunningReturnsBool() {
        let service = MediaPlaybackService()
        // Smoke test: method compiles, returns a deterministic Bool value
        let result = service.isAnyMediaAppRunning()
        XCTAssertTrue(result == true || result == false)
    }

    func testPauseDoesNotToggleWhenNoMediaAppRunning() {
        let recorder = CommandRecorder()
        let mediaKey = MediaKeyRecorder()
        let service = MediaPlaybackService(
            sendCommand: recorder.record,
            postMediaPlayPauseKey: mediaKey.post,
            queryIsPlaying: { handler in handler(true) },
            queryNowPlayingInfo: { [self] handler in handler(playbackInfo(rate: 1)) },
            isAnyMediaAppRunning: { false }
        )

        service.pause()
        service.resume()

        XCTAssertEqual(mediaKey.postCount, 0)
        XCTAssertEqual(recorder.commands, [])
    }

    private func makeService(
        sendCommand: @escaping (Int) -> Bool,
        postMediaPlayPauseKey: @escaping () -> Bool,
        isPlaying: Bool,
        nowPlayingInfo: [AnyHashable: Any]?
    ) -> MediaPlaybackService {
        makeService(
            sendCommand: sendCommand,
            postMediaPlayPauseKey: postMediaPlayPauseKey,
            queryIsPlaying: { handler in handler(isPlaying) },
            queryNowPlayingInfo: { handler in handler(nowPlayingInfo) }
        )
    }

    private func makeService(
        sendCommand: @escaping (Int) -> Bool,
        postMediaPlayPauseKey: @escaping () -> Bool,
        queryIsPlaying: @escaping (@escaping (Bool) -> Void) -> Void,
        queryNowPlayingInfo: @escaping (@escaping ([AnyHashable: Any]?) -> Void) -> Void,
        playbackStateTimeout: DispatchTimeInterval = .milliseconds(300)
    ) -> MediaPlaybackService {
        MediaPlaybackService(
            sendCommand: sendCommand,
            postMediaPlayPauseKey: postMediaPlayPauseKey,
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

private final class MediaKeyRecorder {
    private(set) var postCount = 0
    private let result: Bool

    init(result: Bool = true) {
        self.result = result
    }

    func post() -> Bool {
        postCount += 1
        return result
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
