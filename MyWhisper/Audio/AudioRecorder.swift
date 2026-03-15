import AVFoundation

// Phase 1: Stub implementation — starts/stops AVAudioEngine to validate mic permission
// and trigger the macOS mic LED, but discards all audio. No STT, no network calls.
// Phase 2 replaces this with real audio capture and buffer collection.

final class AudioRecorder: AudioRecorderProtocol {
    private var audioEngine: AVAudioEngine?

    func startStub() {
        let engine = AVAudioEngine()
        let inputNode = engine.inputNode
        // Query actual hardware format (sets up Phase 2 correctly — do NOT hardcode 16kHz)
        let format = inputNode.outputFormat(forBus: 0)
        // Install a tap that discards all audio — PRV-01: audio never leaves the device
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { _, _ in
            // Intentionally empty — Phase 1 discards audio
        }
        do {
            try engine.start()
            self.audioEngine = engine
        } catch {
            // Log only — recording state will still be set
            print("[AudioRecorder] Engine start failed: \(error)")
        }
    }

    func stopStub() {
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
    }

    func cancelStub() {
        stopStub() // Cancel behaves identically to stop in Phase 1 (audio is discarded either way)
    }
}
