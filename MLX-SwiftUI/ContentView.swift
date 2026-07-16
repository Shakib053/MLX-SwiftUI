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
                SettingsView()
            }
        }
        .tint(.indigo)
    }
}

private struct SettingsView: View {
    var body: some View {
        NavigationStack {
            Form {
                Section("About") {
                    LabeledContent("Local model", value: "Qwen 3 0.6B 4-bit")
                    LabeledContent("Online fallback", value: "Hugging Face")
                }

                #if DEBUG && targetEnvironment(simulator)
                SimulatorTestingSection()
                #endif
            }
            .navigationTitle("Settings")
        }
    }
}

#if DEBUG && targetEnvironment(simulator)
private struct SimulatorTestingSection: View {
    @State private var scenario = SimulatorDownloadScenario.selected

    var body: some View {
        Section {
            Picker("Scenario", selection: $scenario) {
                ForEach(SimulatorDownloadScenario.allCases) { scenario in
                    Text(scenario.title).tag(scenario)
                }
            }

            Button("Reset Test Session") {
                scenario = .normal
                SimulatorDownloadScenario.selected = .normal
            }
        } header: {
            Text("Developer Download Testing")
        } footer: {
            Text("The selected scenario applies to the next new conversation. Simulator progress is synthetic and never loads MLX.")
        }
        .onChange(of: scenario) { _, newValue in
            SimulatorDownloadScenario.selected = newValue
        }
    }
}
#endif

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
