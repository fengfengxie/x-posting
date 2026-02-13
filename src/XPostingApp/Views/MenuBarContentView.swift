import AppKit
import SwiftUI
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
                Button("Polish") {
                    viewModel.polishDraft()
                }
                .disabled(viewModel.isPolishing || viewModel.isPublishing)

                Button("Publish") {
                    viewModel.publishDraft()
                }
                .disabled(viewModel.isPolishing || viewModel.isPublishing)

                Button("Copy") {
                    viewModel.copyDraftToClipboard()
                }
            }

            HStack {
                Button {
                    NSApp.activate(ignoringOtherApps: true)
                    openWindow(id: "composer")
                } label: {
                    Label("Open Composer", systemImage: "square.and.pencil")
                }
                .buttonStyle(.bordered)

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
}
