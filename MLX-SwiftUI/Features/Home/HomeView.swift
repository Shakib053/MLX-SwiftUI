import PhotosUI
import SwiftUI
import UniformTypeIdentifiers
import UIKit

struct HomeView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var colorScheme
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
    @State private var sourceTitle = String(localized: "Text")

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    contentCard
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Quick Actions").font(.title3.bold())
                        Text("Get started with your AI tasks")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    LazyVGrid(columns: [.init(.flexible()), .init(.flexible())], spacing: 12) {
                        ForEach(HomeAction.allCases) { action in
                            Button { open(action) } label: { actionCard(action) }
                                .buttonStyle(.plain)
                        }
                    }
                    HStack {
                        Text("Models").font(.title3.bold())
                        Spacer()
                        Button("Manage models") { appState.selectedTab = .models }
                            .font(.caption)
                    }
                    Button {
                        appState.selectedTab = .models
                    } label: {
                        HStack {
                            Image(systemName: "cpu")
                                .foregroundStyle(AppPalette.accent)
                            VStack(alignment: .leading) {
                                Text(appState.defaultModelName).font(.subheadline.weight(.semibold))
                                Text(appState.hasUsableDefaultModel ? String(localized: "Ready to use") : String(localized: "Choose or download a model"))
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").font(.caption)
                        }
                        .padding(14)
                        .appCard()
                    }
                    .buttonStyle(.plain)
                    Text("TRY IT WITH A SAMPLE")
                        .font(.caption2.weight(.bold))
                        .tracking(1.8)
                        .foregroundStyle(.secondary)
                    samples
                }
                .padding(20)
                .padding(.bottom, 80)
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity)
            }
            .background(AppPalette.background)
            .tint(AppPalette.accent)
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
                        sourceTitle = String(localized: "Selected image")
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
        HStack(spacing: 12) {
            Image(systemName: "cpu")
                .font(.system(size: 32, weight: .medium))
                .foregroundStyle(AppPalette.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text("MLX").font(.title.bold())
                Text("Local AI on Your iPhone")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer(minLength: 4)
            Label(backendStatus, systemImage: appState.hasUsableDefaultModel ? "checkmark.shield.fill" : "exclamationmark.triangle.fill")
                .font(.caption2.weight(.medium))
                .foregroundStyle(appState.hasUsableDefaultModel ? .green : .orange)
                .padding(.horizontal, 10).padding(.vertical, 7)
                .background((appState.hasUsableDefaultModel ? Color.green : Color.orange).opacity(colorScheme == .dark ? 0.16 : 0.1), in: Capsule())
            Button { appState.selectedTab = .settings } label: {
                Image(systemName: "gearshape").font(.title3)
            }
            .accessibilityLabel("Settings")
        }
        .padding(.bottom, 12)
    }

    private var backendStatus: String {
        if appState.usesFoundationModel { return String(localized: "On Device") }
        #if targetEnvironment(simulator)
        return appState.hasUsableDefaultModel ? String(localized: "On Device") : String(localized: "Unavailable")
        #else
        return appState.hasUsableDefaultModel ? String(localized: "On Device") : String(localized: "Set Up AI")
        #endif
    }

    private var contentCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Your device. Local models. Powerful AI.", systemImage: "sparkles")
                .font(.headline)
            Text("Run LLMs directly on your iPhone with MLX. Private, fast and always available.")
                .font(.subheadline)
            if !content.isEmpty {
                Button("Change added content", systemImage: "pencil") {
                    pendingAction = nil
                    showsContentSheet = true
                }
                .font(.caption.weight(.semibold))
            }
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            AppPalette.accentFill,
            in: RoundedRectangle(cornerRadius: 20)
        )
    }

    private func actionCard(_ action: HomeAction) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: action.symbol)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(action.tint)
                    .frame(width: 44, height: 44)
                    .background(action.tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 13))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            Text(action.title).font(.subheadline.weight(.semibold))
            Text(action.subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, minHeight: 110, alignment: .leading)
        .padding(14)
        .appCard()
        .contentShape(RoundedRectangle(cornerRadius: 20))
    }

    private var samples: some View {
        VStack(spacing: 0) {
            sample("From screenshot to next steps", subtitle: "Find dates and what needs doing", symbol: "photo") {
                workspace = WorkspaceInput(
                    action: .extract,
                    kind: .image,
                    title: String(localized: "Sample screenshot"),
                    text: String(localized: "Meeting on Friday, October 9 at 2 PM. Send the draft to Maya by Wednesday, October 7. Alex will review it before the meeting.")
                )
            }
            Divider()
            sample("Make sense of meeting notes", subtitle: "Decisions, owners and action items", symbol: "note.text") {
                workspace = WorkspaceInput(
                    action: .extract,
                    kind: .text,
                    title: String(localized: "Sample meeting notes"),
                    text: String(localized: "We agreed to launch the beta next month. Maya will finalize the copy. Alex will test onboarding. Review progress at Friday's check-in.")
                )
            }
        }
        .padding(.horizontal, 13)
        .appCard()
    }

    private func sample(_ title: LocalizedStringKey, subtitle: LocalizedStringKey, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: symbol)
                    .frame(width: 30, height: 30)
                    .background(AppPalette.accent.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))
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
                                sourceTitle = String(localized: "Text")
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
            Text(errorMessage ?? String(localized: "Please try again."))
        }
    }

    private func open(_ action: HomeAction) {
        if action == .askAI {
            beginChat(with: "")
        } else if content.count > 10_000 {
            pendingAction = action
            showsContentSheet = true
        } else if let workspaceAction = action.workspaceAction {
            workspace = WorkspaceInput(action: workspaceAction, kind: sourceKind, title: sourceTitle, text: content)
        }
    }

    private func beginChat(with prompt: String) {
        path.append(prompt)
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
    case understandImage, analyzeDocument, askAI, summarize, rewrite, extract

    var id: String { rawValue }
    var title: String {
        switch self {
        case .summarize: String(localized: "Summarize")
        case .rewrite: String(localized: "Rewrite")
        case .extract: String(localized: "Extract")
        case .understandImage: String(localized: "Read Image Text")
        case .analyzeDocument: String(localized: "Analyze Document")
        case .askAI: String(localized: "Ask AI")
        }
    }
    var subtitle: String {
        switch self {
        case .summarize: String(localized: "Get the key points instantly")
        case .rewrite: String(localized: "Improve your writing style")
        case .extract: String(localized: "Dates, details & tasks")
        case .understandImage: String(localized: "Extract text from images and photos")
        case .analyzeDocument: String(localized: "Summarize and analyze your documents")
        case .askAI: String(localized: "Chat with your local model")
        }
    }
    var symbol: String {
        switch self {
        case .summarize: "text.alignleft"
        case .rewrite: "pencil.line"
        case .extract: "checklist"
        case .understandImage: "photo"
        case .analyzeDocument: "doc.text"
        case .askAI: "bubble.left"
        }
    }
    var tint: Color { AppPalette.accent }
    var workspaceAction: WorkspaceAction? {
        WorkspaceAction(rawValue: rawValue)
    }
}
