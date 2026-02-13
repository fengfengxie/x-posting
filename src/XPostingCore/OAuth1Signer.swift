import CryptoKit
import Foundation

public struct OAuth1Signer: Sendable {
    private let credentials: XCredentials
    private let timestampProvider: @Sendable () -> String
    private let nonceProvider: @Sendable () -> String

    public init(credentials: XCredentials) {
        self.credentials = credentials
        self.timestampProvider = { String(Int(Date().timeIntervalSince1970)) }
        self.nonceProvider = { UUID().uuidString.replacingOccurrences(of: "-", with: "") }
    }

    init(credentials: XCredentials, timestamp: String, nonce: String) {
        self.credentials = credentials
        self.timestampProvider = { timestamp }
        self.nonceProvider = { nonce }
    }

    public func sign(_ request: URLRequest) -> URLRequest {
        var signed = request
        let method = (request.httpMethod ?? "GET").uppercased()

        guard let url = request.url, let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return signed
        }

        let baseURL = "\(url.scheme ?? "https")://\(url.host ?? "")\(url.path)"

        let timestamp = timestampProvider()
        let nonce = nonceProvider()

        var oauthParams: [(String, String)] = [
            ("oauth_consumer_key", credentials.apiKey),
            ("oauth_nonce", nonce),
            ("oauth_signature_method", "HMAC-SHA1"),
            ("oauth_timestamp", timestamp),
            ("oauth_token", credentials.accessToken),
            ("oauth_version", "1.0"),
        ]

        var allParams = oauthParams
        if let queryItems = components.queryItems {
            for item in queryItems {
                allParams.append((item.name, item.value ?? ""))
            }
        }

        allParams.sort { ($0.0, $0.1) < ($1.0, $1.1) }

        let paramString = allParams
            .map { "\(percentEncode($0.0))=\(percentEncode($0.1))" }
            .joined(separator: "&")

        let baseString = "\(method)&\(percentEncode(baseURL))&\(percentEncode(paramString))"
        let signingKey = "\(percentEncode(credentials.apiKeySecret))&\(percentEncode(credentials.accessTokenSecret))"

        let signature = hmacSHA1(key: signingKey, message: baseString)
        oauthParams.append(("oauth_signature", signature))

        let header = "OAuth " + oauthParams
            .sorted { $0.0 < $1.0 }
            .map { "\(percentEncode($0.0))=\"\(percentEncode($0.1))\"" }
            .joined(separator: ", ")

        signed.setValue(header, forHTTPHeaderField: "Authorization")
        return signed
    }

    private func percentEncode(_ string: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(.init(charactersIn: "-._~"))
        return string.addingPercentEncoding(withAllowedCharacters: allowed) ?? string
    }

    private func hmacSHA1(key: String, message: String) -> String {
        let keyData = SymmetricKey(data: Data(key.utf8))
        let mac = HMAC<Insecure.SHA1>.authenticationCode(for: Data(message.utf8), using: keyData)
        return Data(mac).base64EncodedString()
    }
}
