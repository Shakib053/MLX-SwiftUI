import SwiftData
import SwiftUI

struct ChatsView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Conversation.updatedAt, order: .reverse) private var conversations: [Conversation]
    @Query(sort: \SavedTaskResult.createdAt, order: .reverse) private var savedResults: [SavedTaskResult]
    @State private var searchText = ""
    @State private var conversationToDelete: Conversation?
    @State private var persistenceError: String?
    @State private var resultToDelete: SavedTaskResult?
    @State private var startsNewChat = false
    @FocusState private var isSearchFocused: Bool

    private var filteredResults: [SavedTaskResult] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return savedResults }
        return savedResults.filter {
            $0.title.localizedCaseInsensitiveContains(query) ||
            $0.resultText.localizedCaseInsensitiveContains(query) ||
            $0.sourceText.localizedCaseInsensitiveContains(query)
        }
    }

    private var filteredConversations: [Conversation] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return conversations }
        return conversations.filter { conversation in
            conversation.title.localizedCaseInsensitiveContains(query) ||
            conversation.messages.contains {
                $0.text.localizedCaseInsensitiveContains(query)
            }
        }
    }

    private var pinnedConversations: [Conversation] {
        filteredConversations.filter(\.isPinned)
    }

    private var recentConversations: [Conversation] {
        filteredConversations.filter { !$0.isPinned }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    searchField

                    if filteredConversations.isEmpty && filteredResults.isEmpty {
                        emptyState
                            .simultaneousGesture(TapGesture().onEnded { isSearchFocused = false })
                    } else {
                        if !filteredResults.isEmpty {
                            savedResultSection
                                .simultaneousGesture(TapGesture().onEnded { isSearchFocused = false })
                        }
                        conversationSections
                            .simultaneousGesture(TapGesture().onEnded { isSearchFocused = false })
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
            .background {
                AppBackground()
                    .onTapGesture { isSearchFocused = false }
            }
            .navigationTitle("History")
            .onChange(of: appState.selectedTab) { _, selectedTab in
                if selectedTab != .history { isSearchFocused = false }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        startNewChat()
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Start new conversation")
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { isSearchFocused = false }
                }
            }
            .navigationDestination(isPresented: $startsNewChat) {
                ChatView(viewID: UUID())
            }
            .alert("Delete Conversation?", isPresented: Binding(
                get: { conversationToDelete != nil },
                set: { if !$0 { conversationToDelete = nil } }
            )) {
                Button("Cancel", role: .cancel) { conversationToDelete = nil }
                Button("Delete", role: .destructive) {
                    if let conversationToDelete {
                        modelContext.delete(conversationToDelete)
                        saveChanges()
                    }
                    self.conversationToDelete = nil
                }
            } message: {
                Text("This permanently deletes the conversation and its messages from this device.")
            }
            .alert("Couldn’t update conversations", isPresented: Binding(
                get: { persistenceError != nil },
                set: { if !$0 { persistenceError = nil } }
            )) {
                Button("OK", role: .cancel) { persistenceError = nil }
            } message: {
                Text(persistenceError ?? String(localized: "Please try again."))
            }
            .alert("Delete Saved Result?", isPresented: Binding(
                get: { resultToDelete != nil },
                set: { if !$0 { resultToDelete = nil } }
            )) {
                Button("Cancel", role: .cancel) { resultToDelete = nil }
                Button("Delete", role: .destructive) {
                    if let resultToDelete { modelContext.delete(resultToDelete); saveChanges() }
                    resultToDelete = nil
                }
            } message: {
                Text("This removes the saved result and its source from this device.")
            }
        }
    }

    private var savedResultSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("SAVED RESULTS")
            ForEach(filteredResults) { item in
                NavigationLink {
                    SavedTaskResultView(item: item)
                } label: {
                    HStack {
                        Image(systemName: "bookmark")
                        VStack(alignment: .leading) {
                            Text(item.title).font(.headline)
                            Text(WorkspaceAction(rawValue: item.actionRawValue)?.title ?? String(localized: "Result"))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                    .padding()
                    .appCard()
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button("Delete", role: .destructive) { resultToDelete = item }
                }
            }
        }
    }

    private var conversationSections: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !pinnedConversations.isEmpty {
                sectionHeader("PINNED")
                conversationList(pinnedConversations)
            }

            if !recentConversations.isEmpty {
                sectionHeader("RECENT", showsClear: true)
                conversationList(recentConversations)
            }
        }
    }

    private func sectionHeader(_ title: LocalizedStringKey, showsClear: Bool = false) -> some View {
        HStack {
            Text(title)
                .font(.caption.weight(.bold))
                .tracking(1.1)
                .foregroundStyle(.secondary)
            Spacer()
            if showsClear {
                Button("Clear") {
                    for conversation in recentConversations {
                        modelContext.delete(conversation)
                    }
                    saveChanges()
                }
                .font(.subheadline)
                .foregroundStyle(AppPalette.accent)
            }
        }
        .padding(.horizontal, 2)
    }

    private func conversationList(_ items: [Conversation]) -> some View {
        LazyVStack(spacing: 0) {
            ForEach(items) { conversation in
                NavigationLink {
                    ChatView(conversationID: conversation.id)
                } label: {
                    ConversationRow(conversation: conversation)
                }
                .buttonStyle(.plain)
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        delete(conversation)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                .contextMenu {
                    Button(role: .destructive) {
                        conversationToDelete = conversation
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }

                if conversation.id != items.last?.id {
                    Divider().padding(.leading, 70)
                }
            }
        }
        .appCard()
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func delete(_ conversation: Conversation) {
        modelContext.delete(conversation)
        saveChanges()
    }

    private func saveChanges() {
        do {
            try modelContext.save()
        } catch {
            persistenceError = error.localizedDescription
        }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search history", text: $searchText)
                .focused($isSearchFocused)
                .textInputAutocapitalization(.never)
                .submitLabel(.search)
                .onSubmit { isSearchFocused = false }
        }
        .padding(.horizontal, 14)
        .frame(height: 44)
        .background(AppPalette.card, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(AppPalette.border)
                .allowsHitTesting(false)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(AppPalette.accent.opacity(0.12))
                    .frame(width: 92, height: 92)
                Image(systemName: "bubble.left.and.text.bubble.right")
                    .font(.system(size: 38, weight: .medium))
                    .foregroundStyle(AppPalette.accent)
            }

            VStack(spacing: 7) {
                Text(searchText.isEmpty ? String(localized: "No History") : String(localized: "No Results"))
                    .font(.title2.weight(.bold))
                Text(searchText.isEmpty
                     ? String(localized: "Saved results and conversations will appear here.")
                     : String(localized: "There are no saved results or conversations matching “\(searchText)”."))
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button {
                startNewChat()
            } label: {
                Label("New Conversation", systemImage: "plus")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
            }
            .appPrimaryButton()
            .accessibilityHint("Opens a new chat using your preferred model")

            Label(preferredModelStatus, systemImage: preferredModelSymbol)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .padding(28)
        .frame(maxWidth: 440)
        .appCard()
        .padding(.top, 40)
    }

    private func startNewChat() {
        startsNewChat = true
    }

    private var preferredModelStatus: String {
        if appState.usesFoundationModel { return String(localized: "Apple Foundation Models • On device") }
        #if targetEnvironment(simulator)
        return appState.foundationModelAvailable
            ? String(localized: "Apple Foundation Models fallback • On device")
            : String(localized: "No model available in Simulator")
        #else
        return appState.prefersFoundationModel
            ? String(localized: "Foundation Models unavailable • \(appState.activeModel.shortName) fallback")
            : String(localized: "\(appState.activeModel.shortName) • On device")
        #endif
    }

    private var preferredModelSymbol: String {
        appState.usesFoundationModel ? "sparkles" : "lock.fill"
    }
}

private struct ConversationRow: View {
    let conversation: Conversation

    var body: some View {
        HStack(spacing: 12) {
            Text(initials)
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(avatarColor.gradient, in: RoundedRectangle(cornerRadius: 13, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(conversation.title)
                        .font(.headline)
                        .lineLimit(1)
                    Spacer()
                    Text(conversation.updatedAt, style: .relative)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text(conversation.latestMessage?.text.isEmpty == false
                     ? conversation.latestMessage?.text ?? ""
                     : String(localized: "No response yet"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Label(statusText, systemImage: "lock.fill")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .contentShape(Rectangle())
    }

    private var initials: String {
        let words = conversation.title.split(separator: " ")
        return String(words.prefix(2).compactMap(\.first)).uppercased()
    }

    private var statusText: String {
        String(localized: "On device")
    }

    private var avatarColor: Color { AppPalette.accentFill }
}
