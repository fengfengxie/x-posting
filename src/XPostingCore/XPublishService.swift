import Foundation

public actor XPublishService {
    public struct Configuration: Sendable {
        public let createPostEndpoint: URL

        public init(
            createPostEndpoint: URL = URL(string: "https://api.twitter.com/2/tweets")!
        ) {
            self.createPostEndpoint = createPostEndpoint
        }
    }

    private let httpClient: HTTPClient
    private let signerProvider: @Sendable () async throws -> OAuth1Signer
    private let configuration: Configuration

    public init(
        httpClient: HTTPClient = URLSession.shared,
        configuration: Configuration = Configuration(),
        signerProvider: @escaping @Sendable () async throws -> OAuth1Signer
    ) {
        self.httpClient = httpClient
        self.configuration = configuration
        self.signerProvider = signerProvider
    }

    public func publish(_ plan: PublishPlan) async throws -> PublishResult {
        guard !plan.segments.isEmpty else {
            throw XPostingError.service("Cannot publish an empty post.")
        }

        let signer = try await signerProvider()

        var postedIDs: [String] = []
        var replyToID: String?

        for segment in plan.segments {
            let id = try await createPost(
                text: segment.text,
                replyToID: replyToID,
                signer: signer
            )
            postedIDs.append(id)
            replyToID = id
        }

        return PublishResult(success: true, postIDs: postedIDs)
    }

    private func createPost(text: String, replyToID: String?, signer: OAuth1Signer) async throws -> String {
        var request = URLRequest(url: configuration.createPostEndpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload = CreatePostRequest(
            text: text,
            reply: replyToID.map { .init(inReplyToTweetID: $0) }
        )

        request.httpBody = try JSONEncoder().encode(payload)
        request = signer.sign(request)

        let (data, response) = try await httpClient.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw XPostingError.invalidResponse
        }

        if httpResponse.statusCode == 401 {
            throw XPostingError.unauthorized
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Unknown post create error"
            throw XPostingError.service("Publish failed (\(httpResponse.statusCode)): \(message)")
        }

        let decoded = try JSONDecoder().decode(CreatePostResponse.self, from: data)
        return decoded.data.id
    }
}

private struct CreatePostRequest: Encodable {
    struct Reply: Encodable {
        let inReplyToTweetID: String

        enum CodingKeys: String, CodingKey {
            case inReplyToTweetID = "in_reply_to_tweet_id"
        }
    }

    let text: String
    let reply: Reply?
}

private struct CreatePostResponse: Decodable {
    struct Payload: Decodable {
        let id: String
    }

    let data: Payload
}
