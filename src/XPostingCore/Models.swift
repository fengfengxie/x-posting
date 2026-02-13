import Foundation

public struct Draft: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var text: String
    public let createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        text: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.text = text
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct XCredentials: Codable, Sendable {
    public let apiKey: String
    public let apiKeySecret: String
    public let accessToken: String
    public let accessTokenSecret: String

    public init(apiKey: String, apiKeySecret: String, accessToken: String, accessTokenSecret: String) {
        self.apiKey = apiKey
        self.apiKeySecret = apiKeySecret
        self.accessToken = accessToken
        self.accessTokenSecret = accessTokenSecret
    }
}

public struct AppSettings: Codable, Sendable {
    public var deepSeekBaseURL: URL
    public var deepSeekModel: String
    public var deepSeekAPIKey: String

    public init(
        deepSeekBaseURL: URL = URL(string: "https://api.deepseek.com")!,
        deepSeekModel: String = "deepseek-chat",
        deepSeekAPIKey: String = ""
    ) {
        self.deepSeekBaseURL = deepSeekBaseURL
        self.deepSeekModel = deepSeekModel
        self.deepSeekAPIKey = deepSeekAPIKey
    }
}

public struct PolishRequest: Sendable {
    public let originalText: String

    public init(originalText: String) {
        self.originalText = originalText
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

    public init(segments: [PostSegment]) {
        self.segments = segments
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

public enum XPostingError: Error, LocalizedError {
    case missingConfiguration(String)
    case invalidResponse
    case unauthorized
    case network(String)
    case service(String)

    public var errorDescription: String? {
        switch self {
        case .missingConfiguration(let message): return message
        case .invalidResponse: return "Received an invalid response from the service."
        case .unauthorized: return "Authentication failed. Please reconnect your account."
        case .network(let message): return "Network error: \(message)"
        case .service(let message): return message
        }
    }
}
