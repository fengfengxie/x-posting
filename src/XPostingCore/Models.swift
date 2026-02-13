import Foundation

public enum PolishPreset: String, Codable, CaseIterable, Sendable {
    case concise
    case professional
    case casual
}

public enum TargetOutputLanguage: String, Codable, CaseIterable, Sendable {
    case auto
    case en
    case cn

    public var displayName: String {
        switch self {
        case .auto: return "Auto"
        case .en: return "English"
        case .cn: return "Chinese"
        }
    }
}

public struct Draft: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var text: String
    public var imagePath: String?
    public let createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        text: String = "",
        imagePath: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.text = text
        self.imagePath = imagePath
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct AppSettings: Codable, Sendable {
    public var deepSeekBaseURL: URL
    public var deepSeekModel: String
    public var deepSeekAPIKey: String
    public var defaultPreset: PolishPreset
    public var defaultOutputLanguage: TargetOutputLanguage
    public var xClientID: String
    public var xRedirectURI: String

    public init(
        deepSeekBaseURL: URL = URL(string: "https://api.deepseek.com")!,
        deepSeekModel: String = "deepseek-chat",
        deepSeekAPIKey: String = "",
        defaultPreset: PolishPreset = .concise,
        defaultOutputLanguage: TargetOutputLanguage = .auto,
        xClientID: String = "",
        xRedirectURI: String = "xposting://oauth/callback"
    ) {
        self.deepSeekBaseURL = deepSeekBaseURL
        self.deepSeekModel = deepSeekModel
        self.deepSeekAPIKey = deepSeekAPIKey
        self.defaultPreset = defaultPreset
        self.defaultOutputLanguage = defaultOutputLanguage
        self.xClientID = xClientID
        self.xRedirectURI = xRedirectURI
    }
}

public struct PolishRequest: Sendable {
    public let originalText: String
    public let preset: PolishPreset
    public let outputLanguage: TargetOutputLanguage

    public init(originalText: String, preset: PolishPreset, outputLanguage: TargetOutputLanguage) {
        self.originalText = originalText
        self.preset = preset
        self.outputLanguage = outputLanguage
    }
}

public struct PolishResponse: Sendable {
    public let polishedText: String
    public let estimatedPostCount: Int

    public init(polishedText: String, estimatedPostCount: Int) {
        self.polishedText = polishedText
        self.estimatedPostCount = estimatedPostCount
    }
}

public struct PostSegment: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let index: Int
    public let text: String
    public let weightedCharacterCount: Int

    public init(index: Int, text: String, weightedCharacterCount: Int) {
        self.id = UUID()
        self.index = index
        self.text = text
        self.weightedCharacterCount = weightedCharacterCount
    }
}

public struct PublishPlan: Sendable {
    public let segments: [PostSegment]
    public let imageData: Data?

    public init(segments: [PostSegment], imageData: Data? = nil) {
        self.segments = segments
        self.imageData = imageData
    }
}

public struct PublishResult: Sendable {
    public let success: Bool
    public let postIDs: [String]
    public let errorMessage: String?

    public init(success: Bool, postIDs: [String] = [], errorMessage: String? = nil) {
        self.success = success
        self.postIDs = postIDs
        self.errorMessage = errorMessage
    }
}

public struct OAuthConfiguration: Sendable {
    public let clientID: String
    public let redirectURI: String
    public let scopes: [String]
    public let authorizeEndpoint: URL
    public let tokenEndpoint: URL

    public init(
        clientID: String,
        redirectURI: String,
        scopes: [String] = ["tweet.read", "tweet.write", "users.read", "offline.access"],
        authorizeEndpoint: URL = URL(string: "https://twitter.com/i/oauth2/authorize")!,
        tokenEndpoint: URL = URL(string: "https://api.twitter.com/2/oauth2/token")!
    ) {
        self.clientID = clientID
        self.redirectURI = redirectURI
        self.scopes = scopes
        self.authorizeEndpoint = authorizeEndpoint
        self.tokenEndpoint = tokenEndpoint
    }
}

public struct OAuthToken: Codable, Sendable {
    public let accessToken: String
    public let refreshToken: String?
    public let expiresIn: Int
    public let tokenType: String
    public let acquiredAt: Date

    public init(accessToken: String, refreshToken: String?, expiresIn: Int, tokenType: String, acquiredAt: Date = Date()) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiresIn = expiresIn
        self.tokenType = tokenType
        self.acquiredAt = acquiredAt
    }

    public var expiresAt: Date {
        acquiredAt.addingTimeInterval(TimeInterval(expiresIn))
    }

    public var isExpired: Bool {
        Date() >= expiresAt
    }
}

public enum XPostingError: Error, LocalizedError {
    case missingConfiguration(String)
    case invalidResponse
    case unauthorized
    case network(String)
    case service(String)
    case oauthStateMismatch

    public var errorDescription: String? {
        switch self {
        case .missingConfiguration(let message): return message
        case .invalidResponse: return "Received an invalid response from the service."
        case .unauthorized: return "Authentication failed. Please reconnect your account."
        case .network(let message): return "Network error: \(message)"
        case .service(let message): return message
        case .oauthStateMismatch: return "OAuth callback state did not match the request."
        }
    }
}
