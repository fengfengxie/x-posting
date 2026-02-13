import AppKit
import SwiftUI
import UniformTypeIdentifiers
import XPostingCore

struct ComposerWindowView: View {
    @ObservedObject var viewModel: ComposerViewModel

    @Environment(\.openWindow) private var openWindow

    @State private var isImporterPresented = false

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Compose")
                    .font(.title2.weight(.semibold))

                TextEditor(text: $viewModel.draftText)
                    .font(.body)
                    .frame(minHeight: 260)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.25))
                    )
                    .onChange(of: viewModel.draftText) { _, _ in
                        viewModel.onDraftChanged()
                    }

                HStack {
                    Picker("Tone", selection: $viewModel.selectedPreset) {
                        Text("Concise").tag(PolishPreset.concise)
                        Text("Professional").tag(PolishPreset.professional)
                        Text("Casual").tag(PolishPreset.casual)
                    }
                    .pickerStyle(.segmented)

                    Picker("Output", selection: $viewModel.selectedOutputLanguage) {
                        Text("Auto").tag(TargetOutputLanguage.auto)
                        Text("EN").tag(TargetOutputLanguage.en)
                        Text("CN").tag(TargetOutputLanguage.cn)
                    }
                    .frame(width: 180)
                }

                HStack {
                    Label("Weighted: \(viewModel.weightedCharacterCount)", systemImage: "textformat.size")
                    Label("Posts: \(viewModel.estimatedPostCount)", systemImage: "number.square")
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                HStack {
                    Button("Analyze") {
                        viewModel.refreshAnalysis()
                    }

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
                    Button("Attach Image") {
                        isImporterPresented = true
                    }

                    if viewModel.imagePath != nil {
                        Button("Remove Image") {
                            viewModel.removeImage()
                        }
                    }

                    Spacer()

                    Button("Settings") {
                        NSApp.activate(ignoringOtherApps: true)
                        openWindow(id: "settings")
                        DispatchQueue.main.async {
                            NSApp.activate(ignoringOtherApps: true)
                        }
                    }
                }
                .font(.caption)

                if let imagePath = viewModel.imagePath {
                    Text("Attached: \(URL(fileURLWithPath: imagePath).lastPathComponent)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let message = viewModel.statusMessage {
                    Text(message)
                        .font(.callout)
                        .foregroundStyle(viewModel.statusIsError ? Color.red : Color.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if viewModel.isPolishing || viewModel.isPublishing {
                    ProgressView()
                        .controlSize(.small)
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Publish Preview")
                    .font(.headline)

                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(viewModel.segments) { segment in
                            VStack(alignment: .leading, spacing: 4) {
                                Text("#\(segment.index) • \(segment.weightedCharacterCount)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(segment.text)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(8)
                                    .background(Color.gray.opacity(0.09), in: RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }
                }
            }
            .frame(width: 280, alignment: .topLeading)
        }
        .padding(18)
        .fileImporter(
            isPresented: $isImporterPresented,
            allowedContentTypes: [.image],
            allowsMultipleSelection: false
        ) { result in
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
}
