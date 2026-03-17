import AppKit

final class MediaPlaybackService: MediaPlaybackServiceProtocol {
    private var pausedByApp = false
    private let sendCommand: (Int) -> Bool
    private let queryIsPlaying: (@escaping (Bool) -> Void) -> Void

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
    }

    func pause() {
        guard isEnabled else { return }
        guard isAnyMediaAppRunning() else { return }
        guard isMediaPlaying() else { return }
        _ = sendCommand(1) // MRMediaRemoteCommandPause
        pausedByApp = true
    }

    func isAnyMediaAppRunning() -> Bool {
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
        let sem = DispatchSemaphore(value: 0)
        var playing = false
        queryIsPlaying { isPlaying in
            playing = isPlaying
            sem.signal()
        }
        // 100ms timeout — if we can't determine state, assume not playing (safe: no false resume)
        let result = sem.wait(timeout: .now() + 0.1)
        return result == .success ? playing : false
    }
}
