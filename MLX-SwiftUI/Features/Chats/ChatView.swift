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
    @State private var isFollowingBottom = true
    @State private var scrollPhase: ScrollPhase = .idle
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

            if viewModel.state == .ready || !viewModel.messages.isEmpty {
                // An in-progress conversation keeps its transcript visible while
                // a model loads (initial open or mid-chat switch); the inline
                // status strip in `conversationView` surfaces the progress.
                conversationView
            } else {
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
                        showsHostedOption: ChatEnvironment.supportsHostedChat,
                        style: style
                    ) {
                        Task { await viewModel.useHostedFallback() }
                    }
                case .failed(let message):
                    ChatErrorView(
                        message: message,
                        showsHostedOption: ChatEnvironment.supportsHostedChat,
                        style: style
                    ) {
                        viewModel.retryDownload()
                    } useHostedFallback: {
                        Task { await viewModel.useHostedFallback() }
                    }
                case .ready:
                    EmptyView()
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
        .alert("Couldn’t save conversation", isPresented: Binding(
            get: { viewModel.persistenceError != nil },
            set: { if !$0 { viewModel.persistenceError = nil } }
        )) {
            Button("OK", role: .cancel) { viewModel.persistenceError = nil }
        } message: {
            Text(viewModel.persistenceError ?? "Please try again.")
        }
        .task {
            await viewModel.start(
                activeModel: appState.activeModel,
                downloadedModelIDs: appState.downloadedModelIDs,
                context: modelContext
            )
            if appState.activeModelID != viewModel.currentModel.id {
                // The conversation restored its own model; sync the global
                // selection so the picker and UserDefaults agree. The change
                // observer no-ops because the view model already uses it.
                appState.activate(viewModel.currentModel)
            }
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
                         : "\(viewModel.currentModel.shortName) • On device")
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
        }

        if viewModel.hasConversation {
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

            if viewModel.historyLimitReached {
                Label(
                    "Older messages were removed to keep this chat within the device limit.",
                    systemImage: "info.circle"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
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
                                showsModelLabel: showsModelLabels,
                                style: style
                            ) {
                                _ = viewModel.regenerateLastResponse()
                            }
                            .id(message.id)
                        }
                    }
                    .padding(16)
                }
                .onAppear {
                    guard !viewModel.messages.isEmpty else { return }
                    scrollToLatestMessage(with: proxy, animated: false)
                }
                .onScrollGeometryChange(for: Bool.self) { geometry in
                    geometry.isNearBottom
                } action: { _, isNearBottom in
                    if isNearBottom {
                        isFollowingBottom = true
                    } else if scrollPhase != .idle && scrollPhase != .animating {
                        // Content growing between updates briefly leaves the bottom;
                        // only a user-driven scroll should abandon the response.
                        isFollowingBottom = false
                    }
                }
                .onScrollPhaseChange { _, newPhase in
                    scrollPhase = newPhase
                }
                .onChange(of: viewModel.messages.count) { _, _ in
                    guard viewModel.isSending else { return }
                    isFollowingBottom = true
                    scrollToLatestMessage(with: proxy, animated: true)
                }
                .onChange(of: viewModel.messages.last?.text) { _, _ in
                    guard isFollowingBottom else { return }
                    scrollToLatestMessage(with: proxy, animated: false)
                }
                .onChange(of: viewModel.isSending) { wasSending, isSending in
                    guard wasSending, !isSending else { return }
                    resetComposerAndFocus()
                    if isFollowingBottom {
                        scrollToLatestMessage(with: proxy, animated: true)
                    }
                }
            }

            if isSwitchingModel {
                ChatModelSwitchStatusView(
                    state: viewModel.state,
                    modelName: viewModel.currentModel.shortName,
                    progress: viewModel.downloadProgress,
                    retry: {
                        viewModel.retryDownload()
                    },
                    useHostedFallback: {
                        Task { await viewModel.useHostedFallback() }
                    }
                )
            }

            ChatComposer(
                text: $composerText,
                activeModel: viewModel.currentModel,
                backendMode: viewModel.backendMode,
                isSending: viewModel.isSending,
                isSwitchingModel: viewModel.state != .ready,
                isFocused: $isComposerFocused,
                style: style,
                showModelPicker: { showsModelPicker = true },
                send: sendCurrentPrompt
            )
            .id(composerID)
        }
        .onAppear {
            isComposerFocused = true
        }
    }

    private var isSwitchingModel: Bool {
        viewModel.state != .ready && !viewModel.messages.isEmpty
    }

    /// Model labels appear on assistant bubbles only once a conversation mixes
    /// replies from more than one recorded model.
    private var showsModelLabels: Bool {
        let recordedModelIDs = Set(
            viewModel.messages
                .filter { $0.role == .assistant }
                .map(\.modelID)
                .filter { !$0.isEmpty }
        )
        return recordedModelIDs.count > 1
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

    private func scrollToLatestMessage(with proxy: ScrollViewProxy, animated: Bool) {
        guard let lastID = viewModel.messages.last?.id else { return }

        if animated {
            withAnimation(.easeOut(duration: 0.2)) {
                proxy.scrollTo(lastID, anchor: .bottom)
            }
        } else {
            proxy.scrollTo(lastID, anchor: .bottom)
        }
    }
}

/// Compact strip shown above the composer while a conversation keeps its
/// transcript visible during a model load or mid-chat model switch.
private struct ChatModelSwitchStatusView: View {
    let state: ChatState
    let modelName: String
    let progress: Double
    let retry: () -> Void
    let useHostedFallback: () -> Void

    private var hasFailed: Bool {
        if case .failed = state { return true }
        return false
    }

    var body: some View {
        HStack(spacing: 8) {
            if hasFailed {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text("\(modelName) could not load")
                    .font(.caption)
                Spacer()
                Button("Retry", action: retry)
                    .font(.caption.weight(.semibold))
            } else {
                if state == .downloading, progress > 0 {
                    ProgressView(value: progress)
                        .frame(width: 120)
                } else {
                    ProgressView()
                        .controlSize(.small)
                }
                Text(state == .downloading ? "Downloading \(modelName)…" : "Loading \(modelName)…")
                    .font(.caption)
                Spacer()
            }

            // Preserve the hosted-fallback escape hatch the full-screen
            // download/error views offer (simulator only).
            if ChatEnvironment.supportsHostedChat {
                Button("Chat Online", action: useHostedFallback)
                    .font(.caption.weight(.semibold))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }
}

private extension ScrollGeometry {
    var isNearBottom: Bool {
        let distanceFromBottom = contentSize.height
            - contentOffset.y
            - visibleRect.height
            + contentInsets.bottom
        return distanceFromBottom <= 120
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
