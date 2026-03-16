import AVFoundation
import Accelerate

// Phase 2: Real audio capture implementation.
// Captures mic audio at hardware sample rate, resamples to 16kHz mono Float32 via AVAudioConverter,
// publishes normalized RMS audioLevel for waveform visualization, accumulates samples for STT.

final class AudioRecorder: AudioRecorderProtocol {
    private var audioEngine: AVAudioEngine?
    private var converter: AVAudioConverter?
    private var accumulator: [Float] = []
    var microphoneService: MicrophoneDeviceService?
    // nonisolated(unsafe): written from audio thread, read from main thread.
    // Acceptable for a single Float visualization value — worst case shows stale level.
    nonisolated(unsafe) private var _audioLevel: Float = 0.0
    private var hardwareSampleRate: Double = 44100.0

    var audioLevel: Float { _audioLevel }

    func start() throws {
        let engine = AVAudioEngine()
        let inputNode = engine.inputNode

        // CRITICAL: use hardware format — never hardcode sample rate (pitfall from RESEARCH.md)
        let hardwareFormat = inputNode.outputFormat(forBus: 0)
        hardwareSampleRate = hardwareFormat.sampleRate

        let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 16000,
            channels: 1,
            interleaved: false
        )!

        guard let audioConverter = AVAudioConverter(from: hardwareFormat, to: targetFormat) else {
            throw AudioRecorderError.converterCreationFailed
        }
        converter = audioConverter

        // Install tap using HARDWARE format (not 16kHz — critical pitfall from RESEARCH.md)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: hardwareFormat) { [weak self] buffer, _ in
            guard let self else { return }

            // (a) Compute RMS on raw buffer for UI visualization
            let channelData = buffer.floatChannelData![0]
            let frameCount = vDSP_Length(buffer.frameLength)
            var rms: Float = 0
            vDSP_rmsqv(channelData, 1, &rms, frameCount)
            // Normalize to 0.0-1.0: typical speech RMS is 0.02-0.15, so multiply by 10
            self._audioLevel = min(rms * 10.0, 1.0)

            // (b) Convert buffer to 16kHz mono Float32 and accumulate
            if let converted = self.convert(buffer: buffer) {
                self.accumulator.append(contentsOf: converted)
            }
        }

        // Apply selected microphone device (MAC-04) BEFORE engine.start()
        // Setting device after start() silently fails
        if let deviceID = microphoneService?.selectedDeviceID {
            try? microphoneService?.setInputDevice(deviceID, on: engine)
        }
        // If no device selected, AVAudioEngine uses system default automatically

        try engine.start()
        audioEngine = engine
    }

    func stop() -> [Float] {
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        converter = nil

        let result = accumulator
        accumulator = []
        _audioLevel = 0.0
        return result
    }

    func cancel() {
        _ = stop()
    }

    // MARK: - Private

    private func convert(buffer: AVAudioPCMBuffer) -> [Float]? {
        guard let converter else { return nil }

        // Calculate output frame count proportional to the ratio 16000 / hardwareSampleRate
        let outputFrameCount = AVAudioFrameCount(
            Double(buffer.frameLength) * (16000.0 / hardwareSampleRate)
        )
        guard outputFrameCount > 0,
              let outputBuffer = AVAudioPCMBuffer(
                  pcmFormat: converter.outputFormat,
                  frameCapacity: outputFrameCount
              ) else {
            return nil
        }

        var error: NSError?
        var inputConsumed = false

        let status = converter.convert(to: outputBuffer, error: &error) { _, outStatus in
            if inputConsumed {
                outStatus.pointee = .noDataNow
                return nil
            }
            inputConsumed = true
            outStatus.pointee = .haveData
            return buffer
        }

        guard status != .error, error == nil,
              let channelData = outputBuffer.floatChannelData else {
            return nil
        }

        let frameLength = Int(outputBuffer.frameLength)
        return Array(UnsafeBufferPointer(start: channelData[0], count: frameLength))
    }
}

enum AudioRecorderError: Error {
    case converterCreationFailed
}
