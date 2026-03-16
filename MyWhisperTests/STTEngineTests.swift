import XCTest
@testable import MyWhisper

/// MockSTTEngine for testing STTEngineProtocol consumers.
/// Verifies that the protocol contract supports model readiness checks,
/// progress reporting, and transcription (STT-02).
final class MockSTTEngine: STTEngineProtocol, @unchecked Sendable {
    var mockTranscription: String = "Hola mundo"
    var shouldThrow = false
    var prepareModelCalled = false
    var transcribeCalled = false
    private var _isReady = false
    private var _loadProgress: Double = 0.0

    var isReady: Bool { _isReady }
    var loadProgress: Double { _loadProgress }

    func prepareModel() async throws {
        prepareModelCalled = true
        _loadProgress = 1.0
        _isReady = true
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
        let engine = MockSTTEngine()
        let ready = await engine.isReady
        XCTAssertFalse(ready, "Engine should not be ready before prepareModel()")
    }

    func testMockEngineReadyAfterPrepare() async throws {
        let engine = MockSTTEngine()
        try await engine.prepareModel()
        let ready = await engine.isReady
        XCTAssertTrue(ready, "Engine should be ready after prepareModel()")
        XCTAssertTrue(engine.prepareModelCalled)
    }

    func testLoadProgressZeroBeforePrepare() async {
        let engine = MockSTTEngine()
        let progress = await engine.loadProgress
        XCTAssertEqual(progress, 0.0, "Progress should be 0 before model load")
    }

    func testLoadProgressOneAfterPrepare() async throws {
        let engine = MockSTTEngine()
        try await engine.prepareModel()
        let progress = await engine.loadProgress
        XCTAssertEqual(progress, 1.0, "Progress should be 1.0 after model load")
    }

    // MARK: - Transcription (STT-02 protocol contract)

    func testTranscribeReturnsText() async throws {
        let engine = MockSTTEngine()
        try await engine.prepareModel()
        let text = try await engine.transcribe([0.1, 0.2, 0.3])
        XCTAssertEqual(text, "Hola mundo")
        XCTAssertTrue(engine.transcribeCalled)
    }

    func testTranscribeThrowsOnError() async throws {
        let engine = MockSTTEngine()
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
        let engine = MockSTTEngine()
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
    }
}
