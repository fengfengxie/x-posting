import AppKit
import Foundation
import XPostingCore

@MainActor
final class ComposerViewModel: ObservableObject {
    @Published var draftText: String = ""
    @Published var imagePath: String?

    @Published var weightedCharacterCount: Int = 0
    @Published var estimatedPostCount: Int = 1
    @Published var segments: [PostSegment] = []

    @Published var deepSeekBaseURL: String = "https://api.deepseek.com"
    @Published var deepSeekModel: String = "deepseek-chat"
    @Published var deepSeekAPIKey: String = ""

    @Published var xAPIKey: String = ""
    @Published var xAPIKeySecret: String = ""
    @Published var xAccessToken: String = ""
    @Published var xAccessTokenSecret: String = ""
    @Published var xConnected: Bool = false

    @Published var statusMessage: String?
    @Published var statusIsError: Bool = false

    @Published var isPolishing: Bool = false
    @Published var isPublishing: Bool = false
    @Published var isSavingSettings: Bool = false

    private let draftStore: DraftStore
    private let settingsStore: AppSettingsStore
    private let credentialStore: SecureCredentialStore
    private let limitService: CharacterLimitService
    private let polishService: DeepSeekPolishService
    private let credentialService: XCredentialService
    private let publishService: XPublishService

    private var hasBootstrapped = false

    init(
        draftStore: DraftStore,
        settingsStore: AppSettingsStore,
        credentialStore: SecureCredentialStore,
        limitService: CharacterLimitService,
        polishService: DeepSeekPolishService,
        credentialService: XCredentialService,
        publishService: XPublishService
    ) {
        self.draftStore = draftStore
        self.settingsStore = settingsStore
        self.credentialStore = credentialStore
        self.limitService = limitService
        self.polishService = polishService
        self.credentialService = credentialService
        self.publishService = publishService
    }

    static func live() -> ComposerViewModel {
        let draftStore = DraftStore()
        let settingsStore = AppSettingsStore()
        let credentialStore = KeychainCredentialStore()
        let limitService = CharacterLimitService()

        let polishService = DeepSeekPolishService(
            settingsProvider: {
                await settingsStore.load()
            },
            limitService: limitService
        )

        let credentialService = XCredentialService(credentialStore: credentialStore)

        let publishService = XPublishService(signerProvider: {
            guard let creds = try await credentialService.load() else {
                throw XPostingError.unauthorized
            }
            return OAuth1Signer(credentials: creds)
        })

        return ComposerViewModel(
            draftStore: draftStore,
            settingsStore: settingsStore,
            credentialStore: credentialStore,
            limitService: limitService,
            polishService: polishService,
            credentialService: credentialService,
            publishService: publishService
        )
    }

    func bootstrapIfNeeded() {
        guard !hasBootstrapped else { return }
        hasBootstrapped = true

        Task {
            await loadInitialState()
        }
    }

    func onDraftChanged() {
        refreshAnalysis()
        Task {
            do {
                _ = try await draftStore.updateText(draftText)
            } catch {
                setStatus("Failed to save draft: \(error.localizedDescription)", isError: true)
            }
        }
    }

    func refreshAnalysis() {
        let analysis = limitService.analyze(draftText)
        weightedCharacterCount = analysis.weightedCharacters
        estimatedPostCount = analysis.estimatedPosts
        segments = limitService.split(draftText)
    }

    func polishDraft() {
        guard !draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            setStatus("Draft is empty.", isError: true)
            return
        }

        isPolishing = true
        Task {
            do {
                let response = try await polishService.polish(
                    PolishRequest(
                        originalText: draftText
                    )
                )

                draftText = response.polishedText
                _ = try await draftStore.updateText(draftText)
                refreshAnalysis()
                setStatus("Polished successfully.", isError: false)
            } catch {
                setStatus("Polish failed: \(error.localizedDescription)", isError: true)
            }
            isPolishing = false
        }
    }

    func publishDraft() {
        guard !draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            setStatus("Draft is empty.", isError: true)
            return
        }

        isPublishing = true
        Task {
            do {
                let segments = limitService.split(draftText)
                let imageData = try loadImageDataIfNeeded()
                let result = try await publishService.publish(PublishPlan(segments: segments, imageData: imageData))

                if result.success {
                    draftText = ""
                    imagePath = nil
                    try await draftStore.clear()
                    refreshAnalysis()
                    setStatus("Published \(result.postIDs.count) post(s).", isError: false)
                } else {
                    setStatus(result.errorMessage ?? "Publish failed.", isError: true)
                }
            } catch {
                setStatus("Publish failed: \(error.localizedDescription)", isError: true)
            }
            isPublishing = false
        }
    }

    func copyDraftToClipboard() {
        let value = draftText
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
        setStatus("Copied draft to clipboard.", isError: false)
    }

    func attachImage(at url: URL) {
        do {
            // Security-scoped access for fileImporter URLs; no-op for NSOpenPanel URLs.
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }

            // Copy image into app support so the data is always readable later.
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let dir = appSupport.appendingPathComponent("XPosting", isDirectory: true)
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let dest = dir.appendingPathComponent("attached_image_\(url.lastPathComponent)")
            if FileManager.default.fileExists(atPath: dest.path) {
                try FileManager.default.removeItem(at: dest)
            }
            try FileManager.default.copyItem(at: url, to: dest)

            imagePath = dest.path
            Task {
                do {
                    _ = try await draftStore.updateImagePath(dest.path)
                    setStatus("Image attached.", isError: false)
                } catch {
                    setStatus("Failed to save image selection: \(error.localizedDescription)", isError: true)
                }
            }
        } catch {
            setStatus("Failed to attach image: \(error.localizedDescription)", isError: true)
        }
    }

    func removeImage() {
        if let imagePath {
            try? FileManager.default.removeItem(atPath: imagePath)
        }
        imagePath = nil
        Task {
            do {
                _ = try await draftStore.updateImagePath(nil)
            } catch {
                setStatus("Failed to remove image: \(error.localizedDescription)", isError: true)
            }
        }
    }

    func saveSettings() {
        isSavingSettings = true

        Task {
            defer { isSavingSettings = false }

            do {
                try await persistSettings()
                setStatus("Settings saved.", isError: false)
            } catch {
                setStatus("Failed to save settings: \(error.localizedDescription)", isError: true)
            }
        }
    }

    func connectX() {
        let fields = [xAPIKey, xAPIKeySecret, xAccessToken, xAccessTokenSecret]
        guard fields.allSatisfy({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
            setStatus("All four X API credential fields are required.", isError: true)
            return
        }

        Task {
            do {
                let credentials = XCredentials(
                    apiKey: xAPIKey.trimmingCharacters(in: .whitespacesAndNewlines),
                    apiKeySecret: xAPIKeySecret.trimmingCharacters(in: .whitespacesAndNewlines),
                    accessToken: xAccessToken.trimmingCharacters(in: .whitespacesAndNewlines),
                    accessTokenSecret: xAccessTokenSecret.trimmingCharacters(in: .whitespacesAndNewlines)
                )
                try await credentialService.save(credentials)
                xConnected = true
                setStatus("X account connected.", isError: false)
            } catch {
                setStatus("Failed to save X credentials: \(error.localizedDescription)", isError: true)
            }
        }
    }

    func disconnectX() {
        Task {
            do {
                try await credentialService.clear()
                xAPIKey = ""
                xAPIKeySecret = ""
                xAccessToken = ""
                xAccessTokenSecret = ""
                xConnected = false
                setStatus("X account disconnected.", isError: false)
            } catch {
                setStatus("Failed to disconnect X account: \(error.localizedDescription)", isError: true)
            }
        }
    }

    private func loadInitialState() async {
        let draft = await draftStore.load()
        let settings = await settingsStore.load()

        draftText = draft.text
        imagePath = draft.imagePath

        deepSeekBaseURL = settings.deepSeekBaseURL.absoluteString
        deepSeekModel = settings.deepSeekModel
        deepSeekAPIKey = settings.deepSeekAPIKey

        do {
            if let creds = try await credentialService.load() {
                xAPIKey = creds.apiKey
                xAPIKeySecret = creds.apiKeySecret
                xAccessToken = creds.accessToken
                xAccessTokenSecret = creds.accessTokenSecret
                xConnected = true
            }
        } catch {
            setStatus("Failed to read X auth status: \(error.localizedDescription)", isError: true)
        }

        refreshAnalysis()
    }

    private func persistSettings() async throws {
        guard let baseURL = URL(string: deepSeekBaseURL) else {
            throw XPostingError.service("DeepSeek base URL is invalid.")
        }
        let settings = AppSettings(
            deepSeekBaseURL: baseURL,
            deepSeekModel: deepSeekModel,
            deepSeekAPIKey: deepSeekAPIKey
        )
        try await settingsStore.save(settings)
    }

    private func loadImageDataIfNeeded() throws -> Data? {
        guard let imagePath else { return nil }
        let url = URL(fileURLWithPath: imagePath)
        return try Data(contentsOf: url)
    }

    private func setStatus(_ message: String, isError: Bool) {
        statusMessage = message
        statusIsError = isError
    }
}
