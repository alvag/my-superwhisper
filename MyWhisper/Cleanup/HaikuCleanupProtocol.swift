protocol HaikuCleanupProtocol: AnyObject, Sendable {
    /// Clean raw transcription text. Returns cleaned text, or throws HaikuCleanupError.
    func clean(_ rawText: String) async throws -> String
    /// Whether a valid API key is stored in Keychain.
    var hasAPIKey: Bool { get async }
    /// Save a new API key (validates first, then stores in Keychain).
    func saveAPIKey(_ key: String) async throws
    /// Validate the currently stored API key with a lightweight request.
    func validateStoredAPIKey() async throws
    /// Remove the stored API key from Keychain.
    func removeAPIKey() async throws
}
