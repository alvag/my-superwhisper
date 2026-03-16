import XCTest
@testable import MyWhisper

// MARK: - MockURLProtocol

final class MockURLProtocol: URLProtocol {
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = MockURLProtocol.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.unknown))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

// MARK: - HaikuCleanupServiceTests

class HaikuCleanupServiceTests: XCTestCase {

    var service: HaikuCleanupService!
    var mockSession: URLSession!

    override func setUp() {
        super.setUp()
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        mockSession = URLSession(configuration: config)
        service = HaikuCleanupService(session: mockSession)
        // Clean up any leftover key
        try? KeychainService.delete()
    }

    override func tearDown() {
        MockURLProtocol.requestHandler = nil
        try? KeychainService.delete()
        service = nil
        mockSession = nil
        super.tearDown()
    }

    // MARK: - Helpers

    private func makeResponse(statusCode: Int) -> HTTPURLResponse {
        HTTPURLResponse(
            url: URL(string: "https://api.anthropic.com/v1/messages")!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: nil
        )!
    }

    private func validResponseData(text: String) -> Data {
        let json = """
        {"content":[{"type":"text","text":"\(text)"}]}
        """
        return Data(json.utf8)
    }

    // MARK: - Tests

    func testCleanReturns200CleanedText() async throws {
        try KeychainService.save("test-key-123")
        MockURLProtocol.requestHandler = { [weak self] _ in
            guard let self else { throw URLError(.unknown) }
            return (self.makeResponse(statusCode: 200), self.validResponseData(text: "Hola mundo."))
        }
        let result = try await service.clean("hola mundo")
        XCTAssertEqual(result, "Hola mundo.")
    }

    func testCleanThrowsAuthFailedOn401() async throws {
        try KeychainService.save("test-key-123")
        MockURLProtocol.requestHandler = { [weak self] _ in
            guard let self else { throw URLError(.unknown) }
            return (self.makeResponse(statusCode: 401), Data())
        }
        do {
            _ = try await service.clean("hola")
            XCTFail("Expected authFailed error")
        } catch HaikuCleanupError.authFailed {
            // expected
        }
    }

    func testCleanThrowsServerErrorOn500() async throws {
        try KeychainService.save("test-key-123")
        MockURLProtocol.requestHandler = { [weak self] _ in
            guard let self else { throw URLError(.unknown) }
            return (self.makeResponse(statusCode: 500), Data())
        }
        do {
            _ = try await service.clean("hola")
            XCTFail("Expected serverError")
        } catch HaikuCleanupError.serverError(let code) {
            XCTAssertEqual(code, 500)
        }
    }

    func testCleanThrowsInvalidResponseOnEmptyContent() async throws {
        try KeychainService.save("test-key-123")
        MockURLProtocol.requestHandler = { [weak self] _ in
            guard let self else { throw URLError(.unknown) }
            let data = Data(#"{"content":[]}"#.utf8)
            return (self.makeResponse(statusCode: 200), data)
        }
        do {
            _ = try await service.clean("hola")
            XCTFail("Expected invalidResponse")
        } catch HaikuCleanupError.invalidResponse {
            // expected
        }
    }

    func testCleanThrowsNoAPIKeyWhenNotConfigured() async {
        // No key saved (cleared in setUp)
        do {
            _ = try await service.clean("hola")
            XCTFail("Expected noAPIKey error")
        } catch HaikuCleanupError.noAPIKey {
            // expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testHasAPIKeyReturnsTrueWhenKeyExists() async throws {
        try KeychainService.save("test-key-123")
        let result = await service.hasAPIKey
        XCTAssertTrue(result)
    }

    func testHasAPIKeyReturnsFalseWhenNoKey() async {
        let result = await service.hasAPIKey
        XCTAssertFalse(result)
    }

    func testRequestBodyContainsModelAndSystemPrompt() async throws {
        try KeychainService.save("test-key-123")
        var capturedRequest: URLRequest?

        MockURLProtocol.requestHandler = { [weak self] request in
            guard let self else { throw URLError(.unknown) }
            capturedRequest = request
            return (self.makeResponse(statusCode: 200), self.validResponseData(text: "Resultado."))
        }

        let rawText = "hola esto es una prueba"
        _ = try await service.clean(rawText)

        guard let req = capturedRequest, let body = req.httpBody else {
            XCTFail("No request captured")
            return
        }

        let json = try JSONSerialization.jsonObject(with: body) as! [String: Any]

        // PRV-02: only text sent, not audio
        XCTAssertEqual(json["model"] as? String, "claude-haiku-4-5-20251001")

        let systemPrompt = json["system"] as? String
        XCTAssertNotNil(systemPrompt)
        XCTAssertTrue(systemPrompt?.contains("corrector de texto") == true,
                      "System prompt must contain 'corrector de texto'")

        let messages = json["messages"] as? [[String: Any]]
        XCTAssertEqual(messages?.first?["content"] as? String, rawText,
                       "Message content must be exactly the raw text (PRV-02)")
    }

    func testSaveAPIKeyValidatesBeforeSaving() async throws {
        MockURLProtocol.requestHandler = { [weak self] _ in
            guard let self else { throw URLError(.unknown) }
            return (self.makeResponse(statusCode: 200), self.validResponseData(text: "ok"))
        }
        try await service.saveAPIKey("valid-key")
        XCTAssertNotNil(KeychainService.load(), "Key should be saved after successful validation")
    }

    func testSaveAPIKeyDoesNotSaveOnAuthFailure() async throws {
        MockURLProtocol.requestHandler = { [weak self] _ in
            guard let self else { throw URLError(.unknown) }
            return (self.makeResponse(statusCode: 401), Data())
        }
        do {
            try await service.saveAPIKey("invalid-key")
            XCTFail("Expected authFailed error")
        } catch HaikuCleanupError.authFailed {
            XCTAssertNil(KeychainService.load(), "Key must NOT be saved on auth failure")
        }
    }
}
