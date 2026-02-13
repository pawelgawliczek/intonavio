import Foundation
import Security

/// Manages JWT tokens in the iOS Keychain via the Security framework.
/// All operations are synchronous and thread-safe (Keychain is thread-safe).
final class TokenManager: Sendable {
    static let shared = TokenManager()

    private let service = "com.intonavio.app"
    private let accessTokenKey = "accessToken"
    private let refreshTokenKey = "refreshToken"

    private init() {}

    // MARK: - Public API

    var hasValidTokens: Bool {
        accessToken != nil && refreshToken != nil
    }

    var accessToken: String? {
        read(key: accessTokenKey)
    }

    var refreshToken: String? {
        read(key: refreshTokenKey)
    }

    func storeTokens(access: String, refresh: String) {
        write(key: accessTokenKey, value: access)
        write(key: refreshTokenKey, value: refresh)
    }

    func clearTokens() {
        delete(key: accessTokenKey)
        delete(key: refreshTokenKey)
    }
}

// MARK: - Keychain Operations

private extension TokenManager {
    func read(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }
        return value
    }

    func write(key: String, value: String) {
        delete(key: key)

        guard let data = value.data(using: .utf8) else { return }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            AppLogger.auth.error("Keychain write failed for \(key): \(status)")
        }
    }

    func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}
