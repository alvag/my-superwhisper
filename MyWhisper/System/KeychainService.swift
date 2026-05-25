import Security
import Foundation

struct KeychainConfiguration: Sendable, Equatable {
    let service: String
    let account: String

    static let production = KeychainConfiguration(
        service: "com.mywhisper.anthropic-api-key",
        account: "anthropic"
    )
}

enum KeychainError: Error {
    case saveFailed(OSStatus)
    case deleteFailed(OSStatus)
}

enum KeychainService {
    static func save(_ key: String, configuration: KeychainConfiguration = .production) throws {
        let data = Data(key.utf8)
        let query = baseQuery(configuration: configuration)
        let attributes: [CFString: Any] = [
            kSecValueData: data
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess {
            return
        }
        guard updateStatus == errSecItemNotFound else {
            throw KeychainError.saveFailed(updateStatus)
        }

        var addQuery = query
        addQuery[kSecValueData] = data
        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        guard addStatus == errSecSuccess else { throw KeychainError.saveFailed(addStatus) }
    }

    static func load(configuration: KeychainConfiguration = .production) -> String? {
        var query = baseQuery(configuration: configuration)
        query[kSecReturnData] = true
        query[kSecMatchLimit] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete(configuration: KeychainConfiguration = .production) throws {
        let query = baseQuery(configuration: configuration)
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status)
        }
    }

    private static func baseQuery(configuration: KeychainConfiguration) -> [CFString: Any] {
        [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: configuration.service,
            kSecAttrAccount: configuration.account
        ]
    }
}
