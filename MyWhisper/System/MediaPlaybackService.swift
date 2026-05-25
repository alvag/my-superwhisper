import AppKit

final class MediaPlaybackService: MediaPlaybackServiceProtocol {
    private var pausedByApp = false
    private let sendCommand: (Int) -> Bool
    private let queryIsPlaying: (@escaping (Bool) -> Void) -> Void
    private let queryNowPlayingInfo: (@escaping ([AnyHashable: Any]?) -> Void) -> Void
    private let mediaAppRunningProvider: () -> Bool
    private let playbackStateTimeout: DispatchTimeInterval

    var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: "pausePlaybackEnabled")
    }

    init() {
        // Dynamically load from private MediaRemote framework
        let frameworkURL = NSURL(fileURLWithPath: "/System/Library/PrivateFrameworks/MediaRemote.framework")
        let bundle = CFBundleCreate(kCFAllocatorDefault, frameworkURL)

        if let bundle,
           let ptr = CFBundleGetFunctionPointerForName(bundle, "MRMediaRemoteSendCommand" as CFString) {
            typealias MRSendCommand = @convention(c) (Int, AnyObject?) -> Bool
            let fn = unsafeBitCast(ptr, to: MRSendCommand.self)
            sendCommand = { command in fn(command, nil) }
        } else {
            sendCommand = { _ in false }
        }

        if let bundle,
           let ptr = CFBundleGetFunctionPointerForName(bundle, "MRMediaRemoteGetNowPlayingApplicationIsPlaying" as CFString) {
            typealias MRIsPlaying = @convention(c) (DispatchQueue, @escaping (Bool) -> Void) -> Void
            let fn = unsafeBitCast(ptr, to: MRIsPlaying.self)
            queryIsPlaying = { handler in fn(DispatchQueue.global(), handler) }
        } else {
            queryIsPlaying = { handler in handler(false) }
        }

        if let bundle,
           let ptr = CFBundleGetFunctionPointerForName(bundle, "MRMediaRemoteGetNowPlayingInfo" as CFString) {
            typealias MRNowPlayingInfo = @convention(c) (DispatchQueue, @escaping ([AnyHashable: Any]?) -> Void) -> Void
            let fn = unsafeBitCast(ptr, to: MRNowPlayingInfo.self)
            queryNowPlayingInfo = { handler in fn(DispatchQueue.global(), handler) }
        } else {
            queryNowPlayingInfo = { handler in handler(nil) }
        }

        mediaAppRunningProvider = Self.defaultIsAnyMediaAppRunning
        playbackStateTimeout = .milliseconds(300)
    }

    init(sendCommand: @escaping (Int) -> Bool,
         queryIsPlaying: @escaping (@escaping (Bool) -> Void) -> Void,
         queryNowPlayingInfo: @escaping (@escaping ([AnyHashable: Any]?) -> Void) -> Void,
         isAnyMediaAppRunning: @escaping () -> Bool,
         playbackStateTimeout: DispatchTimeInterval = .milliseconds(300)) {
        self.sendCommand = sendCommand
        self.queryIsPlaying = queryIsPlaying
        self.queryNowPlayingInfo = queryNowPlayingInfo
        self.mediaAppRunningProvider = isAnyMediaAppRunning
        self.playbackStateTimeout = playbackStateTimeout
    }

    func pause() {
        guard isEnabled else { return }
        guard isAnyMediaAppRunning() else { return }
        guard isMediaPlaying() else { return }
        guard sendCommand(1) else { return } // MRMediaRemoteCommandPause
        pausedByApp = true
    }

    func isAnyMediaAppRunning() -> Bool {
        mediaAppRunningProvider()
    }

    private static func defaultIsAnyMediaAppRunning() -> Bool {
        let mediaApps: Set<String> = [
            "com.spotify.client",
            "com.apple.Music",
            "org.videolan.vlc",
            "com.apple.Safari",
            "com.google.Chrome",
            "org.mozilla.firefox"
        ]
        return NSWorkspace.shared.runningApplications
            .compactMap(\.bundleIdentifier)
            .contains { mediaApps.contains($0) }
    }

    func resume() {
        guard pausedByApp else { return }
        pausedByApp = false
        guard isEnabled else { return }
        _ = sendCommand(0) // MRMediaRemoteCommandPlay
    }

    private func isMediaPlaying() -> Bool {
        let group = DispatchGroup()
        let lock = NSLock()
        var isPlaying = false
        var playbackRate: Double?

        group.enter()
        queryIsPlaying { currentIsPlaying in
            lock.lock()
            isPlaying = currentIsPlaying
            lock.unlock()
            group.leave()
        }

        group.enter()
        queryNowPlayingInfo { info in
            lock.lock()
            playbackRate = Self.playbackRate(from: info)
            lock.unlock()
            group.leave()
        }

        // If a query times out, still trust any positive signal already received.
        // If neither query confirms playback, assume not playing (safe: no false resume).
        _ = group.wait(timeout: .now() + playbackStateTimeout)

        lock.lock()
        defer { lock.unlock() }
        return isPlaying || (playbackRate ?? 0) > 0
    }

    private static func playbackRate(from info: [AnyHashable: Any]?) -> Double? {
        guard let info else { return nil }
        guard let value = info.first(where: { key, _ in
            String(describing: key) == "kMRMediaRemoteNowPlayingInfoPlaybackRate"
        })?.value else {
            return nil
        }

        if let number = value as? NSNumber {
            return number.doubleValue
        }
        if let double = value as? Double {
            return double
        }
        if let float = value as? Float {
            return Double(float)
        }
        if let int = value as? Int {
            return Double(int)
        }
        return nil
    }
}
