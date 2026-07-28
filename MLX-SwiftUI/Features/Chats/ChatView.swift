import SwiftUI
import SwiftData

struct ChatView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: ChatViewModel
    @State private var composerText = ""
    @State private var composerID = UUID()
    @State private var showsModelPicker = false
    @State private var showsDeleteConfirmation = false
    @FocusState private var isComposerFocused: Bool
    private let viewID: UUID

    init(conversationID: UUID? = nil, viewID: UUID = UUID()) {
        self.viewID = viewID
        _viewModel = State(initialValue: ChatViewModel(conversationID: conversationID))
    }

    private var style: ChatVisualStyle {
        ChatVisualStyle(colorScheme: colorScheme)
    }

    var body: some View {
        ZStack {
            style.background

            switch viewModel.state {
            case .loading:
                ChatLoadingView(
                    title: viewModel.loadingTitle,
                    message: viewModel.loadingMessage,
                    style: style
                )
            case .downloading:
                ChatDownloadView(
                    title: viewModel.loadingTitle,
                    message: viewModel.loadingMessage,
                    progress: viewModel.downloadProgress,
                    fallbackError: viewModel.fallbackError,
                    isConnecting: viewModel.isConnectingToFallback,
                    style: style
                ) {
                    Task { await viewModel.useHostedFallback() }
                }
            case .ready:
                conversationView
            case .failed(let message):
                ChatErrorView(message: message, style: style) {
                    viewModel.retryDownload()
                } useHostedFallback: {
                    Task { await viewModel.useHostedFallback() }
                }
            }
        }
        .navigationTitle(viewModel.conversationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(colorScheme, for: .navigationBar)
        .toolbar {
            conversationToolbar
        }
        .sheet(isPresented: $showsModelPicker) {
            ChatModelPicker(isPresented: $showsModelPicker)
                .environment(appState)
        }
        .alert("Delete this conversation?", isPresented: $showsDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                viewModel.deleteConversation()
                dismiss()
            }
        } message: {
            Text("This permanently deletes the conversation and its messages from this device.")
        }
        .alert("Rename Conversation", isPresented: Binding(
            get: { viewModel.isRenaming },
            set: { viewModel.isRenaming = $0 }
        )) {
            TextField("Conversation title", text: Binding(
                get: { viewModel.renameText },
                set: { viewModel.renameText = $0 }
            ))
            Button("Cancel", role: .cancel) { viewModel.cancelRenaming() }
            Button("Save") { viewModel.saveRenamedConversation() }
        }
        .task {
            await viewModel.start(model: appState.activeModel, context: modelContext)
        }
        .onChange(of: appState.activeModelID) { _, newModelID in
            guard let model = LocalModel.catalog.first(where: { $0.id == newModelID }) else { return }
            viewModel.switchModel(to: model)
        }
        .id(viewID)
    }

    @ToolbarContentBuilder
    private var conversationToolbar: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            VStack(spacing: 1) {
                Text(viewModel.conversationTitle)
                    .font(.headline)
                HStack(spacing: 4) {
                    Circle()
                        .fill(viewModel.backendMode == .hosted ? .blue : .green)
                        .frame(width: 6, height: 6)
                    Text(viewModel.backendMode == .hosted
                         ? "Hugging Face • Online"
                         : "\(appState.activeModel.shortName) • On device")
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
        }

        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button {
                    viewModel.beginRenaming()
                } label: {
                    Label("Rename", systemImage: "pencil")
                }
                Button {
                    viewModel.togglePin()
                } label: {
                    Label(
                        viewModel.isPinned ? "Unpin" : "Pin",
                        systemImage: viewModel.isPinned ? "pin.slash" : "pin"
                    )
                }
                .disabled(viewModel.conversationTitle == "New Conversation")
                Button(role: .destructive) {
                    showsDeleteConfirmation = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
            }
            .accessibilityLabel("Conversation options")
        }
    }

    private var conversationView: some View {
        VStack(spacing: 0) {
            if viewModel.backendMode == .hosted,
               viewModel.isLocalModelReady || viewModel.downloadError != nil {
                ChatLocalModelStatusBanner(
                    isReady: viewModel.isLocalModelReady,
                    hasError: viewModel.downloadError != nil
                ) {
                    viewModel.retryDownload()
                }
            }

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        if viewModel.messages.isEmpty {
                            ChatConversationEmptyState(backendMode: viewModel.backendMode)
                        }
                        ForEach(viewModel.messages) { message in
                            ChatMessageRow(
                                message: message,
                                isSending: viewModel.isSending,
                                isLastMessage: message.id == viewModel.messages.last?.id,
                                style: style
                            ) {
                                _ = viewModel.regenerateLastResponse()
                            }
                            .id(message.id)
                        }
                    }
                    .padding(16)
                }
                .onChange(of: viewModel.messages.count) { _, _ in
                    scrollToLatestMessage(with: proxy)
                }
                .onChange(of: viewModel.messages.last?.text) { _, _ in
                    scrollToLatestMessage(with: proxy)
                }
            }

            ChatComposer(
                text: $composerText,
                activeModel: appState.activeModel,
                backendMode: viewModel.backendMode,
                isSending: viewModel.isSending,
                isFocused: $isComposerFocused,
                style: style,
                showModelPicker: { showsModelPicker = true },
                send: sendCurrentPrompt
            )
            .id(composerID)
            .onChange(of: viewModel.isSending) { wasSending, isSending in
                if wasSending && !isSending {
                    resetComposerAndFocus()
                }
            }
        }
        .onAppear {
            isComposerFocused = true
        }
    }

    private func sendCurrentPrompt() {
        let prompt = composerText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard viewModel.sendPrompt(prompt) else { return }

        isComposerFocused = false
        composerText = ""
        composerID = UUID()
    }

    private func resetComposerAndFocus() {
        composerText = ""
        composerID = UUID()
        Task { @MainActor in
            await Task.yield()
            isComposerFocused = true
        }
    }

    private func scrollToLatestMessage(with proxy: ScrollViewProxy) {
        guard let lastID = viewModel.messages.last?.id else { return }

        withAnimation(.easeOut(duration: 0.2)) {
            proxy.scrollTo(lastID, anchor: .bottom)
        }
    }
}

#Preview("Light") {
    NavigationStack {
        ChatView()
    }
    .environment(AppState())
    .preferredColorScheme(.light)
}

#Preview("Dark") {
    NavigationStack {
        ChatView()
    }
    .environment(AppState())
    .preferredColorScheme(.dark)
}
