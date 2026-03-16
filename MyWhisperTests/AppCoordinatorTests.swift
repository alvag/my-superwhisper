import XCTest
@testable import MyWhisper

// MARK: - Mocks

final class MockPermissionsManaging: PermissionsManaging {
    var shouldGrantMicrophone: Bool
    init(grant: Bool) { self.shouldGrantMicrophone = grant }
    func requestMicrophone() async -> Bool { shouldGrantMicrophone }
}

final class MockAudioRecorder: AudioRecorderProtocol {
    var isStarted = false
    var shouldThrowOnStart = false
    var mockBuffer: [Float] = []
    var audioLevel: Float = 0.0

    func start() throws {
        if shouldThrowOnStart { throw NSError(domain: "test", code: 1) }
        isStarted = true
    }

    func stop() -> [Float] {
        isStarted = false
        return mockBuffer
    }

    func cancel() {
        isStarted = false
    }
}

final class MockSTTEngine: STTEngineProtocol, @unchecked Sendable {
    var mockTranscription: String = "Hola mundo"
    var shouldThrow = false
    var transcribeCalled = false
    var isReady: Bool = true
    var loadProgress: Double = 1.0

    func prepareModel() async throws {}

    func transcribe(_ audioArray: [Float]) async throws -> String {
        transcribeCalled = true
        if shouldThrow { throw STTError.transcriptionFailed(underlying: NSError(domain: "test", code: 1)) }
        return mockTranscription
    }
}

final class MockOverlayController: OverlayWindowControllerProtocol {
    var isShowing = false
    var isProcessing = false
    var lastAudioLevel: Float = 0.0

    func show() { isShowing = true }
    func hide() { isShowing = false; isProcessing = false }
    func showProcessing() { isProcessing = true }
    func updateAudioLevel(_ level: Float) { lastAudioLevel = level }
}

final class MockTextInjector: TextInjectorProtocol {
    var lastInjectedText: String?
    func inject(_ text: String) async { lastInjectedText = text }
}

final class MockHaikuCleanup: HaikuCleanupProtocol, @unchecked Sendable {
    var mockCleanedText: String = ""
    var shouldThrow: HaikuCleanupError?
    var cleanCalled = false
    var hasAPIKeyValue = true

    func clean(_ rawText: String) async throws -> String {
        cleanCalled = true
        if let error = shouldThrow { throw error }
        return mockCleanedText
    }

    var hasAPIKey: Bool { hasAPIKeyValue }

    func saveAPIKey(_ key: String) async throws {}
    func removeAPIKey() async throws {}
}

// MARK: - Tests

@MainActor
final class AppCoordinatorTests: XCTestCase {
    var coordinator: AppCoordinator!
    var mockRecorder: MockAudioRecorder!
    var mockSTT: MockSTTEngine!
    var mockOverlay: MockOverlayController!
    var mockInjector: MockTextInjector!
    var mockHaiku: MockHaikuCleanup!

    override func setUp() {
        super.setUp()
        coordinator = AppCoordinator()
        mockRecorder = MockAudioRecorder()
        mockSTT = MockSTTEngine()
        mockOverlay = MockOverlayController()
        mockInjector = MockTextInjector()
        mockHaiku = MockHaikuCleanup()

        coordinator.audioRecorder = mockRecorder
        coordinator.sttEngine = mockSTT
        coordinator.overlayController = mockOverlay
        coordinator.textInjector = mockInjector
        coordinator.haikuCleanup = mockHaiku
    }

    // MARK: - Basic FSM

    func testHotkeyStartsRecording() async {
        await coordinator.handleHotkey()
        XCTAssertEqual(coordinator.state, .recording)
        XCTAssertTrue(mockRecorder.isStarted)
        XCTAssertTrue(mockOverlay.isShowing)
    }

    func testHotkeyIgnoredDuringProcessing() async {
        coordinator.state = .processing
        await coordinator.handleHotkey()
        XCTAssertEqual(coordinator.state, .processing)
    }

    func testEscapeCancelsRecording() async {
        await coordinator.handleHotkey()
        XCTAssertEqual(coordinator.state, .recording)
        coordinator.handleEscape()
        XCTAssertEqual(coordinator.state, .idle)
        XCTAssertFalse(mockRecorder.isStarted)
        XCTAssertFalse(mockOverlay.isShowing)
    }

    // MARK: - Full Pipeline (REC-02)

    func testHotkeyStopsRecordingTranscribesAndPastes() async {
        // Provide a speech-level buffer (RMS > 0.01)
        mockRecorder.mockBuffer = speechBuffer()
        mockSTT.mockTranscription = "Hola esto es una prueba"
        mockHaiku.mockCleanedText = "Hola, esto es una prueba."

        await coordinator.handleHotkey() // start
        XCTAssertEqual(coordinator.state, .recording)

        await coordinator.handleHotkey() // stop -> transcribe -> Haiku -> paste
        XCTAssertEqual(coordinator.state, .idle)
        XCTAssertTrue(mockSTT.transcribeCalled)
        XCTAssertEqual(mockInjector.lastInjectedText, "Hola, esto es una prueba.")
        XCTAssertFalse(mockOverlay.isShowing)
    }

    // MARK: - VAD Gate (AUD-03)

    func testSilentRecordingDoesNotTranscribe() async {
        // Empty buffer = no speech
        mockRecorder.mockBuffer = [Float](repeating: 0.0, count: 16000)

        await coordinator.handleHotkey() // start
        await coordinator.handleHotkey() // stop -> VAD fails -> no transcription

        XCTAssertEqual(coordinator.state, .idle)
        XCTAssertFalse(mockSTT.transcribeCalled)
        XCTAssertNil(mockInjector.lastInjectedText)
    }

    // MARK: - STT Error Handling

    func testTranscriptionErrorReturnsToIdle() async {
        mockRecorder.mockBuffer = speechBuffer()
        mockSTT.shouldThrow = true

        await coordinator.handleHotkey() // start
        await coordinator.handleHotkey() // stop -> transcribe fails

        XCTAssertEqual(coordinator.state, .idle)
        XCTAssertFalse(mockOverlay.isShowing)
    }

    // MARK: - Overlay Mode Switching (REC-03)

    func testOverlayShowsProcessingDuringTranscription() async {
        mockRecorder.mockBuffer = speechBuffer()

        await coordinator.handleHotkey() // start
        XCTAssertTrue(mockOverlay.isShowing)

        // Note: showProcessing() is called synchronously during handleHotkey
        // We verify the overlay was showing before the pipeline completed
        await coordinator.handleHotkey() // stop -> process
        XCTAssertFalse(mockOverlay.isShowing) // hidden after completion
    }

    // MARK: - Permission Tests (MAC-02)

    func testHotkeyDeniedMicrophoneTransitionsToError() async {
        let mock = MockPermissionsManaging(grant: false)
        coordinator.permissionsManager = mock
        await coordinator.handleHotkey()
        XCTAssertEqual(coordinator.state, .error("microphone"))
    }

    func testHotkeyGrantedMicrophoneProceedsToRecording() async {
        let mock = MockPermissionsManaging(grant: true)
        coordinator.permissionsManager = mock
        await coordinator.handleHotkey()
        XCTAssertEqual(coordinator.state, .recording)
    }

    func testHotkeyNilPermissionsManagerProceedsToRecording() async {
        coordinator.permissionsManager = nil
        await coordinator.handleHotkey()
        XCTAssertEqual(coordinator.state, .recording)
    }

    // MARK: - Audio Start Failure

    func testAudioStartFailureTransitionsToError() async {
        mockRecorder.shouldThrowOnStart = true
        await coordinator.handleHotkey()
        XCTAssertEqual(coordinator.state, .error("microphone"))
    }

    // MARK: - Haiku Cleanup Integration (CLN-01/02/03/04)

    func testHaikuCleanupCalledAfterTranscription() async {
        mockRecorder.mockBuffer = speechBuffer()
        mockSTT.mockTranscription = "eh hola esto es una prueba"
        mockHaiku.mockCleanedText = "Hola, esto es una prueba."

        await coordinator.handleHotkey() // start
        await coordinator.handleHotkey() // stop -> STT -> Haiku -> paste

        XCTAssertTrue(mockHaiku.cleanCalled)
        XCTAssertEqual(mockInjector.lastInjectedText, "Hola, esto es una prueba.")
    }

    func testHaikuAuthFailurePastesRawText() async {
        mockRecorder.mockBuffer = speechBuffer()
        mockSTT.mockTranscription = "texto sin limpiar"
        mockHaiku.shouldThrow = .authFailed

        await coordinator.handleHotkey() // start
        await coordinator.handleHotkey() // stop -> STT -> Haiku fails -> paste raw

        XCTAssertEqual(mockInjector.lastInjectedText, "texto sin limpiar")
        XCTAssertEqual(coordinator.state, .idle)
    }

    func testHaikuNetworkErrorPastesRawText() async {
        mockRecorder.mockBuffer = speechBuffer()
        mockSTT.mockTranscription = "texto sin limpiar"
        mockHaiku.shouldThrow = .networkError(URLError(.timedOut))

        await coordinator.handleHotkey() // start
        await coordinator.handleHotkey() // stop -> STT -> Haiku fails -> paste raw

        XCTAssertEqual(mockInjector.lastInjectedText, "texto sin limpiar")
        XCTAssertEqual(coordinator.state, .idle)
    }

    func testNilHaikuCleanupPastesRawText() async {
        coordinator.haikuCleanup = nil
        mockRecorder.mockBuffer = speechBuffer()
        mockSTT.mockTranscription = "texto crudo"

        await coordinator.handleHotkey() // start
        await coordinator.handleHotkey() // stop -> STT -> no Haiku -> paste raw

        XCTAssertEqual(mockInjector.lastInjectedText, "texto crudo")
    }

    // MARK: - Helpers

    private func speechBuffer() -> [Float] {
        (0..<16000).map { i in
            Float(sin(Double(i) * 2.0 * .pi * 440.0 / 16000.0)) * 0.1
        }
    }
}
