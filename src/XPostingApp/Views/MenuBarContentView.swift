import AppKit
import SwiftUI
import UniformTypeIdentifiers
import XPostingCore

struct MenuBarContentView: View {
    @ObservedObject var viewModel: ComposerViewModel

    @Environment(\.openWindow) private var openWindow
    @State private var isImporterPresented = false

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
                    presentImageImporter()
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
        .fileImporter(
            isPresented: $isImporterPresented,
            allowedContentTypes: [.image],
            allowsMultipleSelection: false
        ) { result in
            isImporterPresented = false
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    viewModel.attachImage(at: url)
                }
            case .failure(let error):
                viewModel.statusMessage = "Image selection failed: \(error.localizedDescription)"
                viewModel.statusIsError = true
            }
        }
        .onAppear {
            viewModel.bootstrapIfNeeded()
        }
    }

    private func presentImageImporter() {
        // In MenuBarExtra windows the importer binding can remain true after dismissal.
        // Force a false -> true transition so repeated clicks always reopen Finder.
        isImporterPresented = false
        DispatchQueue.main.async {
            isImporterPresented = true
        }
    }
}
