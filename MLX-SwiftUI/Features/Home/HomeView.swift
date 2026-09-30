import FoundationModels
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

struct HomeView: View {
    @Environment(AppState.self) private var appState
    @State private var path = NavigationPath()
    @State private var workspace: WorkspaceInput?
    @State private var content = ""
    @State private var pendingAction: HomeAction?
    @State private var showsContentSheet = false
    @State private var showsFileImporter = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var errorMessage: String?
    @State private var isImporting = false
    @State private var sourceKind: WorkspaceSourceKind = .text
    @State private var sourceTitle = "Text"

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    header
                    contentCard
                    LazyVGrid(columns: [.init(.flexible()), .init(.flexible())], spacing: 8) {
                        ForEach(HomeAction.allCases) { action in
                            Button { open(action) } label: { actionCard(action) }
                                .buttonStyle(.plain)
                        }
                    }
                    Text("TRY IT WITH A SAMPLE")
                        .font(.caption2.weight(.bold))
                        .tracking(1.8)
                        .foregroundStyle(.secondary)
                        .padding(.top, 3)
                    samples
                }
                .padding(18)
                .padding(.bottom, 80)
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity)
            }
            .background(Color(uiColor: .systemBackground))
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: String.self) { prompt in
                ChatView(initialPrompt: prompt)
            }
            .navigationDestination(item: $workspace) { input in
                TaskWorkspaceView(input: input)
            }
            .sheet(isPresented: $showsContentSheet) { contentSheet }
            .onChange(of: selectedPhoto) { _, photo in
                guard let photo else { return }
                isImporting = true
                Task {
                    do {
                        guard let data = try await photo.loadTransferable(type: Data.self) else {
                            throw HomeImportError.noText
                        }
                        content = try await HomeContentExtractor.image(from: data)
                        sourceKind = .image
                        sourceTitle = "Selected image"
                        finishImport()
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                    isImporting = false
                    selectedPhoto = nil
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text("STILL")
                    .font(.caption2.weight(.bold))
                    .tracking(2)
                    .foregroundStyle(.secondary)
                Spacer()
                Label(backendStatus, systemImage: backendStatus == "Online fallback" ? "network" : "checkmark.shield")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(backendStatus == "Online fallback" ? .blue : .green)
                    .padding(9)
                    .background(backendStatus == "Online fallback" ? .blue.opacity(0.08) : .green.opacity(0.08), in: Capsule())
            }
            Text("Your content.\nA little clearer.")
                .font(.system(size: 23, weight: .bold, design: .rounded))
                .fixedSize(horizontal: false, vertical: true)
            Text("What would you like to do?")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 4)
    }

    private var backendStatus: String {
        if appState.prefersFoundationModel && SystemLanguageModel.default.isAvailable {
            return "On-device"
        }
        #if targetEnvironment(simulator)
        return "Online fallback"
        #else
        return "On-device MLX"
        #endif
    }

    private var contentCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Start with something").font(.headline)
            Text(content.isEmpty ? "A note, a screenshot, a document.\nChoose what you need next." : String(content.prefix(110)))
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(3)
            Button {
                pendingAction = nil
                showsContentSheet = true
            } label: {
                Label(content.isEmpty ? "Add content" : "Change content", systemImage: "plus")
                    .frame(maxWidth: .infinity)
                    .frame(height: 38)
            }
            .buttonStyle(.borderedProminent)
            .tint(.indigo)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.indigo.opacity(0.15), in: RoundedRectangle(cornerRadius: 20))
    }

    private func actionCard(_ action: HomeAction) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Image(systemName: action.symbol)
                .frame(width: 24, height: 24)
                .background(.indigo.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))
            Text(action.title).font(.caption.weight(.medium))
            Text(action.subtitle)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, minHeight: 55, alignment: .leading)
        .padding(6)
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(.secondary.opacity(0.15)))
    }

    private var samples: some View {
        VStack(spacing: 0) {
            sample("From screenshot to next steps", subtitle: "Find the dates and what needs doing", symbol: "photo") {
                workspace = WorkspaceInput(
                    action: .extract,
                    kind: .image,
                    title: "Sample screenshot",
                    text: "Meeting on Friday, October 9 at 2 PM. Send the draft to Maya by Wednesday, October 7. Alex will review it before the meeting."
                )
            }
            Divider()
            sample("Make sense of meeting notes", subtitle: "Decisions, owners and action items", symbol: "note.text") {
                workspace = WorkspaceInput(
                    action: .extract,
                    kind: .text,
                    title: "Sample meeting notes",
                    text: "We agreed to launch the beta next month. Maya will finalize the copy. Alex will test onboarding. Review progress at Friday's check-in."
                )
            }
        }
        .padding(.horizontal, 13)
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 15))
    }

    private func sample(_ title: String, subtitle: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: symbol)
                    .frame(width: 30, height: 30)
                    .background(.indigo.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.caption)
                    Text(subtitle).font(.caption2).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.caption2)
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var contentSheet: some View {
        NavigationStack {
            Form {
                Section("Paste or type") {
                    TextEditor(text: Binding(
                        get: { content },
                        set: { newValue in
                            content = newValue
                            if !isImporting {
                                sourceKind = .text
                                sourceTitle = "Text"
                            }
                        }
                    ))
                        .frame(minHeight: 130)
                    if content.count > 10_000 {
                        Text("Shorten to 10,000 characters before continuing.")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
                Section("Import") {
                    Button("Choose PDF or text file", systemImage: "doc") {
                        showsFileImporter = true
                    }
                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        Label("Choose photo or screenshot", systemImage: "photo")
                    }
                }
                if isImporting { ProgressView("Reading content…") }
            }
            .navigationTitle("Add content")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { pendingAction = nil; showsContentSheet = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { finishImport() }
                        .disabled(content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isImporting)
                }
            }
        }
        .fileImporter(
            isPresented: $showsFileImporter,
            allowedContentTypes: [.pdf, .plainText, .init(filenameExtension: "md") ?? .plainText]
        ) { result in
            isImporting = true
            Task {
                do {
                    let url = try result.get()
                    content = try await HomeContentExtractor.document(from: url)
                    sourceKind = .document
                    sourceTitle = url.lastPathComponent
                    finishImport()
                } catch {
                    if !((error as NSError).domain == NSCocoaErrorDomain &&
                         (error as NSError).code == NSUserCancelledError) {
                        errorMessage = error.localizedDescription
                    }
                }
                isImporting = false
            }
        }
        .alert("Couldn’t add content", isPresented: Binding(
            get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "Please try again.")
        }
    }

    private func open(_ action: HomeAction) {
        if action == .askAI {
            path.append("")
        } else if content.count > 10_000 {
            pendingAction = action
            showsContentSheet = true
        } else if let workspaceAction = action.workspaceAction {
            workspace = WorkspaceInput(action: workspaceAction, kind: sourceKind, title: sourceTitle, text: content)
        }
    }

    private func finishImport() {
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = HomeImportError.noText.localizedDescription
            return
        }
        guard content.count <= 10_000 else {
            errorMessage = HomeImportError.tooLong.localizedDescription
            return
        }
        showsContentSheet = false
        if let pendingAction, let workspaceAction = pendingAction.workspaceAction {
            workspace = WorkspaceInput(action: workspaceAction, kind: sourceKind, title: sourceTitle, text: content)
            self.pendingAction = nil
        }
    }
}

private enum HomeAction: String, CaseIterable, Identifiable {
    case summarize, rewrite, extract, understandImage, analyzeDocument, askAI

    var id: String { rawValue }
    var title: String {
        switch self {
        case .summarize: "Summarize"
        case .rewrite: "Rewrite"
        case .extract: "Extract"
        case .understandImage: "Read Image Text"
        case .analyzeDocument: "Analyze Document"
        case .askAI: "Ask AI"
        }
    }
    var subtitle: String {
        switch self {
        case .summarize: "Find the essentials"
        case .rewrite: "Say it your way"
        case .extract: "Dates, details & tasks"
        case .understandImage: "Understand visible text"
        case .analyzeDocument: "Answers from your text"
        case .askAI: "A little extra help"
        }
    }
    var symbol: String {
        switch self {
        case .summarize: "text.alignleft"
        case .rewrite: "pencil.line"
        case .extract: "checklist"
        case .understandImage: "text.viewfinder"
        case .analyzeDocument: "doc.text"
        case .askAI: "bubble.left"
        }
    }
    var workspaceAction: WorkspaceAction? {
        WorkspaceAction(rawValue: rawValue)
    }
}
