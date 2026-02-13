import AppKit
import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: ComposerViewModel

    @FocusState private var focusedField: FocusedField?

    @State private var xAPIKeyDraft: String = ""
    @State private var xAPIKeySecretDraft: String = ""
    @State private var xAccessTokenDraft: String = ""
    @State private var xAccessTokenSecretDraft: String = ""

    private enum FocusedField: Hashable {
        case apiKey
        case apiKeySecret
        case accessToken
        case accessTokenSecret
    }

    var body: some View {
        Form {
            Section("DeepSeek") {
                TextField("Base URL", text: $viewModel.deepSeekBaseURL)
                TextField("Model", text: $viewModel.deepSeekModel)
                HStack {
                    TextField("API Key", text: $viewModel.deepSeekAPIKey)
                    Button("Paste") {
                        if let value = NSPasteboard.general.string(forType: .string) {
                            viewModel.deepSeekAPIKey = value
                        }
                    }
                }
            }

            Section("X API") {
                credentialRow("API Key", draft: $xAPIKeyDraft, focus: .apiKey)
                credentialRow("API Key Secret", draft: $xAPIKeySecretDraft, focus: .apiKeySecret)
                credentialRow("Access Token", draft: $xAccessTokenDraft, focus: .accessToken)
                credentialRow("Access Token Secret", draft: $xAccessTokenSecretDraft, focus: .accessTokenSecret)

                HStack {
                    Text(viewModel.xConnected ? "Connected" : "Not Connected")
                        .foregroundStyle(viewModel.xConnected ? Color.green : Color.secondary)

                    Spacer()

                    Button("Connect") {
                        syncXDraftsToViewModel()
                        viewModel.connectX()
                    }

                    Button("Disconnect") {
                        viewModel.disconnectX()
                        syncDraftsFromViewModel()
                    }
                    .disabled(!viewModel.xConnected)
                }
            }

            Section {
                Button("Save Settings") {
                    syncXDraftsToViewModel()
                    viewModel.saveSettings()
                }
                .disabled(viewModel.isSavingSettings)
            }

            if let message = viewModel.statusMessage {
                Text(message)
                    .foregroundStyle(viewModel.statusIsError ? Color.red : Color.secondary)
            }
        }
        .padding(12)
        .frame(width: 600)
        .onAppear {
            viewModel.bootstrapIfNeeded()
            activateSettingsWindow()
            Task {
                await viewModel.ensureXCredentialsLoaded()
                syncDraftsFromViewModel()
            }
        }
        .onChange(of: viewModel.xAPIKey) { _, _ in
            if focusedField != .apiKey { xAPIKeyDraft = viewModel.xAPIKey }
        }
        .onChange(of: viewModel.xAPIKeySecret) { _, _ in
            if focusedField != .apiKeySecret { xAPIKeySecretDraft = viewModel.xAPIKeySecret }
        }
        .onChange(of: viewModel.xAccessToken) { _, _ in
            if focusedField != .accessToken { xAccessTokenDraft = viewModel.xAccessToken }
        }
        .onChange(of: viewModel.xAccessTokenSecret) { _, _ in
            if focusedField != .accessTokenSecret { xAccessTokenSecretDraft = viewModel.xAccessTokenSecret }
        }
    }

    private func credentialRow(_ label: String, draft: Binding<String>, focus: FocusedField) -> some View {
        HStack {
            SecureField(label, text: draft)
                .focused($focusedField, equals: focus)
            Button("Paste") {
                if let value = NSPasteboard.general.string(forType: .string) {
                    draft.wrappedValue = value
                }
            }
        }
    }

    private func activateSettingsWindow() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        DispatchQueue.main.async {
            for window in NSApp.windows where window.title.contains("Settings") {
                window.makeKeyAndOrderFront(nil)
            }
        }
    }

    private func syncDraftsFromViewModel() {
        xAPIKeyDraft = viewModel.xAPIKey
        xAPIKeySecretDraft = viewModel.xAPIKeySecret
        xAccessTokenDraft = viewModel.xAccessToken
        xAccessTokenSecretDraft = viewModel.xAccessTokenSecret
    }

    private func syncXDraftsToViewModel() {
        viewModel.xAPIKey = xAPIKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        viewModel.xAPIKeySecret = xAPIKeySecretDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        viewModel.xAccessToken = xAccessTokenDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        viewModel.xAccessTokenSecret = xAccessTokenSecretDraft.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
