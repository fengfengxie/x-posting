import Foundation

public actor XPublishService {
    public struct Configuration: Sendable {
        public let createPostEndpoint: URL
        public let mediaUploadEndpoint: URL

        public init(
            createPostEndpoint: URL = URL(string: "https://api.twitter.com/2/tweets")!,
            mediaUploadEndpoint: URL = URL(string: "https://upload.twitter.com/1.1/media/upload.json")!
        ) {
            self.createPostEndpoint = createPostEndpoint
            self.mediaUploadEndpoint = mediaUploadEndpoint
        }
    }

    private let httpClient: HTTPClient
    private let accessTokenProvider: @Sendable () async throws -> String
    private let configuration: Configuration

    public init(
        httpClient: HTTPClient = URLSession.shared,
        configuration: Configuration = Configuration(),
        accessTokenProvider: @escaping @Sendable () async throws -> String
    ) {
        self.httpClient = httpClient
        self.configuration = configuration
        self.accessTokenProvider = accessTokenProvider
    }

    public func publish(_ plan: PublishPlan) async throws -> PublishResult {
        guard !plan.segments.isEmpty else {
            throw XPostingError.service("Cannot publish an empty post.")
        }

        let accessToken = try await accessTokenProvider()
        guard !accessToken.isEmpty else {
            throw XPostingError.unauthorized
        }

        var mediaID: String?
        if let imageData = plan.imageData {
            mediaID = try await uploadImage(imageData, accessToken: accessToken)
        }

        var postedIDs: [String] = []
        var replyToID: String?

        for (index, segment) in plan.segments.enumerated() {
            let attachMedia = index == 0 ? mediaID : nil
            let id = try await createPost(
                text: segment.text,
                replyToID: replyToID,
                mediaID: attachMedia,
                accessToken: accessToken
            )
            postedIDs.append(id)
            replyToID = id
        }

        return PublishResult(success: true, postIDs: postedIDs)
    }

    private func uploadImage(_ imageData: Data, accessToken: String) async throws -> String {
        var request = URLRequest(url: configuration.mediaUploadEndpoint)
        request.httpMethod = "POST"

        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"media\"; filename=\"image.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        let (data, response) = try await httpClient.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw XPostingError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Unknown media upload error"
            throw XPostingError.service("Image upload failed (\(httpResponse.statusCode)): \(message)")
        }

        let decoded = try JSONDecoder().decode(MediaUploadResponse.self, from: data)
        return decoded.mediaIDString
    }

    private func createPost(text: String, replyToID: String?, mediaID: String?, accessToken: String) async throws -> String {
        var request = URLRequest(url: configuration.createPostEndpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let payload = CreatePostRequest(
            text: text,
            reply: replyToID.map { .init(inReplyToTweetID: $0) },
            media: mediaID.map { .init(mediaIDs: [$0]) }
        )

        request.httpBody = try JSONEncoder().encode(payload)

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

private struct MediaUploadResponse: Decodable {
    let mediaIDString: String

    enum CodingKeys: String, CodingKey {
        case mediaIDString = "media_id_string"
    }
}

private struct CreatePostRequest: Encodable {
    struct Reply: Encodable {
        let inReplyToTweetID: String

        enum CodingKeys: String, CodingKey {
            case inReplyToTweetID = "in_reply_to_tweet_id"
        }
    }

    struct Media: Encodable {
        let mediaIDs: [String]

        enum CodingKeys: String, CodingKey {
            case mediaIDs = "media_ids"
        }
    }

    let text: String
    let reply: Reply?
    let media: Media?
}

private struct CreatePostResponse: Decodable {
    struct Payload: Decodable {
        let id: String
    }

    let data: Payload
}
