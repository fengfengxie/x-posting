import CryptoKit
import Foundation

public struct OAuthAuthorizationRequest: Sendable {
    public let url: URL
    public let state: String
    public let codeVerifier: String

    public init(url: URL, state: String, codeVerifier: String) {
        self.url = url
        self.state = state
        self.codeVerifier = codeVerifier
    }
}

public actor XAuthService {
    private let httpClient: HTTPClient
    private let configurationProvider: @Sendable () async -> OAuthConfiguration
    private let credentialStore: SecureCredentialStore
    private let tokenKey = "x.oauth.token"

    public init(
        httpClient: HTTPClient = URLSession.shared,
        configurationProvider: @escaping @Sendable () async -> OAuthConfiguration,
        credentialStore: SecureCredentialStore
    ) {
        self.httpClient = httpClient
        self.configurationProvider = configurationProvider
        self.credentialStore = credentialStore
    }

    public func createAuthorizationRequest() async throws -> OAuthAuthorizationRequest {
        let configuration = await configurationProvider()
        guard !configuration.clientID.isEmpty else {
            throw XPostingError.missingConfiguration("X client ID is missing.")
        }

        let codeVerifier = Self.randomURLSafe(length: 64)
        let codeChallenge = Self.codeChallenge(for: codeVerifier)
        let state = Self.randomURLSafe(length: 24)

        var components = URLComponents(url: configuration.authorizeEndpoint, resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "client_id", value: configuration.clientID),
            URLQueryItem(name: "redirect_uri", value: configuration.redirectURI),
            URLQueryItem(name: "scope", value: configuration.scopes.joined(separator: " ")),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "code_challenge", value: codeChallenge),
            URLQueryItem(name: "code_challenge_method", value: "S256")
        ]

        guard let url = components?.url else {
            throw XPostingError.service("Unable to build OAuth authorization URL.")
        }

        return OAuthAuthorizationRequest(url: url, state: state, codeVerifier: codeVerifier)
    }

    public func exchangeCode(from callbackURL: URL, expectedState: String, codeVerifier: String) async throws -> OAuthToken {
        let configuration = await configurationProvider()
        guard let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false) else {
            throw XPostingError.service("Invalid callback URL.")
        }

        let state = components.queryItems?.first(where: { $0.name == "state" })?.value
        if state != expectedState {
            throw XPostingError.oauthStateMismatch
        }

        guard let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
            throw XPostingError.service("OAuth callback did not include an authorization code.")
        }

        var request = URLRequest(url: configuration.tokenEndpoint)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body = [
            URLQueryItem(name: "grant_type", value: "authorization_code"),
            URLQueryItem(name: "code", value: code),
            URLQueryItem(name: "client_id", value: configuration.clientID),
            URLQueryItem(name: "redirect_uri", value: configuration.redirectURI),
            URLQueryItem(name: "code_verifier", value: codeVerifier)
        ]
        .map { "\($0.name)=\(($0.value ?? "").addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }
        .joined(separator: "&")
        request.httpBody = body.data(using: .utf8)

        let (data, response) = try await httpClient.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw XPostingError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Unknown OAuth error"
            throw XPostingError.service("OAuth token exchange failed (\(httpResponse.statusCode)): \(message)")
        }

        let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
        let token = OAuthToken(
            accessToken: tokenResponse.accessToken,
            refreshToken: tokenResponse.refreshToken,
            expiresIn: tokenResponse.expiresIn,
            tokenType: tokenResponse.tokenType,
            acquiredAt: Date()
        )
        try saveToken(token)
        return token
    }

    public func loadToken() throws -> OAuthToken? {
        guard let data = try credentialStore.get(for: tokenKey) else {
            return nil
        }
        return try JSONDecoder().decode(OAuthToken.self, from: data)
    }

    public func saveToken(_ token: OAuthToken) throws {
        let data = try JSONEncoder().encode(token)
        try credentialStore.set(data, for: tokenKey)
    }

    public func clearToken() throws {
        try credentialStore.remove(for: tokenKey)
    }

    public static func codeChallenge(for verifier: String) -> String {
        let digest = SHA256.hash(data: Data(verifier.utf8))
        return Data(digest).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private static func randomURLSafe(length: Int) -> String {
        let chars = Array("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~")
        return String((0..<length).map { _ in chars.randomElement()! })
    }
}

private struct TokenResponse: Decodable {
    let tokenType: String
    let expiresIn: Int
    let accessToken: String
    let refreshToken: String?

    enum CodingKeys: String, CodingKey {
        case tokenType = "token_type"
        case expiresIn = "expires_in"
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
    }
}
