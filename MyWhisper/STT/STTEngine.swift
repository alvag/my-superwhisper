import Foundation
import WhisperKit

actor STTEngine: STTEngineProtocol {
    private var whisperKit: WhisperKit?
    private var isLoading: Bool = false
    private var _loadProgress: Double = 0.0

    // MARK: - STTEngineProtocol

    /// Prepare the model (download if needed, prewarm, load). Call at app launch.
    /// Guard against re-entry — safe to call multiple times.
    func prepareModel() async throws {
        guard whisperKit == nil, !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        // Download model (first launch: ~3GB; cached on subsequent launches)
        let modelFolder = try await WhisperKit.download(
            variant: "openai_whisper-large-v3",
            from: "argmaxinc/whisperkit-coreml",
            progressCallback: { [weak self] progress in
                guard let self else { return }
                // Download accounts for the first 50% of total load progress
                Task { await self.setLoadProgress(progress.fractionCompleted * 0.5) }
            }
        )

        // Initialize WhisperKit with CoreML/ANE compute
        // WhisperKit.download returns a URL, WhisperKitConfig.modelFolder expects a String path
        let config = WhisperKitConfig(
            model: "openai_whisper-large-v3",
            modelFolder: modelFolder.path,
            computeOptions: ModelComputeOptions(audioEncoderCompute: .cpuAndNeuralEngine)
        )
        whisperKit = try await WhisperKit(config)
        _loadProgress = 0.75

        // Prewarm + load — both required (prewarm alone is not sufficient per research)
        try await whisperKit?.prewarmModels()
        try await whisperKit?.loadModels()
        _loadProgress = 1.0
    }

    /// Transcribe a 16kHz mono Float32 audio buffer to Spanish text.
    func transcribe(_ audioArray: [Float]) async throws -> String {
        // If model not loaded, attempt to prepare it (user may have recorded before load finished)
        if whisperKit == nil && !isLoading {
            try await prepareModel()
        }
        guard let kit = whisperKit else {
            throw STTError.notLoaded
        }

        // Force Spanish — no auto-detection per locked decision
        let options = DecodingOptions(
            language: "es",
            temperature: 0.0,
            temperatureFallbackCount: 3,
            sampleLength: 224,
            noSpeechThreshold: 0.6
        )

        let results = try await kit.transcribe(audioArray: audioArray, decodeOptions: options)
        let text = results.map { $0.text }.joined(separator: " ").trimmingCharacters(in: .whitespaces)

        guard !text.isEmpty else {
            throw STTError.emptyResult
        }
        return text
    }

    /// Whether the model is loaded and ready for transcription.
    var isReady: Bool {
        whisperKit != nil
    }

    /// Model download/load progress (0.0-1.0). Observable for UI.
    var loadProgress: Double {
        _loadProgress
    }

    // MARK: - Private helpers

    private func setLoadProgress(_ value: Double) {
        _loadProgress = value
    }
}
