import XCTest
@testable import MyWhisper

/// MockSTTEngineProtocol for testing STTEngineProtocol behavior in isolation.
/// Verifies that the protocol contract supports model readiness checks,
/// progress reporting, and transcription (STT-02).
final class MockSTTEngineProtocol: STTEngineProtocol, @unchecked Sendable {
    var mockTranscription: String = "Hola mundo"
    var shouldThrow = false
    var prepareModelCalled = false
    var transcribeCalled = false
    var resetCalled = false
    private var _isReady = false
    private var _loadProgress: Double = 0.0
    var modelName: String = "openai_whisper-large-v3"
    var modelDirectory: URL = URL(fileURLWithPath: "/tmp/MyWhisperTests/Models")
    var modelAssetsStatus: ModelAssetsStatus = .missing

    var isReady: Bool { _isReady }
    var loadProgress: Double { _loadProgress }

    func prepareModel() async throws {
        prepareModelCalled = true
        _loadProgress = 1.0
        _isReady = true
        modelAssetsStatus = .ready
    }

    func resetModelAssets() async throws {
        resetCalled = true
        _loadProgress = 0.0
        _isReady = false
        modelAssetsStatus = .missing
    }

    func transcribe(_ audioArray: [Float]) async throws -> String {
        transcribeCalled = true
        if shouldThrow {
            throw STTError.transcriptionFailed(underlying: NSError(domain: "test", code: 1))
        }
        if audioArray.isEmpty {
            throw STTError.emptyResult
        }
        return mockTranscription
    }
}

final class STTEngineTests: XCTestCase {

    // MARK: - Model readiness (STT-02)

    func testMockEngineNotReadyBeforePrepare() async {
        let engine = MockSTTEngineProtocol()
        let ready = await engine.isReady
        XCTAssertFalse(ready, "Engine should not be ready before prepareModel()")
    }

    func testMockEngineReadyAfterPrepare() async throws {
        let engine = MockSTTEngineProtocol()
        try await engine.prepareModel()
        let ready = await engine.isReady
        XCTAssertTrue(ready, "Engine should be ready after prepareModel()")
        XCTAssertTrue(engine.prepareModelCalled)
    }

    func testLoadProgressZeroBeforePrepare() async {
        let engine = MockSTTEngineProtocol()
        let progress = await engine.loadProgress
        XCTAssertEqual(progress, 0.0, "Progress should be 0 before model load")
    }

    func testLoadProgressOneAfterPrepare() async throws {
        let engine = MockSTTEngineProtocol()
        try await engine.prepareModel()
        let progress = await engine.loadProgress
        XCTAssertEqual(progress, 1.0, "Progress should be 1.0 after model load")
    }

    func testModelMetadataContract() async {
        let engine = MockSTTEngineProtocol()
        let modelName = await engine.modelName
        let modelDirectory = await engine.modelDirectory
        let assetsStatus = await engine.modelAssetsStatus
        XCTAssertEqual(modelName, "openai_whisper-large-v3")
        XCTAssertTrue(modelDirectory.path.contains("MyWhisperTests"))
        XCTAssertEqual(assetsStatus, .missing)
    }

    func testResetModelAssetsClearsReadiness() async throws {
        let engine = MockSTTEngineProtocol()
        try await engine.prepareModel()
        try await engine.resetModelAssets()
        let isReady = await engine.isReady
        let loadProgress = await engine.loadProgress
        let assetsStatus = await engine.modelAssetsStatus
        XCTAssertTrue(engine.resetCalled)
        XCTAssertFalse(isReady)
        XCTAssertEqual(loadProgress, 0.0)
        XCTAssertEqual(assetsStatus, .missing)
    }

    // MARK: - Transcription (STT-02 protocol contract)

    func testTranscribeReturnsText() async throws {
        let engine = MockSTTEngineProtocol()
        try await engine.prepareModel()
        let text = try await engine.transcribe([0.1, 0.2, 0.3])
        XCTAssertEqual(text, "Hola mundo")
        XCTAssertTrue(engine.transcribeCalled)
    }

    func testTranscribeThrowsOnError() async throws {
        let engine = MockSTTEngineProtocol()
        engine.shouldThrow = true
        try await engine.prepareModel()
        do {
            _ = try await engine.transcribe([0.1, 0.2])
            XCTFail("Expected transcription error")
        } catch {
            XCTAssertTrue(error is STTError)
        }
    }

    func testTranscribeEmptyBufferThrows() async throws {
        let engine = MockSTTEngineProtocol()
        try await engine.prepareModel()
        do {
            _ = try await engine.transcribe([])
            XCTFail("Expected emptyResult error for empty buffer")
        } catch let error as STTError {
            if case .emptyResult = error {
                // expected
            } else {
                XCTFail("Expected STTError.emptyResult, got \(error)")
            }
        }
    }

    // MARK: - STTError tests

    func testSTTErrorDescriptions() {
        let notLoaded = STTError.notLoaded
        XCTAssertNotNil(notLoaded.errorDescription)
        XCTAssertTrue(notLoaded.errorDescription!.contains("modelo"))

        let empty = STTError.emptyResult
        XCTAssertNotNil(empty.errorDescription)
        XCTAssertTrue(empty.errorDescription!.contains("texto"))

        let failed = STTError.transcriptionFailed(underlying: NSError(domain: "test", code: 42))
        XCTAssertNotNil(failed.errorDescription)
        XCTAssertTrue(failed.errorDescription!.contains("transcripcion"))

        let busy = STTError.modelBusy
        XCTAssertNotNil(busy.errorDescription)
        XCTAssertTrue(busy.errorDescription!.contains("ocupado"))
    }
}
