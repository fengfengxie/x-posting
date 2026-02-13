import Foundation
import Security

public protocol SecureCredentialStore: Sendable {
    func set(_ value: Data, for key: String) throws
    func get(for key: String) throws -> Data?
    func remove(for key: String) throws
}

public extension SecureCredentialStore {
    func setString(_ value: String, for key: String) throws {
        guard let data = value.data(using: .utf8) else {
            throw XPostingError.service("Failed to encode credential for key \(key)")
        }
        try set(data, for: key)
    }

    func getString(for key: String) throws -> String? {
        guard let data = try get(for: key) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

public struct KeychainCredentialStore: SecureCredentialStore {
    private let service: String

    public init(service: String = "com.xposting.credentials") {
        self.service = service
    }

    public func set(_ value: Data, for key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]

        let update: [String: Any] = [kSecValueData as String: value]
        let status = SecItemUpdate(query as CFDictionary, update as CFDictionary)

        if status == errSecItemNotFound {
            var insert = query
            insert[kSecValueData as String] = value
            let addStatus = SecItemAdd(insert as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw XPostingError.service("Unable to save keychain item \(key) (status \(addStatus)).")
            }
            return
        }

        guard status == errSecSuccess else {
            throw XPostingError.service("Unable to update keychain item \(key) (status \(status)).")
        }
    }

    public func get(for key: String) throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess else {
            throw XPostingError.service("Unable to read keychain item \(key) (status \(status)).")
        }

        return result as? Data
    }

    public func remove(for key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw XPostingError.service("Unable to delete keychain item \(key) (status \(status)).")
        }
    }
}
