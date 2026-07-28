import SwiftData
import SwiftUI

struct ChatsView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Conversation.updatedAt, order: .reverse) private var conversations: [Conversation]
    @State private var searchText = ""
    @State private var conversationToDelete: Conversation?
    @State private var persistenceError: String?

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

                    if filteredConversations.isEmpty {
                        emptyState
                    } else {
                        conversationSections
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .frame(maxWidth: .infinity)
            }
            .background(AppBackground())
            .navigationTitle("Chats")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        ChatView(viewID: UUID())
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Start new conversation")
                }
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
                Text(persistenceError ?? "Please try again.")
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
                sectionHeader("RECENT")
                conversationList(recentConversations)
            }
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.caption.weight(.bold))
                .tracking(1.1)
                .foregroundStyle(.secondary)
            Spacer()
            if title == "RECENT" {
                Button("Clear") {
                    for conversation in recentConversations {
                        modelContext.delete(conversation)
                    }
                    saveChanges()
                }
                .font(.subheadline)
                .foregroundStyle(.indigo)
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
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
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
            TextField("Search conversations", text: $searchText)
                .textInputAutocapitalization(.never)
                .submitLabel(.search)
        }
        .padding(.horizontal, 14)
        .frame(height: 44)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(.primary.opacity(0.06))
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(.indigo.opacity(0.12))
                    .frame(width: 92, height: 92)
                Image(systemName: "bubble.left.and.text.bubble.right")
                    .font(.system(size: 38, weight: .medium))
                    .foregroundStyle(.indigo)
            }

            VStack(spacing: 7) {
                Text(searchText.isEmpty ? "No Conversations" : "No Results")
                    .font(.title2.weight(.bold))
                Text(searchText.isEmpty
                     ? "Start a private conversation with a model that runs on this device."
                     : "There are no saved conversations matching “\(searchText)”.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            NavigationLink { ChatView(viewID: UUID()) } label: {
                Label("New Conversation", systemImage: "plus")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.roundedRectangle(radius: 14))
            .tint(.indigo)
            .accessibilityHint("Opens a new chat using \(appState.activeModel.name)")

            Label("\(appState.activeModel.shortName) • On device", systemImage: "lock.fill")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .padding(28)
        .frame(maxWidth: 440)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(.primary.opacity(0.07))
        }
        .padding(.top, 40)
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
                     : "No response yet")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Label(statusText, systemImage: conversation.backendMode == .hosted ? "network" : "lock.fill")
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
        conversation.backendMode == .hosted ? "Online" : "On device"
    }

    private var avatarColor: Color {
        let palette: [Color] = [.indigo, .blue, .orange, .green, .pink, .purple]
        let index = abs(conversation.id.hashValue) % palette.count
        return palette[index]
    }
}
