//
//  ContentView.swift
//  MLX-SwiftUI
//
//  Created by Kazi Tanjim Shakib on 4/6/26.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            Tab("Chats", systemImage: "bubble.left.and.bubble.right") {
                ChatsView()
            }

            Tab("Models", systemImage: "cpu") {
                PlaceholderTabView(title: "Models", systemImage: "cpu")
            }

            Tab("Settings", systemImage: "gearshape") {
                PlaceholderTabView(title: "Settings", systemImage: "gearshape")
            }
        }
        .tint(.indigo)
    }
}

private struct ChatsView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView {
                Label("No Conversations", systemImage: "bubble.left.and.bubble.right")
            } description: {
                Text("Start a new conversation to chat with your local model.")
            } actions: {
                NavigationLink {
                    ChatView()
                } label: {
                    Label("New Conversation", systemImage: "square.and.pencil")
                }
                .buttonStyle(.borderedProminent)
            }
            .navigationTitle("Chats")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        ChatView()
                    } label: {
                        Image(systemName: "square.and.pencil")
                    }
                    .accessibilityLabel("New Conversation")
                }
            }
            .background(Color(.systemGroupedBackground))
        }
    }
}

private struct PlaceholderTabView: View {
    let title: String
    let systemImage: String

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.system(size: 36, weight: .medium))
                    .foregroundStyle(.secondary)
                Text(title)
                    .font(.title2.weight(.semibold))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemGroupedBackground))
            .navigationTitle(title)
        }
    }
}

#Preview {
    ContentView()
}
