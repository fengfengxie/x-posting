import AppKit
import Foundation
import XPostingCore

@MainActor
final class ComposerViewModel: ObservableObject {
    @Published var draftText: String = ""

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
    @Published var canRevertPolish: Bool = false
    @Published var publishedPostURL: URL?

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
    private var hasLoadedXCredentials = false
    private var lastPrePolishText: String?

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

        let originalText = draftText
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
                lastPrePolishText = originalText
                setStatus("Polished successfully.", isError: false, canRevertPolish: true)
            } catch {
                setStatus("Polish failed: \(error.localizedDescription)", isError: true)
            }
            isPolishing = false
        }
    }

    func revertLastPolish() {
        guard let originalText = lastPrePolishText else { return }

        draftText = originalText
        refreshAnalysis()

        Task {
            do {
                _ = try await draftStore.updateText(originalText)
                setStatus("Reverted to pre-polish text.", isError: false)
            } catch {
                setStatus("Reverted locally, but failed to save draft: \(error.localizedDescription)", isError: true)
            }
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
                let result = try await publishService.publish(PublishPlan(segments: segments))

                if result.success {
                    draftText = ""
                    try await draftStore.clear()
                    refreshAnalysis()
                    let postURL = result.postIDs.first.map { URL(string: "https://x.com/i/web/status/\($0)")! }
                    setStatus("Published \(result.postIDs.count) post(s).", isError: false, publishedPostURL: postURL)
                } else {
                    setStatus(result.errorMessage ?? "Publish failed.", isError: true)
                }
            } catch {
                setStatus("Publish failed: \(error.localizedDescription)", isError: true)
            }
            isPublishing = false
        }
    }

    func openComposePostForImageEditing() {
        let trimmedText = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: "https://x.com/compose/post") else {
            setStatus("Failed to open X compose page.", isError: true)
            return
        }

        if !trimmedText.isEmpty {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(trimmedText, forType: .string)
        }

        NSWorkspace.shared.open(url)
        if trimmedText.isEmpty {
            setStatus("Opened X compose page for image editing.", isError: false)
        } else {
            setStatus("Copied draft to clipboard and opened X compose page.", isError: false)
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
                hasLoadedXCredentials = true
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
                hasLoadedXCredentials = true
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

    func ensureXCredentialsLoaded() async {
        guard !hasLoadedXCredentials else { return }
        hasLoadedXCredentials = true

        do {
            if let creds = try await credentialService.load() {
                xAPIKey = creds.apiKey
                xAPIKeySecret = creds.apiKeySecret
                xAccessToken = creds.accessToken
                xAccessTokenSecret = creds.accessTokenSecret
                xConnected = true
            } else {
                xConnected = false
            }
        } catch {
            setStatus("Failed to read X auth status: \(error.localizedDescription)", isError: true)
        }
    }

    private func loadInitialState() async {
        let draft = await draftStore.load()
        let settings = await settingsStore.load()

        draftText = draft.text

        deepSeekBaseURL = settings.deepSeekBaseURL.absoluteString
        deepSeekModel = settings.deepSeekModel
        deepSeekAPIKey = settings.deepSeekAPIKey

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

    private func setStatus(_ message: String, isError: Bool, canRevertPolish: Bool = false, publishedPostURL: URL? = nil) {
        statusMessage = message
        statusIsError = isError
        self.canRevertPolish = canRevertPolish
        self.publishedPostURL = publishedPostURL
        if !canRevertPolish {
            lastPrePolishText = nil
        }
    }
}
