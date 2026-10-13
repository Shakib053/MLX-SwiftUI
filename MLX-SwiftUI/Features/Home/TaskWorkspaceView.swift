import FoundationModels
import PhotosUI
import SwiftData
import SwiftUI
import UniformTypeIdentifiers
import UIKit

enum WorkspaceAction: String, Hashable, CaseIterable {
    case summarize, rewrite, extract, understandImage, analyzeDocument

    var title: String {
        switch self {
        case .summarize: String(localized: "Summarize")
        case .rewrite: String(localized: "Rewrite")
        case .extract: String(localized: "Extract")
        case .understandImage: String(localized: "Read Image Text")
        case .analyzeDocument: String(localized: "Analyze Document")
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
    @Environment(\.colorScheme) private var colorScheme
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
    @State private var showsModelSetup = false
    @State private var continueAfterModelSetup = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showsCamera = false
    @State private var task: Task<Void, Never>?
    @State private var savedID: UUID?
    @State private var summarySource: WorkspaceSourceKind = .text

    var body: some View {
        Group {
            if input.action == .summarize && result.isEmpty && !isWorking {
                summarizeView
            } else if input.action == .extract && result.isEmpty && !isWorking {
                extractView
            } else if input.action == .rewrite && result.isEmpty && !isWorking {
                rewriteView
            } else {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 12) {
                    Image(systemName: input.action == .understandImage ? "photo" : "sparkles")
                        .font(.title2).foregroundStyle(.indigo)
                        .frame(width: 48, height: 48)
                        .background(.indigo.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
                    Text(input.action.title).font(.title.bold())
                }
                if input.action == .understandImage {
                    Text("Extract and understand text from images, screenshots, and photos using local AI models.")
                        .font(.subheadline).foregroundStyle(.secondary)
                }

                if !result.isEmpty { resultSection } else if isWorking { workingSection } else { inputSection }
            }
            .padding(20)
            .frame(maxWidth: 650, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle(input.action.title)
        .navigationBarTitleDisplayMode(.inline)
            }
        }
        .background(HomePalette.background)
        .tint(HomePalette.lavender)
        .onAppear {
            if sourceTitle.isEmpty {
                text = input.text
                sourceTitle = input.title
                sourceKind = input.kind
                summarySource = input.kind
            }
        }
        .onDisappear { task?.cancel() }
        .sheet(isPresented: $showsCamera) {
            CameraPicker { image in
                guard let data = image.jpegData(compressionQuality: 0.9) else { return }
                importImage(data, title: String(localized: "Camera photo"))
            }
        }
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
            Task {
                do {
                    guard let data = try await photo.loadTransferable(type: Data.self) else { throw HomeImportError.noText }
                    importImage(data, title: String(localized: "Selected image"))
                } catch {
                    errorMessage = error.localizedDescription
                }
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
        #if !targetEnvironment(simulator)
        .sheet(isPresented: $showsModelSetup, onDismiss: {
            guard continueAfterModelSetup else { return }
            continueAfterModelSetup = false
            if appState.hasUsableDefaultModel { run() }
        }, content: {
            ModelSetupView()
                .environment(appState)
        })
        #endif
    }

    private var extractView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                workspaceHeader(title: "Extract", subtitle: "Turn your text into structured information with AI.")

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("SOURCE TEXT")
                            .font(.caption2.weight(.bold))
                            .tracking(1)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button {
                            if let pasted = UIPasteboard.general.string { text = pasted }
                        } label: {
                            Label("Paste", systemImage: "doc.on.clipboard")
                                .font(.caption.weight(.medium))
                        }
                        .buttonStyle(.bordered)
                        .tint(HomePalette.lavender)
                    }
                    sourceTextEditor(placeholder: "Paste text to extract key information...", accessibilityLabel: "Text to extract")
                        .frame(height: 210)
                    characterCount
                }

                Button(action: run) {
                    Label("Extract", systemImage: "sparkles")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .tint(HomePalette.lavender)
                .disabled(!canRun)

                Label("Extract names, dates, key points, and more.", systemImage: "lightbulb")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(HomePalette.lavender.opacity(0.07), in: RoundedRectangle(cornerRadius: 16))

                if let errorMessage { Text(errorMessage).foregroundStyle(.red) }
                #if !targetEnvironment(simulator)
                if !appState.hasUsableDefaultModel {
                    Button("Choose a model") { showsModelSetup = true }
                }
                #endif
            }
            .padding(20)
            .frame(maxWidth: 650)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("Extract")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var summarizeView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                workspaceHeader(title: "Summarize", subtitle: "Turn long text into a clear, short summary, privately on your iPhone.")

                HStack(spacing: 4) {
                    summaryTab(.text, title: "Text", symbol: "doc.text")
                    summaryTab(.document, title: "Document", symbol: "folder")
                    summaryTab(.image, title: "Image", symbol: "photo")
                }
                .padding(5)
                .background(colorScheme == .dark ? HomePalette.card : HomePalette.lavender.opacity(0.07), in: RoundedRectangle(cornerRadius: 18))

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(summarySource == .text ? "SOURCE TEXT" : summarySource == .document ? "DOCUMENT" : "IMAGE")
                            .font(.caption2.weight(.bold))
                            .tracking(1)
                            .foregroundStyle(.secondary)
                        Spacer()
                        if summarySource == .text {
                            Button {
                                if let pasted = UIPasteboard.general.string { text = pasted }
                            } label: {
                                Label("Paste", systemImage: "doc.on.clipboard")
                                    .font(.caption.weight(.medium))
                            }
                            .buttonStyle(.bordered)
                            .tint(HomePalette.lavender)
                        }
                    }
                    if summarySource == .text {
                        sourceTextEditor(placeholder: "Paste text to summarize...", accessibilityLabel: "Text to summarize")
                            .frame(height: 210)
                    } else if summarySource == .document {
                        VStack(alignment: .leading, spacing: 14) {
                            if !text.isEmpty {
                                Label(sourceTitle, systemImage: "doc.text").lineLimit(1)
                                Button("View source") { showsSource = true }
                            }
                            Button("Choose document", systemImage: "doc.badge.plus") { showsFileImporter = true }
                                .buttonStyle(.borderedProminent)
                                .tint(HomePalette.lavender)
                        }
                        .frame(maxWidth: .infinity, minHeight: 170, alignment: .center)
                        .padding(16)
                        .background(HomePalette.card, in: RoundedRectangle(cornerRadius: 16))
                    } else {
                        summaryImagePicker
                            .padding(16)
                            .background(HomePalette.card, in: RoundedRectangle(cornerRadius: 16))
                    }
                    characterCount
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Summary length").font(.headline)
                    HStack(spacing: 10) {
                        lengthCard("Short", title: "Short", subtitle: "Key points only", symbol: "text.alignleft")
                        lengthCard("Detailed", title: "Detailed", subtitle: "Full summary", symbol: "text.book.closed")
                    }
                }

                Button(action: run) {
                    Label("Generate summary", systemImage: "sparkles")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .tint(HomePalette.lavender)
                .disabled(!canRun)

                if isImporting { ProgressView("Reading content…") }
                if let errorMessage { Text(errorMessage).foregroundStyle(.red) }
                #if !targetEnvironment(simulator)
                if !appState.hasUsableDefaultModel {
                    Button("Choose a model") { showsModelSetup = true }
                }
                #endif
            }
            .padding(20)
            .frame(maxWidth: 650)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("Summarize")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var rewriteView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                workspaceHeader(title: "Rewrite", subtitle: "Make your text clearer, shorter, more professional, or in a different style.")

                ZStack(alignment: .topLeading) {
                    TextEditor(text: $text)
                        .padding(.horizontal, 12)
                        .padding(.top, 12)
                        .padding(.bottom, 36)
                        .scrollContentBackground(.hidden)
                        .accessibilityLabel("Text to rewrite")
                    if text.isEmpty {
                        Text("Paste your text here...\n(e.g. email, message, article, or any text)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 18)
                            .padding(.top, 21)
                            .allowsHitTesting(false)
                    }
                    HStack(spacing: 8) {
                        Image(systemName: "doc.text")
                        characterCount
                        Spacer()
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(16)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                    .allowsHitTesting(false)
                }
                .frame(height: 220)
                .background(HomePalette.card.opacity(colorScheme == .dark ? 1 : 0.55), in: RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(HomePalette.border))

                Picker("Tone", selection: $tone) {
                    Text("Professional").tag("Professional")
                    Text("Friendly").tag("Friendly")
                    Text("Direct").tag("Direct")
                }
                Picker("Length", selection: $detail) {
                    Text("Short").tag("Short")
                    Text("Detailed").tag("Detailed")
                }

                Button(action: run) {
                    Label("Rewrite", systemImage: "sparkles")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .tint(HomePalette.lavender)
                .disabled(!canRun)

                if let errorMessage { Text(errorMessage).foregroundStyle(.red) }
                #if !targetEnvironment(simulator)
                if !appState.hasUsableDefaultModel {
                    Button("Choose a model") { showsModelSetup = true }
                }
                #endif
            }
            .padding(20)
            .frame(maxWidth: 650)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("Rewrite")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var canRun: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && text.count <= 10_000 && !isImporting && appState.hasUsableDefaultModel
    }

    private var characterCount: some View {
        Text("\(text.count.formatted()) / 10,000 characters")
            .font(.caption)
            .foregroundStyle(text.count > 10_000 ? .red : .secondary)
    }

    private func workspaceHeader(title: LocalizedStringKey, subtitle: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: "sparkles")
                .font(.title2)
                .foregroundStyle(HomePalette.lavender)
                .frame(width: 56, height: 56)
                .background(HomePalette.lavender.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.title.bold())
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func sourceTextEditor(placeholder: LocalizedStringKey, accessibilityLabel: LocalizedStringKey) -> some View {
        ZStack {
            if text.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 36, weight: .light))
                        .foregroundStyle(HomePalette.lavender.opacity(0.7))
                    Text(placeholder)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("Text stays on your device.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .multilineTextAlignment(.center)
                .allowsHitTesting(false)
            }
            TextEditor(text: $text)
                .padding(12)
                .scrollContentBackground(.hidden)
                .opacity(text.isEmpty ? 0.12 : 1)
                .accessibilityLabel(accessibilityLabel)
        }
        .background(HomePalette.card.opacity(colorScheme == .dark ? 1 : 0.55), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(HomePalette.border))
    }

    private func summaryTab(_ kind: WorkspaceSourceKind, title: LocalizedStringKey, symbol: String) -> some View {
        Button {
            summarySource = kind
            text = ""
            sourceTitle = ""
            sourceKind = kind
        } label: {
            Label(title, systemImage: symbol)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(summarySource == kind ? HomePalette.lavender : Color.clear, in: RoundedRectangle(cornerRadius: 16))
                .foregroundStyle(summarySource == kind ? Color.white : Color.primary)
        }
        .buttonStyle(.plain)
    }

    private var summaryImagePicker: some View {
        VStack(spacing: 16) {
            if text.isEmpty {
                Image(systemName: "photo.badge.plus")
                    .font(.system(size: 42))
                    .foregroundStyle(HomePalette.lavender)
                    .frame(width: 88, height: 88)
                    .background(HomePalette.lavender.opacity(0.1), in: Circle())
                VStack(spacing: 4) {
                    Text("Add an image").font(.title3.bold())
                    Text("Choose from Photos or capture with Camera.")
                        .font(.subheadline).foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            } else {
                HStack(spacing: 12) {
                    Image(systemName: "text.viewfinder")
                        .font(.title2)
                        .foregroundStyle(HomePalette.lavender)
                        .frame(width: 56, height: 56)
                        .background(HomePalette.lavender.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(sourceTitle).font(.headline).lineLimit(1)
                        Label("\(text.count) characters found", systemImage: "checkmark")
                            .font(.caption).foregroundStyle(.green)
                    }
                    Spacer(minLength: 0)
                }
            }
            HStack(spacing: 10) {
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    Label(text.isEmpty ? String(localized: "Choose Photo") : String(localized: "Replace"), systemImage: text.isEmpty ? "photo" : "arrow.triangle.2.circlepath")
                        .frame(maxWidth: .infinity)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .frame(maxWidth: .infinity)
                .buttonStyle(.borderedProminent)
                .tint(HomePalette.lavender)
                if text.isEmpty {
                    Button {
                        showsCamera = true
                    } label: {
                        Label("Take Photo", systemImage: "camera")
                            .frame(maxWidth: .infinity)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                    .buttonStyle(.bordered)
                    .disabled(!UIImagePickerController.isSourceTypeAvailable(.camera))
                } else {
                    Button(role: .destructive) {
                        text = ""
                        sourceTitle = ""
                        sourceKind = .image
                    } label: {
                        Label("Remove", systemImage: "trash")
                            .frame(maxWidth: .infinity)
                    }
                    .frame(maxWidth: .infinity)
                    .buttonStyle(.bordered)
                }
            }
            if !text.isEmpty {
                Button("View extracted text") { showsSource = true }
                    .font(.subheadline)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, text.isEmpty ? 20 : 0)
    }

    private func lengthCard(_ value: String, title: LocalizedStringKey, subtitle: LocalizedStringKey, symbol: String) -> some View {
        Button { detail = value } label: {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: symbol).foregroundStyle(HomePalette.lavender)
                Spacer(minLength: 8)
                Text(title).font(.headline)
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 90, alignment: .leading)
            .padding(14)
            .background(
                detail == value
                    ? HomePalette.lavender.opacity(colorScheme == .dark ? 0.25 : 0.12)
                    : (colorScheme == .dark ? HomePalette.background : Color.clear),
                in: RoundedRectangle(cornerRadius: 16)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(
                        detail == value
                            ? HomePalette.lavender
                            : (colorScheme == .dark ? HomePalette.border : Color.secondary.opacity(0.25))
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            #if !targetEnvironment(simulator)
            if !appState.foundationModelAvailable && appState.downloadedModels.isEmpty {
                Label("Set up on-device AI to use this tool", systemImage: "cpu")
                Button("Choose a model") {
                    continueAfterModelSetup = true
                    showsModelSetup = true
                }
                    .buttonStyle(.borderedProminent)
            }
            #endif
            if sourceKind != .text && !text.isEmpty {
                Label(sourceTitle, systemImage: sourceKind == .document ? "doc.text" : "text.viewfinder")
                Button("View source") { showsSource = true }
            }
            if input.action == .understandImage && text.isEmpty {
                imageChooser
            }
            TextEditor(text: $text)
                .frame(minHeight: input.action == .understandImage ? 120 : 180)
                .padding(8)
                .scrollContentBackground(.hidden)
                .background(colorScheme == .dark ? HomePalette.card : Color(uiColor: .quaternarySystemFill), in: RoundedRectangle(cornerRadius: 12))
                .accessibilityLabel("Source text")
            Text("\(text.count) / 10,000 characters")
                .font(.caption).foregroundStyle(text.count > 10_000 ? .red : .secondary)

            if input.action == .understandImage {
                if !text.isEmpty {
                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        Label("Choose another photo", systemImage: "photo")
                    }
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
                    Text("Professional").tag("Professional")
                    Text("Friendly").tag("Friendly")
                    Text("Direct").tag("Direct")
                }
            }
            if input.action == .summarize || input.action == .rewrite {
                Picker("Length", selection: $detail) {
                    Text("Short").tag("Short")
                    Text("Detailed").tag("Detailed")
                }
            }
            if isImporting { ProgressView("Reading content…") }
            if let errorMessage {
                Text(errorMessage).foregroundStyle(.red)
                Button("Try again") { self.errorMessage = nil }
                #if !targetEnvironment(simulator)
                if !appState.foundationModelAvailable {
                    Button("Choose another model") { showsModelSetup = true }
                }
                #endif
            }
            Button(action: run) {
                Text(input.action.title).frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || text.count > 10_000 || isImporting || !appState.hasUsableDefaultModel)
        }
    }

    private var imageChooser: some View {
        VStack(spacing: 14) {
            Image(systemName: "photo.badge.plus")
                .font(.system(size: 44)).foregroundStyle(.indigo)
            Text("Choose an image").font(.headline)
            Text("Select from your gallery or take a new photo")
                .font(.subheadline).foregroundStyle(.secondary)
            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                Label(String(localized: "Choose Photo"), systemImage: "photo")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.indigo)
            .padding(.top, 8)
            Text("OR").font(.caption).foregroundStyle(.secondary)
            Button {
                showsCamera = true
            } label: {
                Label("Take Photo", systemImage: "camera")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(!UIImagePickerController.isSourceTypeAvailable(.camera))
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(colorScheme == .dark ? HomePalette.card : Color.indigo.opacity(0.05), in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(.indigo.opacity(0.15), style: StrokeStyle(lineWidth: 1, dash: [5])))
    }

    private func importImage(_ data: Data, title: String) {
        isImporting = true
        Task {
            do {
                text = try await HomeContentExtractor.image(from: data)
                sourceTitle = title
                sourceKind = .image
                errorMessage = nil
            } catch {
                errorMessage = error.localizedDescription
            }
            isImporting = false
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
            Label("Result ready", systemImage: "checkmark.circle.fill")
                .foregroundStyle(input.action == .summarize ? .blue : .green)
            Text(result).textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(colorScheme == .dark ? HomePalette.card : Color(uiColor: .quaternarySystemFill), in: RoundedRectangle(cornerRadius: 12))
            Button("View source") { showsSource = true }
            HStack {
                Button(savedID == nil ? String(localized: "Save") : String(localized: "Saved"), systemImage: savedID == nil ? "bookmark" : "checkmark") { save() }
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
            errorMessage = String(localized: "Couldn’t save this result: \(error.localizedDescription)")
        }
    }
}

private enum WorkspaceError: LocalizedError {
    case unavailable, emptyResult

    var errorDescription: String? {
        switch self {
        case .unavailable: String(localized: "Local AI isn’t ready. Enable Apple Intelligence or download a local model in Settings.")
        case .emptyResult: String(localized: "No result was generated. Try again.")
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
        .background(HomePalette.background)
        .sheet(isPresented: $showsSource) {
            NavigationStack {
                ScrollView { Text(item.sourceText).frame(maxWidth: .infinity, alignment: .leading).padding() }
                    .navigationTitle("Source")
                    .toolbar { Button("Done") { showsSource = false } }
            }
        }
    }
}

private struct CameraPicker: UIViewControllerRepresentable {
    let onImage: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ controller: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: CameraPicker
        init(_ parent: CameraPicker) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage { parent.onImage(image) }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { parent.dismiss() }
    }
}
