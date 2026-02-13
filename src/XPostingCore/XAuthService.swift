import Foundation

public actor XCredentialService {
    private let credentialStore: SecureCredentialStore
    private let credentialKey = "x.oauth1.credentials"

    public init(credentialStore: SecureCredentialStore) {
        self.credentialStore = credentialStore
    }

    public func save(_ credentials: XCredentials) throws {
        let data = try JSONEncoder().encode(credentials)
        try credentialStore.set(data, for: credentialKey)
    }

    public func load() throws -> XCredentials? {
        guard let data = try credentialStore.get(for: credentialKey) else {
            return nil
        }
        return try JSONDecoder().decode(XCredentials.self, from: data)
    }

    public func clear() throws {
        try credentialStore.remove(for: credentialKey)
    }
}
