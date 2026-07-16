//
//  ChatView.swift
//  MLX-SwiftUI
//
//  Created by Kazi Tanjim Shakib on 4/6/26.
//

import SwiftUI

struct ChatView: View {
    @State private var viewModel = ChatViewModel()
    @FocusState private var isComposerFocused: Bool

    var body: some View {
        ZStack {
            background

            switch viewModel.state {
            case .loading:
                loadingView
            case .downloading:
                downloadView
            case .ready:
                chatView
            case .failed(let message):
                errorView(message)
            }
        }
        .navigationTitle("New Conversation")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .task {
            await viewModel.start()
        }
    }

    private var background: some View {
        LinearGradient(
            colors: [
                Color(red: 0.06, green: 0.07, blue: 0.11),
                Color(red: 0.10, green: 0.12, blue: 0.18),
                Color(red: 0.18, green: 0.10, blue: 0.16)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private var loadingView: some View {
        VStack(spacing: 14) {
            ProgressView()
                .tint(.white)
            Text(viewModel.loadingTitle)
                .font(.system(.title2, design: .rounded, weight: .semibold))
                .foregroundStyle(.white)
            Text(viewModel.loadingMessage)
                .font(.system(.footnote, design: .rounded))
                .foregroundStyle(.white.opacity(0.75))
                .multilineTextAlignment(.center)
        }
        .padding(28)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var downloadView: some View {
        VStack(spacing: 16) {
            Image(systemName: "arrow.down.circle.fill")
                .font(.system(size: 44))
                .foregroundStyle(.white)

            Text(viewModel.loadingTitle)
                .font(.system(.title2, design: .rounded, weight: .semibold))
                .foregroundStyle(.white)

            ProgressView(value: viewModel.downloadProgress)
                .tint(.orange)

            Text("\(Int(viewModel.downloadProgress * 100))%")
                .font(.system(.headline, design: .rounded, weight: .semibold))
                .foregroundStyle(.white)

            Text(viewModel.loadingMessage)
                .font(.system(.footnote, design: .rounded))
                .foregroundStyle(.white.opacity(0.75))
                .multilineTextAlignment(.center)

            if let fallbackError = viewModel.fallbackError {
                Text(fallbackError)
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(.yellow)
                    .multilineTextAlignment(.center)
            }

            Button {
                Task { await viewModel.useHostedFallback() }
            } label: {
                if viewModel.isConnectingToFallback {
                    ProgressView()
                        .tint(.white)
                } else {
                    Label("Chat Online While Downloading", systemImage: "cloud.fill")
                }
            }
            .font(.system(.headline, design: .rounded, weight: .semibold))
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(.white.opacity(0.14), in: Capsule())
            .foregroundStyle(.white)
            .disabled(viewModel.isConnectingToFallback)

            Text("Online chat sends your prompts to the hosted Hugging Face service.")
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
        }
        .padding(28)
        .frame(maxWidth: 420)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .padding()
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 44))
                .foregroundStyle(.yellow)
            Text("Could not load model")
                .font(.system(.title2, design: .rounded, weight: .semibold))
                .foregroundStyle(.white)
            Text(message)
                .font(.system(.body, design: .rounded))
                .foregroundStyle(.white.opacity(0.75))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
            Button("Try Again") {
                viewModel.retryDownload()
            }
            .font(.system(.headline, design: .rounded, weight: .semibold))
            .padding(.horizontal, 22)
            .padding(.vertical, 14)
            .background(.white.opacity(0.14), in: Capsule())
            .foregroundStyle(.white)

            Button("Chat Online Instead") {
                Task { await viewModel.useHostedFallback() }
            }
            .font(.system(.subheadline, design: .rounded, weight: .semibold))
            .foregroundStyle(.white.opacity(0.85))
        }
        .padding(28)
    }

    private var chatView: some View {
        VStack(spacing: 0) {
            header

            if viewModel.backendMode == .hosted,
               viewModel.isLocalModelReady || viewModel.downloadError != nil {
                localModelStatusBanner
            }

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.messages) { message in
                            bubble(for: message)
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

            composer
        }
        .onAppear {
            isComposerFocused = true
        }
    }

    private var localModelStatusBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: viewModel.isLocalModelReady ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
            Text(viewModel.isLocalModelReady
                 ? "Local model ready for your next chat"
                 : "Local model download failed")
                .font(.system(.caption, design: .rounded, weight: .semibold))
            Spacer()
            if viewModel.downloadError != nil {
                Button("Retry") {
                    viewModel.retryDownload()
                }
                .font(.system(.caption, design: .rounded, weight: .semibold))
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(viewModel.isLocalModelReady ? Color.green.opacity(0.25) : Color.orange.opacity(0.25))
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Qwen 3")
                    .font(.system(.headline, design: .rounded, weight: .semibold))
                    .foregroundStyle(.white)
                Text(viewModel.headerSubtitle)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
            }

            Spacer()

            Circle()
                .fill(.green)
                .frame(width: 10, height: 10)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(.white.opacity(0.05))
    }

    private var composer: some View {
        HStack(alignment: .bottom, spacing: 12) {
            TextField("Ask Qwen anything...", text: $viewModel.draft, axis: .vertical)
                .focused($isComposerFocused)
                .lineLimit(1...5)
                .padding(14)
                .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .foregroundStyle(.white)

            Button {
                Task {
                    await viewModel.sendPrompt()
                }
                isComposerFocused = true
            } label: {
                Image(systemName: viewModel.isSending ? "hourglass" : "paperplane.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .frame(width: 52, height: 52)
                    .background(
                        LinearGradient(
                            colors: [Color.orange, Color.pink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .disabled(viewModel.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isSending)
            .opacity(viewModel.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isSending ? 0.5 : 1)
        }
        .padding(16)
        .background(.white.opacity(0.04))
    }

    private func bubble(for message: ChatMessage) -> some View {
        HStack {
            if message.role == .assistant {
                bubbleBody(message)
                Spacer(minLength: 24)
            } else {
                Spacer(minLength: 24)
                bubbleBody(message)
            }
        }
    }

    private func bubbleBody(_ message: ChatMessage) -> some View {
        Text(displayText(for: message))
            .font(.system(.body, design: .rounded))
            .foregroundStyle(message.role == .user ? .black : .white)
            .padding(14)
            .background(message.role == .user ? Color.white.opacity(0.9) : Color.white.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .frame(maxWidth: 320, alignment: .leading)
    }

    private func displayText(for message: ChatMessage) -> String {
        if message.text.isEmpty && message.role == .assistant && viewModel.isSending {
            return "Thinking..."
        }

        return message.text
    }

    private func scrollToLatestMessage(with proxy: ScrollViewProxy) {
        guard let lastID = viewModel.messages.last?.id else { return }

        withAnimation(.easeOut(duration: 0.2)) {
            proxy.scrollTo(lastID, anchor: .bottom)
        }
    }
}

#Preview {
    NavigationStack {
        ChatView()
    }
}
