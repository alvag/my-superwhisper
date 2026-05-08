import Foundation
import WhisperKit

actor STTEngine: STTEngineProtocol {
    private var whisperKit: WhisperKit?
    private var isLoading: Bool = false
    private var _loadProgress: Double = 0.0
    private let repository = "argmaxinc/whisperkit-coreml"
    private let modelVariant = AppDiagnosticsStore.sttModelName

    // MARK: - STTEngineProtocol

    /// Prepare the model (download if needed, prewarm, load). Call at app launch.
    /// Guard against re-entry — safe to call multiple times.
    func prepareModel() async throws {
        guard whisperKit == nil, !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        // Download model into Application Support (avoids iCloud sync of ~/.cache/huggingface)
        let modelsDir = modelDirectory
        try FileManager.default.createDirectory(at: modelsDir, withIntermediateDirectories: true)

        let modelFolder = try await WhisperKit.download(
            variant: modelVariant,
            downloadBase: modelsDir,
            from: repository,
            progressCallback: { [weak self] progress in
                guard let self else { return }
                // Download accounts for the first 50% of total load progress
                Task { await self.setLoadProgress(progress.fractionCompleted * 0.5) }
            }
        )

        // Initialize WhisperKit with CoreML/ANE compute
        // WhisperKit.download returns a URL, WhisperKitConfig.modelFolder expects a String path
        let config = WhisperKitConfig(
            model: modelVariant,
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
        if whisperKit == nil {
            if isLoading {
                // Model is downloading — wait for it instead of failing immediately
                while isLoading {
                    try await Task.sleep(nanoseconds: 200_000_000) // 200ms
                }
            } else {
                try await prepareModel()
            }
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

    var modelName: String {
        modelVariant
    }

    var modelDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("MyWhisper/Models", isDirectory: true)
    }

    var modelAssetsStatus: ModelAssetsStatus {
        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: modelDirectory.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            return .missing
        }

        guard let enumerator = fileManager.enumerator(
            at: modelDirectory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return .partial
        }

        var regularFileCount = 0
        for case let fileURL as URL in enumerator {
            let values = try? fileURL.resourceValues(forKeys: [.isRegularFileKey])
            if values?.isRegularFile == true {
                regularFileCount += 1
                if regularFileCount >= 3 {
                    return .ready
                }
            }
        }

        return regularFileCount > 0 ? .partial : .missing
    }

    func resetModelAssets() async throws {
        whisperKit = nil
        isLoading = false
        _loadProgress = 0.0

        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: modelDirectory.path) {
            try fileManager.removeItem(at: modelDirectory)
        }
    }

    // MARK: - Private helpers

    private func setLoadProgress(_ value: Double) {
        _loadProgress = value
    }
}
