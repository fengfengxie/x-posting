import AppKit
import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: ComposerViewModel

    @Environment(\.openURL) private var openURL
    @FocusState private var focusedField: FocusedField?

    @State private var xClientIDDraft: String = ""
    @State private var xRedirectURIDraft: String = "xposting://oauth/callback"
    @State private var callbackURLDraft: String = ""

    private enum FocusedField: Hashable {
        case clientID
        case redirectURI
        case callbackURL
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
                HStack {
                    TextField("Client ID", text: $xClientIDDraft)
                        .focused($focusedField, equals: .clientID)
                    Button("Paste") {
                        if let value = NSPasteboard.general.string(forType: .string) {
                            xClientIDDraft = value
                        }
                    }
                }
                TextField("Redirect URI", text: $xRedirectURIDraft)
                    .focused($focusedField, equals: .redirectURI)

                HStack {
                    Text(viewModel.xConnected ? "Connected" : "Not Connected")
                        .foregroundStyle(viewModel.xConnected ? Color.green : Color.secondary)

                    Spacer()

                    Button("Start OAuth") {
                        syncXDraftsToViewModel()
                        Task {
                            if let url = await viewModel.startXOAuth() {
                                openURL(url)
                            }
                        }
                    }

                    Button("Disconnect") {
                        viewModel.disconnectX()
                    }
                    .disabled(!viewModel.xConnected)
                }

                TextField("Callback URL (optional manual completion)", text: $callbackURLDraft)
                    .focused($focusedField, equals: .callbackURL)
                Button("Complete OAuth With Callback URL") {
                    syncXDraftsToViewModel()
                    viewModel.completeOAuthFromInput()
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
            syncDraftsFromViewModel()
            activateSettingsWindow()
        }
        .onChange(of: viewModel.xClientID) { _, _ in
            if focusedField != .clientID {
                xClientIDDraft = viewModel.xClientID
            }
        }
        .onChange(of: viewModel.xRedirectURI) { _, _ in
            if focusedField != .redirectURI {
                xRedirectURIDraft = viewModel.xRedirectURI
            }
        }
        .onChange(of: viewModel.callbackURLInput) { _, _ in
            if focusedField != .callbackURL {
                callbackURLDraft = viewModel.callbackURLInput
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
        xClientIDDraft = viewModel.xClientID
        xRedirectURIDraft = viewModel.xRedirectURI
        callbackURLDraft = viewModel.callbackURLInput
    }

    private func syncXDraftsToViewModel() {
        viewModel.xClientID = xClientIDDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        viewModel.xRedirectURI = xRedirectURIDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        viewModel.callbackURLInput = callbackURLDraft.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
