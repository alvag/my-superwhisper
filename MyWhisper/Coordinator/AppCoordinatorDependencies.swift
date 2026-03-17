protocol AudioRecorderProtocol: AnyObject {
    /// Start audio capture. Throws if AVAudioEngine fails to start.
    func start() throws
    /// Stop capture and return accumulated 16kHz mono Float32 samples.
    func stop() -> [Float]
    /// Cancel capture, discard all accumulated audio.
    func cancel()
    /// Current audio level (0.0-1.0 normalized RMS). Updated from tap callback.
    var audioLevel: Float { get }
}

protocol TextInjectorProtocol: AnyObject {
    func inject(_ text: String) async
}

@MainActor
protocol OverlayWindowControllerProtocol: AnyObject {
    func show()
    func hide()
    func showProcessing()
    func updateAudioLevel(_ level: Float)
}

protocol STTEngineProtocol: AnyObject, Sendable {
    /// Prepare the model (download if needed, prewarm, load). Call at app launch.
    func prepareModel() async throws
    /// Transcribe a 16kHz mono Float32 audio buffer to text.
    func transcribe(_ audioArray: [Float]) async throws -> String
    /// Whether the model is loaded and ready for transcription.
    var isReady: Bool { get async }
    /// Model download/load progress (0.0-1.0). Observable for UI.
    var loadProgress: Double { get async }
}

protocol MediaPlaybackServiceProtocol: AnyObject {
    func pause()
    func resume()
    var isEnabled: Bool { get }
}

protocol MicInputVolumeServiceProtocol: AnyObject {
    /// Read current input volume, store it, then set input volume to 1.0.
    func maximizeAndSave()
    /// Restore the input volume saved by the last maximizeAndSave() call.
    func restore()
    /// Whether the feature is enabled (UserDefaults toggle).
    var isEnabled: Bool { get }
}
