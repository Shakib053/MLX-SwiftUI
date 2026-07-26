import SwiftUI

struct ChatsView: View {
    @Environment(AppState.self) private var appState
    @State private var searchText = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    searchField
                    emptyState
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
                        ChatView()
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Start new conversation")
                }
            }
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

            NavigationLink {
                ChatView()
            } label: {
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
