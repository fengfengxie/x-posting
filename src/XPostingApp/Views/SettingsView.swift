import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: ComposerViewModel

    @Environment(\.openURL) private var openURL

    var body: some View {
        Form {
            Section("DeepSeek") {
                TextField("Base URL", text: $viewModel.deepSeekBaseURL)
                TextField("Model", text: $viewModel.deepSeekModel)
                SecureField("API Key", text: $viewModel.deepSeekAPIKey)
            }

            Section("X API") {
                TextField("Client ID", text: $viewModel.xClientID)
                TextField("Redirect URI", text: $viewModel.xRedirectURI)

                HStack {
                    Text(viewModel.xConnected ? "Connected" : "Not Connected")
                        .foregroundStyle(viewModel.xConnected ? Color.green : Color.secondary)

                    Spacer()

                    Button("Start OAuth") {
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

                TextField("Callback URL (optional manual completion)", text: $viewModel.callbackURLInput)
                Button("Complete OAuth With Callback URL") {
                    viewModel.completeOAuthFromInput()
                }
            }

            Section {
                Button("Save Settings") {
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
        }
    }
}
