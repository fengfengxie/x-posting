import XCTest
@testable import XPostingCore

final class OAuth1SignerTests: XCTestCase {
    func testSignedRequestContainsAuthorizationHeader() {
        let creds = XCredentials(
            apiKey: "testConsumerKey",
            apiKeySecret: "testConsumerSecret",
            accessToken: "testAccessToken",
            accessTokenSecret: "testAccessTokenSecret"
        )
        let signer = OAuth1Signer(credentials: creds, timestamp: "1234567890", nonce: "testnonce123")

        var request = URLRequest(url: URL(string: "https://api.twitter.com/2/tweets")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let signed = signer.sign(request)
        let authHeader = signed.value(forHTTPHeaderField: "Authorization")

        XCTAssertNotNil(authHeader)
        XCTAssertTrue(authHeader!.hasPrefix("OAuth "))
        XCTAssertTrue(authHeader!.contains("oauth_consumer_key=\"testConsumerKey\""))
        XCTAssertTrue(authHeader!.contains("oauth_token=\"testAccessToken\""))
        XCTAssertTrue(authHeader!.contains("oauth_signature_method=\"HMAC-SHA1\""))
        XCTAssertTrue(authHeader!.contains("oauth_timestamp=\"1234567890\""))
        XCTAssertTrue(authHeader!.contains("oauth_nonce=\"testnonce123\""))
        XCTAssertTrue(authHeader!.contains("oauth_version=\"1.0\""))
        XCTAssertTrue(authHeader!.contains("oauth_signature="))
    }

    func testSignatureIsDeterministic() {
        let creds = XCredentials(
            apiKey: "key",
            apiKeySecret: "secret",
            accessToken: "token",
            accessTokenSecret: "tokenSecret"
        )
        let signer = OAuth1Signer(credentials: creds, timestamp: "1000000000", nonce: "fixednonce")

        var request = URLRequest(url: URL(string: "https://api.twitter.com/2/tweets")!)
        request.httpMethod = "POST"

        let signed1 = signer.sign(request)
        let signed2 = signer.sign(request)

        XCTAssertEqual(
            signed1.value(forHTTPHeaderField: "Authorization"),
            signed2.value(forHTTPHeaderField: "Authorization")
        )
    }

    func testQueryParamsIncludedInSignature() {
        let creds = XCredentials(
            apiKey: "key",
            apiKeySecret: "secret",
            accessToken: "token",
            accessTokenSecret: "tokenSecret"
        )
        let signer = OAuth1Signer(credentials: creds, timestamp: "1000000000", nonce: "fixednonce")

        var withQuery = URLRequest(url: URL(string: "https://api.twitter.com/1.1/statuses?count=10")!)
        withQuery.httpMethod = "GET"

        var withoutQuery = URLRequest(url: URL(string: "https://api.twitter.com/1.1/statuses")!)
        withoutQuery.httpMethod = "GET"

        let signedWith = signer.sign(withQuery)
        let signedWithout = signer.sign(withoutQuery)

        XCTAssertNotEqual(
            signedWith.value(forHTTPHeaderField: "Authorization"),
            signedWithout.value(forHTTPHeaderField: "Authorization")
        )
    }
}

final class XCredentialServiceTests: XCTestCase {
    func testSaveAndLoadRoundTrip() async throws {
        let store = InMemoryCredentialStore()
        let service = XCredentialService(credentialStore: store)

        let creds = XCredentials(
            apiKey: "ak",
            apiKeySecret: "aks",
            accessToken: "at",
            accessTokenSecret: "ats"
        )
        try await service.save(creds)

        let loaded = try await service.load()
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.apiKey, "ak")
        XCTAssertEqual(loaded?.apiKeySecret, "aks")
        XCTAssertEqual(loaded?.accessToken, "at")
        XCTAssertEqual(loaded?.accessTokenSecret, "ats")
    }

    func testLoadReturnsNilWhenEmpty() async throws {
        let store = InMemoryCredentialStore()
        let service = XCredentialService(credentialStore: store)

        let loaded = try await service.load()
        XCTAssertNil(loaded)
    }

    func testClearRemovesCredentials() async throws {
        let store = InMemoryCredentialStore()
        let service = XCredentialService(credentialStore: store)

        let creds = XCredentials(apiKey: "a", apiKeySecret: "b", accessToken: "c", accessTokenSecret: "d")
        try await service.save(creds)
        try await service.clear()

        let loaded = try await service.load()
        XCTAssertNil(loaded)
    }
}

private final class InMemoryCredentialStore: SecureCredentialStore, @unchecked Sendable {
    private var storage: [String: Data] = [:]

    func set(_ value: Data, for key: String) throws {
        storage[key] = value
    }

    func get(for key: String) throws -> Data? {
        storage[key]
    }

    func remove(for key: String) throws {
        storage.removeValue(forKey: key)
    }
}
