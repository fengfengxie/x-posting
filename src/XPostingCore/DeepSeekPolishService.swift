import Foundation

public actor DeepSeekPolishService {
    private let httpClient: HTTPClient
    private let settingsProvider: @Sendable () async -> AppSettings
    private let limitService: CharacterLimitService

    public init(
        httpClient: HTTPClient = URLSession.shared,
        settingsProvider: @escaping @Sendable () async -> AppSettings,
        limitService: CharacterLimitService = CharacterLimitService()
    ) {
        self.httpClient = httpClient
        self.settingsProvider = settingsProvider
        self.limitService = limitService
    }

    public func polish(_ request: PolishRequest) async throws -> PolishResponse {
        let settings = await settingsProvider()
        let apiKey = settings.deepSeekAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !apiKey.isEmpty else {
            throw XPostingError.missingConfiguration("DeepSeek API key is missing.")
        }

        let endpoint = settings.deepSeekBaseURL.appending(path: "/chat/completions")

        var urlRequest = URLRequest(url: endpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let payload = DeepSeekChatRequest(
            model: settings.deepSeekModel,
            messages: [
                DeepSeekChatMessage(role: "system", content: systemPrompt(for: request)),
                DeepSeekChatMessage(role: "user", content: request.originalText)
            ],
            temperature: 0.3
        )

        urlRequest.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await httpClient.data(for: urlRequest)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw XPostingError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Unknown DeepSeek API error"
            throw XPostingError.service("DeepSeek request failed (\(httpResponse.statusCode)): \(message)")
        }

        let decoded = try JSONDecoder().decode(DeepSeekChatResponse.self, from: data)
        guard let content = decoded.choices.first?.message.content?.trimmingCharacters(in: .whitespacesAndNewlines), !content.isEmpty else {
            throw XPostingError.invalidResponse
        }

        let estimate = limitService.analyze(content).estimatedPosts
        return PolishResponse(polishedText: content, estimatedPostCount: estimate)
    }

    private func systemPrompt(for request: PolishRequest) -> String {
        let toneInstruction: String
        switch request.preset {
        case .concise:
            toneInstruction = "Keep it concise and direct."
        case .professional:
            toneInstruction = "Use a professional and clear tone."
        case .casual:
            toneInstruction = "Use a natural, casual tone."
        }

        let languageInstruction: String
        switch request.outputLanguage {
        case .auto:
            languageInstruction = "Automatically keep the most suitable language from the input (English or Chinese)."
        case .en:
            languageInstruction = "Output in English."
        case .cn:
            languageInstruction = "Output in Chinese."
        }

        return "You improve social media post drafts for X. Fix grammar and readability while preserving factual meaning. \(toneInstruction) \(languageInstruction) Keep hashtags and mentions if they are present."
    }
}

private struct DeepSeekChatRequest: Encodable {
    let model: String
    let messages: [DeepSeekChatMessage]
    let temperature: Double
}

private struct DeepSeekChatMessage: Codable {
    let role: String
    let content: String
}

private struct DeepSeekChatResponse: Decodable {
    let choices: [Choice]

    struct Choice: Decodable {
        let message: Message
    }

    struct Message: Decodable {
        let content: String?
    }
}
