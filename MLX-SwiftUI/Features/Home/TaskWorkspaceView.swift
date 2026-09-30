import FoundationModels
import PhotosUI
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

enum WorkspaceAction: String, Hashable, CaseIterable {
    case summarize, rewrite, extract, understandImage, analyzeDocument

    var title: String {
        switch self {
        case .summarize: "Summarize"
        case .rewrite: "Rewrite"
        case .extract: "Extract"
        case .understandImage: "Read Image Text"
        case .analyzeDocument: "Analyze Document"
        }
    }
}

enum WorkspaceSourceKind: String, Hashable {
    case text, image, document
}

struct WorkspaceInput: Hashable, Identifiable {
    let id = UUID()
    let action: WorkspaceAction
    let kind: WorkspaceSourceKind
    let title: String
    let text: String
}

@Model
final class SavedTaskResult {
    @Attribute(.unique) var id: UUID
    var title: String
    var actionRawValue: String
    var kindRawValue: String
    var sourceText: String
    var resultText: String
    var createdAt: Date

    init(title: String, action: WorkspaceAction, kind: WorkspaceSourceKind, sourceText: String, resultText: String) {
        id = UUID()
        self.title = title
        actionRawValue = action.rawValue
        kindRawValue = kind.rawValue
        self.sourceText = sourceText
        self.resultText = resultText
        createdAt = .now
    }
}

struct TaskWorkspaceView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    let input: WorkspaceInput
    @State private var text = ""
    @State private var sourceTitle = ""
    @State private var sourceKind: WorkspaceSourceKind = .text
    @State private var question = ""
    @State private var tone = "Professional"
    @State private var detail = "Short"
    @State private var result = ""
    @State private var errorMessage: String?
    @State private var isWorking = false
    @State private var isImporting = false
    @State private var showsFileImporter = false
    @State private var showsSource = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var task: Task<Void, Never>?
    @State private var savedID: UUID?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Label("Only on your device", systemImage: "lock.shield")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.green)
                Text(input.action.title).font(.largeTitle.bold())

                if !result.isEmpty { resultSection }
                else if isWorking { workingSection }
                else { inputSection }
            }
            .padding(20)
            .frame(maxWidth: 650, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle(input.action.title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if sourceTitle.isEmpty {
                text = input.text
                sourceTitle = input.title
                sourceKind = input.kind
            }
        }
        .onDisappear { task?.cancel() }
        .fileImporter(isPresented: $showsFileImporter, allowedContentTypes: [.pdf, .plainText, .init(filenameExtension: "md") ?? .plainText]) { selection in
            guard case .success(let url) = selection else { return }
            isImporting = true
            Task {
                do {
                    let imported = try await HomeContentExtractor.document(from: url)
                    text = imported
                    sourceTitle = url.lastPathComponent
                    sourceKind = .document
                    errorMessage = nil
                } catch {
                    errorMessage = error.localizedDescription
                }
                isImporting = false
            }
        }
        .onChange(of: selectedPhoto) { _, photo in
            guard let photo else { return }
            isImporting = true
            Task {
                do {
                    guard let data = try await photo.loadTransferable(type: Data.self) else { throw HomeImportError.noText }
                    text = try await HomeContentExtractor.image(from: data)
                    sourceTitle = "Selected image"
                    sourceKind = .image
                    errorMessage = nil
                } catch {
                    errorMessage = error.localizedDescription
                }
                isImporting = false
                selectedPhoto = nil
            }
        }
        .sheet(isPresented: $showsSource) {
            NavigationStack {
                ScrollView { Text(text).frame(maxWidth: .infinity, alignment: .leading).padding() }
                    .navigationTitle(sourceTitle)
                    .toolbar { Button("Done") { showsSource = false } }
            }
        }
    }

    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            if sourceKind != .text && !text.isEmpty {
                Label(sourceTitle, systemImage: sourceKind == .document ? "doc.text" : "text.viewfinder")
                Button("View source") { showsSource = true }
            }
            TextEditor(text: $text)
                .frame(minHeight: 180)
                .padding(8)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
                .accessibilityLabel("Source text")
            Text("\(text.count) / 10,000 characters")
                .font(.caption).foregroundStyle(text.count > 10_000 ? .red : .secondary)

            if input.action == .understandImage {
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    Label("Choose screenshot or photo", systemImage: "photo")
                }
                Text("Reads visible text. Photo scene descriptions are not available yet.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if input.action == .analyzeDocument {
                Button("Choose document", systemImage: "doc") { showsFileImporter = true }
                TextField("Optional question about the document", text: $question)
                    .textFieldStyle(.roundedBorder)
            }
            if input.action == .rewrite {
                Picker("Tone", selection: $tone) {
                    ForEach(["Professional", "Friendly", "Direct"], id: \.self) { Text($0) }
                }
            }
            if input.action == .summarize || input.action == .rewrite {
                Picker("Length", selection: $detail) {
                    ForEach(["Short", "Detailed"], id: \.self) { Text($0) }
                }
            }
            if isImporting { ProgressView("Reading content…") }
            if let errorMessage {
                Text(errorMessage).foregroundStyle(.red)
                Button("Try again") { self.errorMessage = nil }
            }
            Button(action: run) {
                Text(input.action.title).frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || text.count > 10_000 || isImporting)
        }
    }

    private var workingSection: some View {
        VStack(spacing: 20) {
            ProgressView("Working on your content…")
            Button("Stop") { task?.cancel(); isWorking = false }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    private var resultSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Result ready", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
            Text(result).textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
            Button("View source") { showsSource = true }
            HStack {
                Button(savedID == nil ? "Save" : "Saved", systemImage: savedID == nil ? "bookmark" : "checkmark") { save() }
                    .disabled(savedID != nil)
                Button("Copy", systemImage: "doc.on.doc") { UIPasteboard.general.string = result }
                ShareLink(item: result) { Label("Share", systemImage: "square.and.arrow.up") }
            }
            if let errorMessage { Text(errorMessage).foregroundStyle(.red) }
            Button("Edit original content") { result = ""; savedID = nil }
            Text("AI can miss details. Check the source before using important information.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private func run() {
        let source = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !source.isEmpty, source.count <= 10_000 else { return }
        errorMessage = nil
        isWorking = true
        task = Task { @MainActor in
            do {
                let backend: any ChatBackend
                if appState.prefersFoundationModel && SystemLanguageModel.default.isAvailable {
                    backend = FoundationChatBackend()
                } else {
                    #if targetEnvironment(simulator)
                    throw WorkspaceError.unavailable
                    #else
                    guard appState.downloadedModelIDs.contains(appState.activeModelID) else { throw WorkspaceError.unavailable }
                    let model = try await MLXModelLoader.load(configuration: appState.activeModel.configuration, progressHandler: { _ in })
                    try Task.checkCancellation()
                    backend = LocalMLXChatBackend(model: model, instructions: ChatRequest.defaultSystemPrompt, additionalContext: [:])
                    #endif
                }
                let request = ChatRequest(prompt: prompt(for: source))
                var output = ""
                for try await event in backend.streamResponse(for: request) {
                    try Task.checkCancellation()
                    if case .chunk(let chunk) = event { output += chunk }
                }
                guard !output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw WorkspaceError.emptyResult }
                result = output
            } catch is CancellationError {
                // The input stays available when generation is stopped.
            } catch {
                errorMessage = error.localizedDescription
            }
            isWorking = false
        }
    }

    private func prompt(for source: String) -> String {
        let instruction: String
        switch input.action {
        case .summarize: instruction = "Summarize the essential points. Length: \(detail)."
        case .rewrite: instruction = "Rewrite clearly, preserving meaning. Tone: \(tone). Length: \(detail)."
        case .extract: instruction = "Extract dates, amounts, people, and action items. Mark missing details as Not stated."
        case .understandImage: instruction = "Explain the visible text recognized in this image. Do not claim to see the image itself."
        case .analyzeDocument:
            instruction = question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? "Summarize this document. Quote short supporting passages from the supplied text."
                : "Answer this question using only the supplied document: \(question). Quote short supporting passages. If the answer is absent, say so."
        }
        return "\(instruction)\n\nSOURCE:\n\(source)"
    }

    private func save() {
        guard savedID == nil else { return }
        let item = SavedTaskResult(title: sourceTitle, action: input.action, kind: sourceKind, sourceText: text, resultText: result)
        modelContext.insert(item)
        do {
            try modelContext.save()
            savedID = item.id
        } catch {
            modelContext.delete(item)
            errorMessage = "Couldn’t save this result: \(error.localizedDescription)"
        }
    }
}

private enum WorkspaceError: LocalizedError {
    case unavailable, emptyResult

    var errorDescription: String? {
        switch self {
        case .unavailable: "Local AI isn’t ready. Enable Apple Intelligence or download a local model in Settings."
        case .emptyResult: "No result was generated. Try again."
        }
    }
}

struct SavedTaskResultView: View {
    let item: SavedTaskResult
    @State private var showsSource = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(item.resultText).textSelection(.enabled)
                Button("View source") { showsSource = true }
                HStack {
                    Button("Copy", systemImage: "doc.on.doc") { UIPasteboard.general.string = item.resultText }
                    ShareLink(item: item.resultText) { Label("Share", systemImage: "square.and.arrow.up") }
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle(item.title)
        .sheet(isPresented: $showsSource) {
            NavigationStack {
                ScrollView { Text(item.sourceText).frame(maxWidth: .infinity, alignment: .leading).padding() }
                    .navigationTitle("Source")
                    .toolbar { Button("Done") { showsSource = false } }
            }
        }
    }
}
