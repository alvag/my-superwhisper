import XCTest
@testable import MyWhisper

// MARK: - HaikuCleanupQATests
//
// Comprehensive QA test suite for Haiku hallucination prevention (HAIKU-03).
// Tests the full AppCoordinator pipeline:
//   rawText -> haiku.clean() -> stripHallucinatedSuffix() -> vocabularyService.apply() -> inject
//
// stripHallucinatedSuffix is private — tested exclusively through handleHotkey() pipeline.

@MainActor
final class HaikuCleanupQATests: XCTestCase {
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

    // MARK: - Helpers

    /// Returns a buffer with speech-level RMS (passes VAD gate)
    private func speechBuffer() -> [Float] {
        (0..<16000).map { i in
            Float(sin(Double(i) * 2.0 * .pi * 440.0 / 16000.0)) * 0.1
        }
    }

    /// Runs the full recording pipeline: start hotkey, set mocks, stop hotkey.
    /// Returns the text injected into the text injector.
    @discardableResult
    private func runPipeline(stt: String, haiku: String) async -> String? {
        mockRecorder.mockBuffer = speechBuffer()
        mockSTT.mockTranscription = stt
        mockHaiku.mockCleanedText = haiku

        await coordinator.handleHotkey()  // start recording
        await coordinator.handleHotkey()  // stop -> STT -> Haiku -> strip -> inject

        return mockInjector.lastInjectedText
    }

    // MARK: - Section A: Hallucination Samples
    // 11 tests where raw STT does NOT contain "gracias" but Haiku appends it.
    // Expected: "Gracias" suffix is stripped from the output.

    func testSample01_HallucinatedGraciasStripped() async {
        let result = await runPipeline(
            stt: "hola esto es una prueba",
            haiku: "Hola, esto es una prueba. Gracias"
        )
        XCTAssertEqual(result, "Hola, esto es una prueba",
                       "Hallucinated 'Gracias' must be stripped when absent from STT input")
    }

    func testSample02_HallucinatedGraciasDotStripped() async {
        let result = await runPipeline(
            stt: "necesito que me envies el archivo",
            haiku: "Necesito que me envies el archivo. Gracias."
        )
        XCTAssertEqual(result, "Necesito que me envies el archivo",
                       "Hallucinated 'Gracias.' with trailing period must be stripped")
    }

    func testSample03_HallucinatedGraciasStripped() async {
        let result = await runPipeline(
            stt: "el reporte esta listo para revision",
            haiku: "El reporte esta listo para revision. Gracias"
        )
        XCTAssertEqual(result, "El reporte esta listo para revision",
                       "Hallucinated 'Gracias' must be stripped")
    }

    func testSample04_HallucinatedGraciasDotStripped() async {
        let result = await runPipeline(
            stt: "recuerda comprar leche y pan",
            haiku: "Recuerda comprar leche y pan. Gracias."
        )
        XCTAssertEqual(result, "Recuerda comprar leche y pan",
                       "Hallucinated 'Gracias.' must be stripped")
    }

    func testSample05_HallucinatedGraciasStripped() async {
        let result = await runPipeline(
            stt: "la reunion es a las tres de la tarde",
            haiku: "La reunion es a las tres de la tarde. Gracias"
        )
        XCTAssertEqual(result, "La reunion es a las tres de la tarde",
                       "Hallucinated 'Gracias' must be stripped")
    }

    func testSample06_HallucinatedGraciasDotStripped() async {
        let result = await runPipeline(
            stt: "por favor revisa el documento",
            haiku: "Por favor, revisa el documento. Gracias."
        )
        XCTAssertEqual(result, "Por favor, revisa el documento",
                       "Hallucinated 'Gracias.' must be stripped even after comma in Haiku output")
    }

    func testSample07_HallucinatedGraciasStripped() async {
        let result = await runPipeline(
            stt: "manana tengo una cita con el doctor",
            haiku: "Manana tengo una cita con el doctor. Gracias"
        )
        XCTAssertEqual(result, "Manana tengo una cita con el doctor",
                       "Hallucinated 'Gracias' must be stripped")
    }

    func testSample08_HallucinatedGraciasDotStripped() async {
        let result = await runPipeline(
            stt: "no me funciona el internet",
            haiku: "No me funciona el internet. Gracias."
        )
        XCTAssertEqual(result, "No me funciona el internet",
                       "Hallucinated 'Gracias.' must be stripped")
    }

    func testSample09_HallucinatedGraciasStripped() async {
        let result = await runPipeline(
            stt: "el proyecto debe estar terminado el viernes",
            haiku: "El proyecto debe estar terminado el viernes. Gracias"
        )
        XCTAssertEqual(result, "El proyecto debe estar terminado el viernes",
                       "Hallucinated 'Gracias' must be stripped")
    }

    func testSample10_HallucinatedGraciasDotStripped() async {
        let result = await runPipeline(
            stt: "ya envie el correo con los datos",
            haiku: "Ya envie el correo con los datos. Gracias."
        )
        XCTAssertEqual(result, "Ya envie el correo con los datos",
                       "Hallucinated 'Gracias.' must be stripped")
    }

    func testSample11_HallucinatedGraciasStripped() async {
        let result = await runPipeline(
            stt: "necesito mas tiempo para terminar",
            haiku: "Necesito mas tiempo para terminar. Gracias"
        )
        XCTAssertEqual(result, "Necesito mas tiempo para terminar",
                       "Hallucinated 'Gracias' must be stripped")
    }

    // MARK: - Section B: Legitimate Preservation
    // 4 tests where "gracias" IS in the raw STT input.
    // Expected: "gracias" is preserved verbatim in the output.

    func testLegitimate01_GraciasInInputPreserved() async {
        let result = await runPipeline(
            stt: "dile gracias de mi parte",
            haiku: "Dile gracias de mi parte."
        )
        XCTAssertEqual(result, "Dile gracias de mi parte.",
                       "Legitimate 'gracias' present in STT input must be preserved")
    }

    func testLegitimate02_GraciasAtStartPreserved() async {
        let result = await runPipeline(
            stt: "gracias por tu ayuda con el proyecto",
            haiku: "Gracias por tu ayuda con el proyecto."
        )
        XCTAssertEqual(result, "Gracias por tu ayuda con el proyecto.",
                       "Legitimate 'gracias' at sentence start must be preserved")
    }

    func testLegitimate03_MidSentenceGraciasPreserved() async {
        let result = await runPipeline(
            stt: "le dije muchas gracias por todo",
            haiku: "Le dije muchas gracias por todo."
        )
        XCTAssertEqual(result, "Le dije muchas gracias por todo.",
                       "Mid-sentence 'gracias' must be preserved when present in STT input")
    }

    func testLegitimate04_GraciasAsNounPreserved() async {
        let result = await runPipeline(
            stt: "no le dieron las gracias a nadie",
            haiku: "No le dieron las gracias a nadie."
        )
        XCTAssertEqual(result, "No le dieron las gracias a nadie.",
                       "Noun-form 'gracias' must be preserved when present in STT input")
    }

    // MARK: - Section C: Regression Baseline
    // 6 tests verifying that standard Haiku cleanup behavior is unaffected.
    // These use clean Haiku output (no hallucinated suffix) and verify pass-through.

    func testRegression01_PunctuationPreserved() async {
        let result = await runPipeline(
            stt: "hola como estas",
            haiku: "Hola, como estas?"
        )
        XCTAssertEqual(result, "Hola, como estas?",
                       "Punctuation added by Haiku must be preserved when no hallucinated suffix present")
    }

    func testRegression02_CapitalizationPreserved() async {
        let result = await runPipeline(
            stt: "el lunes voy a madrid",
            haiku: "El lunes voy a Madrid."
        )
        XCTAssertEqual(result, "El lunes voy a Madrid.",
                       "Capitalization corrections by Haiku must be preserved")
    }

    func testRegression03_FillerRemovalPreserved() async {
        let result = await runPipeline(
            stt: "eh pues este yo creo que si",
            haiku: "Yo creo que si."
        )
        XCTAssertEqual(result, "Yo creo que si.",
                       "Filler word removal by Haiku must be preserved")
    }

    func testRegression04_ParagraphBreaksPreserved() async {
        let result = await runPipeline(
            stt: "primer tema es importante segundo tema tambien",
            haiku: "Primer tema es importante.\n\nSegundo tema tambien."
        )
        XCTAssertEqual(result, "Primer tema es importante.\n\nSegundo tema tambien.",
                       "Paragraph breaks inserted by Haiku must be preserved")
    }

    func testRegression05_NoModificationPassThrough() async {
        let result = await runPipeline(
            stt: "el clima esta bien hoy",
            haiku: "El clima esta bien hoy."
        )
        XCTAssertEqual(result, "El clima esta bien hoy.",
                       "Clean Haiku output without hallucinations must pass through unchanged")
    }

    func testRegression06_ExclamationAndQuestionMarksPreserved() async {
        let result = await runPipeline(
            stt: "que hora es no puedo creerlo",
            haiku: "Que hora es? No puedo creerlo!"
        )
        XCTAssertEqual(result, "Que hora es? No puedo creerlo!",
                       "Question and exclamation marks from Haiku must be preserved")
    }

    // MARK: - Section D: Edge Cases

    // Note: testEdge01 for empty STT buffer is SKIPPED intentionally.
    // The VAD gate (AUD-03) blocks empty/silent buffers before STT is called.
    // This is already verified in AppCoordinatorTests.testSilentRecordingDoesNotTranscribe.

    func testEdge01_VeryLongTextStripsHallucination() async {
        // 100+ character STT without gracias, Haiku appends hallucinated Gracias
        let longSTT = "necesito que revises todos los documentos del proyecto antes del viernes proximo porque hay una reunion importante"
        let longHaiku = "Necesito que revises todos los documentos del proyecto antes del viernes proximo porque hay una reunion importante. Gracias"
        let result = await runPipeline(stt: longSTT, haiku: longHaiku)
        let output = result ?? ""
        XCTAssertFalse(output.lowercased().hasSuffix("gracias"),
                       "Hallucinated 'Gracias' must be stripped even from very long text")
        XCTAssertTrue(output.contains("reunion importante"),
                      "Main content must be preserved in very long text")
    }

    func testEdge02_MultiSentenceCleanOutputPassThrough() async {
        // Multiple sentences with correct Haiku output — no stripping needed
        let result = await runPipeline(
            stt: "tengo hambre vamos a comer algo",
            haiku: "Tengo hambre. Vamos a comer algo."
        )
        XCTAssertEqual(result, "Tengo hambre. Vamos a comer algo.",
                       "Multi-sentence Haiku output without hallucinations must pass through unchanged")
    }

    func testEdge03_GraciasMidSentenceInHaikuNotStripped() async {
        // "gracias" appears mid-sentence in Haiku output AND in raw STT
        // The suffix strip should not remove mid-sentence words — only trailing suffixes
        let result = await runPipeline(
            stt: "muchas gracias por todo tu trabajo",
            haiku: "Muchas gracias por todo tu trabajo."
        )
        XCTAssertEqual(result, "Muchas gracias por todo tu trabajo.",
                       "Mid-sentence 'gracias' in Haiku output must not be stripped when present in STT input")
    }
}
