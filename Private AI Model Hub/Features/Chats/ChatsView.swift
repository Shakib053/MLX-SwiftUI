import SwiftData
import SwiftUI

struct ChatsView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Conversation.updatedAt, order: .reverse) private var conversations: [Conversation]
    @Query(sort: \SavedTaskResult.createdAt, order: .reverse) private var savedResults: [SavedTaskResult]
    @State private var searchText = ""
    @State private var isSearchActive = false
    @State private var conversationToDelete: Conversation?
    @State private var persistenceError: String?
    @State private var resultToDelete: SavedTaskResult?
    @State private var startsNewChat = false
    @FocusState private var isSearchFocused: Bool

    private var query: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var filteredResults: [SavedTaskResult] {
        guard !query.isEmpty else { return savedResults }
        return savedResults.filter {
            $0.title.localizedCaseInsensitiveContains(query) ||
            $0.resultText.localizedCaseInsensitiveContains(query) ||
            $0.sourceText.localizedCaseInsensitiveContains(query)
        }
    }

    private var filteredConversations: [Conversation] {
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
                    if !query.isEmpty {
                        if filteredConversations.isEmpty && filteredResults.isEmpty {
                            ContentUnavailableView {
                                Label("No Results", systemImage: "magnifyingglass")
                            } description: {
                                Text("Check the spelling or try a new search.")
                            }
                            .frame(minHeight: 240)
                        } else {
                            VStack(alignment: .leading, spacing: 12) {
                                sectionHeader("RESULTS")
                                if !filteredResults.isEmpty {
                                    savedResultSection
                                }
                                if !filteredConversations.isEmpty {
                                    conversationList(filteredConversations)
                                }
                            }
                        }
                    } else if conversations.isEmpty && savedResults.isEmpty {
                        emptyState
                    } else {
                        if !savedResults.isEmpty {
                            savedResultSection
                        }
                        conversationSections
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .frame(maxWidth: 650)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
            .safeAreaInset(edge: .top, spacing: 0) {
                searchField
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .frame(maxWidth: 650)
                    .frame(maxWidth: .infinity)
                    .background(AppPalette.background)
            }
            .background {
                AppBackground()
                    .onTapGesture { isSearchFocused = false }
            }
            .navigationTitle("History")
            .mainTabBar(keepsPositionDuringKeyboard: true)
            .navigationBarTitleDisplayMode(isSearchActive ? .inline : .large)
            .onChange(of: isSearchFocused) { _, focused in
                if focused {
                    withAnimation(.easeInOut(duration: 0.2)) { isSearchActive = true }
                }
            }
            .onChange(of: appState.selectedTab) { _, selectedTab in
                if selectedTab != .history { cancelSearch() }
            }
            .toolbar {
                if !isSearchActive {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            startNewChat()
                        } label: {
                            Image(systemName: "plus")
                        }
                        .accessibilityLabel("Start new conversation")
                    }
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
            if query.isEmpty {
                sectionHeader("SAVED RESULTS")
                if recentConversations.isEmpty && pinnedConversations.isEmpty {
                    storageNote
                }
            }
            ForEach(filteredResults) { item in
                NavigationLink {
                    SavedTaskResultView(item: item)
                } label: {
                    HStack {
                        Image(systemName: "bookmark")
                        VStack(alignment: .leading) {
                            Text(historyMatch(item.title, query: query)).font(.headline)
                            if !query.isEmpty {
                                let excerpt = item.resultText.localizedCaseInsensitiveContains(query)
                                    ? item.resultText : item.sourceText
                                if excerpt.localizedCaseInsensitiveContains(query) {
                                    Text(historyMatch(excerpt, query: query, isPreview: true))
                                        .font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                                }
                            }
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
                if recentConversations.isEmpty { storageNote }
                conversationList(pinnedConversations)
            }

            if !recentConversations.isEmpty {
                sectionHeader("RECENT", showsClear: true)
                storageNote
                conversationList(recentConversations)
            }
        }
    }

    private var storageNote: some View {
        Label("Saved on this device", systemImage: "lock.fill")
            .font(.footnote)
            .foregroundStyle(.secondary)
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
                    ConversationRow(conversation: conversation, query: query)
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
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                TextField("Search", text: $searchText)
                    .accessibilityLabel("Search history")
                    .focused($isSearchFocused)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                    .onSubmit { isSearchFocused = false }
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                        isSearchFocused = true
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                            .frame(minWidth: 44, minHeight: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear search")
                }
            }
            .padding(.leading, 12)
            .padding(.trailing, searchText.isEmpty ? 12 : 0)
            .frame(height: 44)
            .background(AppPalette.card, in: RoundedRectangle(cornerRadius: 13))
            .overlay {
                RoundedRectangle(cornerRadius: 13)
                    .stroke(AppPalette.border)
                    .allowsHitTesting(false)
            }

            if isSearchActive {
                Button("Cancel", action: cancelSearch)
                    .foregroundStyle(AppPalette.accent)
                    .frame(minHeight: 44)
            }
        }
    }

    private func cancelSearch() {
        isSearchFocused = false
        withAnimation(.easeInOut(duration: 0.2)) {
            isSearchActive = false
            searchText = ""
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
                Text("Nothing saved yet")
                    .font(.title2.weight(.bold))
                Text("Saved results and conversations will appear here.")
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
        .padding(.top, 16)
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
    let query: String

    var body: some View {
        HStack(spacing: 12) {
            Text(initials)
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(avatarColor.gradient, in: RoundedRectangle(cornerRadius: 13, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(historyMatch(conversation.title, query: query))
                        .font(.headline)
                        .lineLimit(1)
                    Spacer()
                    Text(conversation.updatedAt, style: .relative)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text(historyMatch(preview, query: query, isPreview: true))
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

    private var preview: String {
        if !query.isEmpty,
           let match = conversation.messages.filter({ $0.text.localizedCaseInsensitiveContains(query) })
               .max(by: { $0.createdAt < $1.createdAt }) {
            return match.text
        }
        let latest = conversation.latestMessage?.text ?? ""
        return latest.isEmpty ? String(localized: "No response yet") : latest
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

private func historyMatch(_ text: String, query: String, isPreview: Bool = false) -> AttributedString {
    guard !query.isEmpty, let match = text.range(of: query, options: .caseInsensitive, locale: .current) else {
        return AttributedString(text)
    }

    let prefix = text[..<match.lowerBound]
    var result = AttributedString(isPreview && prefix.count > 16 ? "…" + prefix.suffix(16) : String(prefix))
    var highlight = AttributedString(text[match])
    highlight.backgroundColor = Color.yellow.opacity(0.45)
    result += highlight
    result += AttributedString(text[match.upperBound...])
    return result
}
