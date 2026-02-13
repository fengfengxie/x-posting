import AppKit
import Foundation
import XPostingCore

@MainActor
final class ComposerViewModel: ObservableObject {
    @Published var draftText: String = ""
    @Published var imagePath: String?

    @Published var selectedPreset: PolishPreset = .concise
    @Published var selectedOutputLanguage: TargetOutputLanguage = .auto

    @Published var weightedCharacterCount: Int = 0
    @Published var estimatedPostCount: Int = 1
    @Published var segments: [PostSegment] = []

    @Published var deepSeekBaseURL: String = "https://api.deepseek.com"
    @Published var deepSeekModel: String = "deepseek-chat"
    @Published var deepSeekAPIKey: String = ""

    @Published var xClientID: String = ""
    @Published var xRedirectURI: String = "xposting://oauth/callback"
    @Published var callbackURLInput: String = ""
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
    private let authService: XAuthService
    private let publishService: XPublishService

    private var hasBootstrapped = false
    private var pendingOAuthState: String?
    private var pendingOAuthCodeVerifier: String?

    init(
        draftStore: DraftStore,
        settingsStore: AppSettingsStore,
        credentialStore: SecureCredentialStore,
        limitService: CharacterLimitService,
        polishService: DeepSeekPolishService,
        authService: XAuthService,
        publishService: XPublishService
    ) {
        self.draftStore = draftStore
        self.settingsStore = settingsStore
        self.credentialStore = credentialStore
        self.limitService = limitService
        self.polishService = polishService
        self.authService = authService
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

        let authService = XAuthService(
            configurationProvider: {
                let settings = await settingsStore.load()
                return OAuthConfiguration(clientID: settings.xClientID, redirectURI: settings.xRedirectURI)
            },
            credentialStore: credentialStore
        )

        let publishService = XPublishService(accessTokenProvider: {
            guard let token = try await authService.loadToken() else {
                throw XPostingError.unauthorized
            }
            return token.accessToken
        })

        return ComposerViewModel(
            draftStore: draftStore,
            settingsStore: settingsStore,
            credentialStore: credentialStore,
            limitService: limitService,
            polishService: polishService,
            authService: authService,
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
                        originalText: draftText,
                        preset: selectedPreset,
                        outputLanguage: selectedOutputLanguage
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
        imagePath = url.path
        Task {
            do {
                _ = try await draftStore.updateImagePath(url.path)
                setStatus("Image attached.", isError: false)
            } catch {
                setStatus("Failed to save image selection: \(error.localizedDescription)", isError: true)
            }
        }
    }

    func removeImage() {
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
                try await persistXSettings()
                setStatus("Settings saved.", isError: false)
            } catch {
                setStatus("Failed to save settings: \(error.localizedDescription)", isError: true)
            }
        }
    }

    func startXOAuth() async -> URL? {
        do {
            try await persistXSettings()
            let request = try await authService.createAuthorizationRequest()
            pendingOAuthState = request.state
            pendingOAuthCodeVerifier = request.codeVerifier
            setStatus("Browser opened for X login. Complete login and provide callback URL if needed.", isError: false)
            return request.url
        } catch {
            setStatus("Unable to start OAuth: \(error.localizedDescription)", isError: true)
            return nil
        }
    }

    func completeOAuthFromInput() {
        guard let callbackURL = URL(string: callbackURLInput.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            setStatus("Callback URL is invalid.", isError: true)
            return
        }

        Task {
            await handleOAuthCallback(callbackURL)
        }
    }

    func handleOAuthCallback(_ url: URL) async {
        guard let state = pendingOAuthState, let verifier = pendingOAuthCodeVerifier else {
            setStatus("No OAuth request in progress.", isError: true)
            return
        }

        do {
            _ = try await authService.exchangeCode(from: url, expectedState: state, codeVerifier: verifier)
            pendingOAuthState = nil
            pendingOAuthCodeVerifier = nil
            xConnected = true
            setStatus("X account connected.", isError: false)
        } catch {
            setStatus("OAuth completion failed: \(error.localizedDescription)", isError: true)
        }
    }

    func disconnectX() {
        Task {
            do {
                try await authService.clearToken()
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

        selectedPreset = settings.defaultPreset
        selectedOutputLanguage = settings.defaultOutputLanguage

        deepSeekBaseURL = settings.deepSeekBaseURL.absoluteString
        deepSeekModel = settings.deepSeekModel
        deepSeekAPIKey = settings.deepSeekAPIKey

        xClientID = settings.xClientID
        xRedirectURI = settings.xRedirectURI

        do {
            xConnected = (try await authService.loadToken()) != nil
        } catch {
            setStatus("Failed to read X auth status: \(error.localizedDescription)", isError: true)
        }

        refreshAnalysis()
    }

    private func persistXSettings() async throws {
        guard let baseURL = URL(string: deepSeekBaseURL) else {
            throw XPostingError.service("DeepSeek base URL is invalid.")
        }
        let settings = AppSettings(
            deepSeekBaseURL: baseURL,
            deepSeekModel: deepSeekModel,
            deepSeekAPIKey: deepSeekAPIKey,
            defaultPreset: selectedPreset,
            defaultOutputLanguage: selectedOutputLanguage,
            xClientID: xClientID,
            xRedirectURI: xRedirectURI
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
