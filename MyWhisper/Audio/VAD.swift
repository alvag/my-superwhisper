import Accelerate

enum VAD {
    /// Default RMS threshold for speech detection.
    /// 0.01 RMS ~ -40 dBFS. Typical speech: 0.02-0.15, room noise: 0.003-0.008.
    static let defaultThreshold: Float = 0.01

    /// Returns true if the audio buffer contains speech above the threshold.
    static func hasSpeech(in samples: [Float], threshold: Float = defaultThreshold) -> Bool {
        guard !samples.isEmpty else { return false }
        var rms: Float = 0
        vDSP_rmsqv(samples, 1, &rms, vDSP_Length(samples.count))
        return rms >= threshold
    }
}
