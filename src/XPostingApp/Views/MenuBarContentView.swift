import AppKit
import SwiftUI
import UniformTypeIdentifiers
import XPostingCore

struct MenuBarContentView: View {
    @ObservedObject var viewModel: ComposerViewModel

    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Quick Draft")
                .font(.headline)

            TextEditor(text: $viewModel.draftText)
                .font(.body)
                .padding(6)
                .frame(minHeight: 110, maxHeight: 140)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.gray.opacity(0.25))
                )
                .onChange(of: viewModel.draftText) { _, _ in
                    viewModel.onDraftChanged()
                }

            HStack {
                Label("\(viewModel.weightedCharacterCount)", systemImage: "textformat.size")
                Spacer()
                Label("\(viewModel.estimatedPostCount)", systemImage: "number.square")
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            HStack {
                Button("Publish") {
                    viewModel.publishDraft()
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .disabled(viewModel.isPolishing || viewModel.isPublishing)

                Button("Fix Text") {
                    viewModel.polishDraft()
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .disabled(viewModel.isPolishing || viewModel.isPublishing)
            }

            HStack {
                Button {
                    openImagePanel()
                } label: {
                    Label("Attach Image", systemImage: "paperclip")
                }
                .buttonStyle(.bordered)

                if viewModel.imagePath != nil {
                    Button("Remove") {
                        viewModel.removeImage()
                    }
                    .buttonStyle(.bordered)
                }

                Spacer()
            }
            .font(.caption)
            .controlSize(.small)

            if let imagePath = viewModel.imagePath {
                Text("Attached: \(URL(fileURLWithPath: imagePath).lastPathComponent)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            HStack {
                Button {
                    NSApp.activate(ignoringOtherApps: true)
                    openWindow(id: "settings")
                } label: {
                    Label("Settings", systemImage: "gearshape")
                }
                .buttonStyle(.bordered)

                Spacer()

                Button(role: .destructive) {
                    NSApp.terminate(nil)
                } label: {
                    Label("Quit", systemImage: "power")
                }
                .buttonStyle(.bordered)
            }
            .font(.caption)
            .controlSize(.small)

            if let message = viewModel.statusMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(viewModel.statusIsError ? Color.red : Color.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if viewModel.isPolishing || viewModel.isPublishing {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .padding(12)
        .frame(width: 360)
        .onAppear {
            viewModel.bootstrapIfNeeded()
        }
    }

    private func openImagePanel() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.level = .popUpMenu
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            Task { @MainActor in
                viewModel.attachImage(at: url)
            }
        }
    }
}
