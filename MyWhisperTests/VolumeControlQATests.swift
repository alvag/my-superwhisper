import XCTest
@testable import MyWhisper

// MARK: - Volume Control QA Tests
// Comprehensive exit-path validation for mic volume control.
// Verifies that restore() fires on EVERY recording exit path and that
// maximize/restore ordering is correct. Mocks are reused from AppCoordinatorTests.swift.

@MainActor
final class VolumeControlQATests: XCTestCase {
    var coordinator: AppCoordinator!
    var mockRecorder: MockAudioRecorder!
    var mockSTT: MockSTTEngine!
    var mockOverlay: MockOverlayController!
    var mockInjector: MockTextInjector!
    var mockHaiku: MockHaikuCleanup!
    var mockMedia: MockMediaPlaybackService!
    var mockVolume: MockMicInputVolumeService!

    override func setUp() {
        super.setUp()
        coordinator = AppCoordinator()
        mockRecorder = MockAudioRecorder()
        mockSTT = MockSTTEngine()
        mockOverlay = MockOverlayController()
        mockInjector = MockTextInjector()
        mockHaiku = MockHaikuCleanup()
        mockMedia = MockMediaPlaybackService()
        mockVolume = MockMicInputVolumeService()

        coordinator.audioRecorder = mockRecorder
        coordinator.sttEngine = mockSTT
        coordinator.overlayController = mockOverlay
        coordinator.textInjector = mockInjector
        coordinator.haikuCleanup = mockHaiku
        coordinator.mediaPlayback = mockMedia
        coordinator.micVolumeService = mockVolume
    }

    // MARK: - Section A: Exit Path Coverage

    /// Normal stop (happy path): start recording, then stop with speech buffer.
    /// Restore must fire exactly once and state returns to idle.
    func testExitPath01_NormalStop_RestoreFires() async {
        mockRecorder.mockBuffer = speechBuffer()
        mockSTT.mockTranscription = "hola prueba"
        mockHaiku.mockCleanedText = "Hola prueba."

        await coordinator.handleHotkey() // start
        XCTAssertEqual(mockVolume.maximizeAndSaveCallCount, 1)
        XCTAssertEqual(mockVolume.restoreCallCount, 0)

        await coordinator.handleHotkey() // stop -> transcribe -> cleanup -> paste

        XCTAssertEqual(mockVolume.maximizeAndSaveCallCount, 1)
        XCTAssertEqual(mockVolume.restoreCallCount, 1, "Restore must fire on normal stop")
        XCTAssertEqual(coordinator.state, .idle)
    }

    /// Escape cancel: start recording, then press Escape.
    /// Restore must fire exactly once and state returns to idle.
    func testExitPath02_EscapeCancel_RestoreFires() async {
        await coordinator.handleHotkey() // start
        XCTAssertEqual(coordinator.state, .recording)
        XCTAssertEqual(mockVolume.maximizeAndSaveCallCount, 1)

        coordinator.handleEscape()

        XCTAssertEqual(mockVolume.maximizeAndSaveCallCount, 1)
        XCTAssertEqual(mockVolume.restoreCallCount, 1, "Restore must fire on Escape cancel")
        XCTAssertEqual(coordinator.state, .idle)
    }

    /// VAD silence gate: start recording with silent buffer, stop.
    /// Restore must fire even though STT is never called.
    func testExitPath03_VADSilenceGate_RestoreFires() async {
        mockRecorder.mockBuffer = [Float](repeating: 0.0, count: 16000) // silence

        await coordinator.handleHotkey() // start
        XCTAssertEqual(mockVolume.maximizeAndSaveCallCount, 1)

        await coordinator.handleHotkey() // stop -> VAD rejects -> early return

        XCTAssertEqual(mockVolume.maximizeAndSaveCallCount, 1)
        XCTAssertEqual(mockVolume.restoreCallCount, 1, "Restore must fire even when VAD detects silence")
        XCTAssertEqual(coordinator.state, .idle)
        XCTAssertFalse(mockSTT.transcribeCalled, "STT must NOT be called when VAD gates silence")
    }

    /// STT transcription error: start recording, STT throws during transcription.
    /// Restore must fire and state returns to idle.
    func testExitPath04_STTTranscriptionError_RestoreFires() async {
        mockRecorder.mockBuffer = speechBuffer()
        mockSTT.shouldThrow = true

        await coordinator.handleHotkey() // start
        XCTAssertEqual(mockVolume.maximizeAndSaveCallCount, 1)

        await coordinator.handleHotkey() // stop -> STT throws

        XCTAssertEqual(mockVolume.maximizeAndSaveCallCount, 1)
        XCTAssertEqual(mockVolume.restoreCallCount, 1, "Restore must fire when STT throws")
        XCTAssertEqual(coordinator.state, .idle)
    }

    /// Haiku cleanup error (authFailed): start recording, Haiku throws .authFailed.
    /// Restore must fire; raw text is injected as fallback.
    func testExitPath05_HaikuAuthError_RestoreFires() async {
        mockRecorder.mockBuffer = speechBuffer()
        mockSTT.mockTranscription = "texto sin limpiar"
        mockHaiku.shouldThrow = .authFailed

        await coordinator.handleHotkey() // start
        XCTAssertEqual(mockVolume.maximizeAndSaveCallCount, 1)

        await coordinator.handleHotkey() // stop -> STT -> Haiku fails -> paste raw

        XCTAssertEqual(mockVolume.maximizeAndSaveCallCount, 1)
        XCTAssertEqual(mockVolume.restoreCallCount, 1, "Restore must fire when Haiku throws authFailed")
        XCTAssertEqual(mockInjector.lastInjectedText, "texto sin limpiar", "Raw text injected as fallback")
        XCTAssertEqual(coordinator.state, .idle)
    }

    /// Audio start failure: recorder throws on start().
    /// Maximize fires first, then restore fires immediately after the failure.
    func testExitPath06_AudioStartFailure_RestoreFires() async {
        mockRecorder.shouldThrowOnStart = true

        await coordinator.handleHotkey() // start fails

        XCTAssertEqual(mockVolume.maximizeAndSaveCallCount, 1, "Maximize must be called before start attempt")
        XCTAssertEqual(mockVolume.restoreCallCount, 1, "Restore must fire when audio start fails")
        XCTAssertEqual(coordinator.state, .error("microphone"))
    }

    // MARK: - Section B: Ordering Verification

    /// Maximize fires before recording state is entered.
    /// After handleHotkey() in .idle, maximize == 1 and state == .recording.
    func testOrder01_MaximizeBeforeRecordingStart() async {
        await coordinator.handleHotkey() // idle -> recording

        XCTAssertEqual(mockVolume.maximizeAndSaveCallCount, 1,
                       "Maximize must be called during transition to recording")
        XCTAssertEqual(mockVolume.restoreCallCount, 0,
                       "Restore must NOT be called when recording starts successfully")
        XCTAssertEqual(coordinator.state, .recording)
    }

    /// Cumulative counts over two recording cycles must match exactly.
    /// After cycle 1: maximize == 1, restore == 1. After cycle 2: maximize == 2, restore == 2.
    func testOrder02_RestoreCalledOncePerRecordingCycle() async {
        // Cycle 1
        mockRecorder.mockBuffer = speechBuffer()
        mockSTT.mockTranscription = "ciclo uno"
        mockHaiku.mockCleanedText = "Ciclo uno."

        await coordinator.handleHotkey() // start
        await coordinator.handleHotkey() // stop

        XCTAssertEqual(mockVolume.maximizeAndSaveCallCount, 1, "After first cycle: maximize == 1")
        XCTAssertEqual(mockVolume.restoreCallCount, 1, "After first cycle: restore == 1")

        // Cycle 2
        mockSTT.mockTranscription = "ciclo dos"
        mockHaiku.mockCleanedText = "Ciclo dos."

        await coordinator.handleHotkey() // start again
        await coordinator.handleHotkey() // stop again

        XCTAssertEqual(mockVolume.maximizeAndSaveCallCount, 2, "After second cycle: maximize == 2")
        XCTAssertEqual(mockVolume.restoreCallCount, 2, "After second cycle: restore == 2")
    }

    /// No restore without prior maximize: pressing hotkey while in .processing state is a no-op.
    func testOrder03_NoRestoreWithoutPriorMaximize() async {
        coordinator.state = .processing

        await coordinator.handleHotkey() // ignored in .processing

        XCTAssertEqual(mockVolume.maximizeAndSaveCallCount, 0,
                       "Maximize must NOT be called when hotkey is ignored in .processing state")
        XCTAssertEqual(mockVolume.restoreCallCount, 0,
                       "Restore must NOT be called without prior maximize")
        XCTAssertEqual(coordinator.state, .processing)
    }

    // MARK: - Section C: Service Delegation

    /// Toggle off: coordinator still calls maximize and restore unconditionally.
    /// The isEnabled guard lives inside MicInputVolumeService, not AppCoordinator.
    func testDelegation01_ToggleOffStillCallsService() async {
        mockVolume.isEnabled = false
        mockRecorder.mockBuffer = speechBuffer()
        mockSTT.mockTranscription = "prueba"
        mockHaiku.mockCleanedText = "Prueba."

        await coordinator.handleHotkey() // start
        await coordinator.handleHotkey() // stop

        XCTAssertEqual(mockVolume.maximizeAndSaveCallCount, 1,
                       "Coordinator always calls maximize; guard is inside service")
        XCTAssertEqual(mockVolume.restoreCallCount, 1,
                       "Coordinator always calls restore; guard is inside service")
    }

    /// Nil volume service — no crash on normal start/stop path.
    func testDelegation02_NilService_NoCrashOnNormalPath() async {
        coordinator.micVolumeService = nil
        mockRecorder.mockBuffer = speechBuffer()
        mockSTT.mockTranscription = "prueba"
        mockHaiku.mockCleanedText = "Prueba."

        await coordinator.handleHotkey() // start
        await coordinator.handleHotkey() // stop

        XCTAssertEqual(coordinator.state, .idle, "Coordinator completes normally with nil volume service")
    }

    /// Nil volume service — no crash when recording is cancelled via Escape.
    func testDelegation03_NilService_NoCrashOnEscape() async {
        coordinator.micVolumeService = nil

        await coordinator.handleHotkey() // start
        XCTAssertEqual(coordinator.state, .recording)

        coordinator.handleEscape()

        XCTAssertEqual(coordinator.state, .idle, "Escape cancel completes normally with nil volume service")
    }

    // MARK: - Section D: Haiku Error Exit Paths

    /// Haiku network error (timedOut): restore must fire and raw text is injected.
    func testHaikuError01_NetworkError_RestoreFires() async {
        mockRecorder.mockBuffer = speechBuffer()
        mockSTT.mockTranscription = "texto de red"
        mockHaiku.shouldThrow = .networkError(URLError(.timedOut))

        await coordinator.handleHotkey() // start
        await coordinator.handleHotkey() // stop -> STT -> Haiku network error -> paste raw

        XCTAssertEqual(mockVolume.maximizeAndSaveCallCount, 1)
        XCTAssertEqual(mockVolume.restoreCallCount, 1, "Restore must fire on Haiku network error")
        XCTAssertEqual(mockInjector.lastInjectedText, "texto de red", "Raw text injected on network error")
        XCTAssertEqual(coordinator.state, .idle)
    }

    /// Haiku server error (500): restore must fire and raw text is injected.
    func testHaikuError02_ServerError_RestoreFires() async {
        mockRecorder.mockBuffer = speechBuffer()
        mockSTT.mockTranscription = "texto servidor"
        mockHaiku.shouldThrow = .serverError(500)

        await coordinator.handleHotkey() // start
        await coordinator.handleHotkey() // stop -> STT -> Haiku server error -> paste raw

        XCTAssertEqual(mockVolume.maximizeAndSaveCallCount, 1)
        XCTAssertEqual(mockVolume.restoreCallCount, 1, "Restore must fire on Haiku server error")
        XCTAssertEqual(mockInjector.lastInjectedText, "texto servidor", "Raw text injected on server error")
        XCTAssertEqual(coordinator.state, .idle)
    }

    /// Haiku noAPIKey error: restore must fire and raw text is injected.
    func testHaikuError03_NoAPIKey_RestoreFires() async {
        mockRecorder.mockBuffer = speechBuffer()
        mockSTT.mockTranscription = "texto sin clave"
        mockHaiku.shouldThrow = .noAPIKey

        await coordinator.handleHotkey() // start
        await coordinator.handleHotkey() // stop -> STT -> Haiku noAPIKey error -> paste raw

        XCTAssertEqual(mockVolume.maximizeAndSaveCallCount, 1)
        XCTAssertEqual(mockVolume.restoreCallCount, 1, "Restore must fire when Haiku throws noAPIKey")
        XCTAssertEqual(mockInjector.lastInjectedText, "texto sin clave", "Raw text injected when no API key")
        XCTAssertEqual(coordinator.state, .idle)
    }

    // MARK: - Helpers

    private func speechBuffer() -> [Float] {
        (0..<16000).map { i in
            Float(sin(Double(i) * 2.0 * .pi * 440.0 / 16000.0)) * 0.1
        }
    }
}
