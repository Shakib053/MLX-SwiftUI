//
//  ChatView.swift
//  MLX-SwiftUI
//
//  Created by Kazi Tanjim Shakib on 4/6/26.
//

import SwiftUI

struct ChatView: View {
    @Environment(\.colorScheme) private var colorScheme
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
        .toolbarColorScheme(colorScheme, for: .navigationBar)
        .task {
            await viewModel.start()
        }
    }

    private var background: some View {
        LinearGradient(
            colors: backgroundColors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private var backgroundColors: [Color] {
        if colorScheme == .dark {
            return [
                Color(red: 0.06, green: 0.07, blue: 0.11),
                Color(red: 0.10, green: 0.12, blue: 0.18),
                Color(red: 0.18, green: 0.10, blue: 0.16)
            ]
        }

        return [
            Color(red: 0.96, green: 0.97, blue: 1.00),
            Color(red: 0.92, green: 0.94, blue: 1.00),
            Color(red: 1.00, green: 0.94, blue: 0.97)
        ]
    }

    private var panelFill: Color {
        colorScheme == .dark ? .white.opacity(0.08) : .white.opacity(0.68)
    }

    private var elevatedFill: Color {
        colorScheme == .dark ? .white.opacity(0.14) : .white.opacity(0.82)
    }

    private var subtleFill: Color {
        colorScheme == .dark ? .white.opacity(0.05) : .white.opacity(0.36)
    }

    private var surfaceBorder: Color {
        colorScheme == .dark ? .white.opacity(0.10) : .indigo.opacity(0.12)
    }

    private var assistantBubbleFill: Color {
        colorScheme == .dark ? .white.opacity(0.10) : .white.opacity(0.74)
    }

    private var userBubbleFill: Color {
        colorScheme == .dark ? .indigo.opacity(0.38) : .indigo.opacity(0.14)
    }

    private var loadingView: some View {
        VStack(spacing: 14) {
            ProgressView()
                .tint(.indigo)
            Text(viewModel.loadingTitle)
                .font(.system(.title2, design: .rounded, weight: .semibold))
                .foregroundStyle(.primary)
            Text(viewModel.loadingMessage)
                .font(.system(.footnote, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(28)
        .background(panelFill, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(surfaceBorder, lineWidth: 1)
        }
    }

    private var downloadView: some View {
        VStack(spacing: 16) {
            Image(systemName: "arrow.down.circle.fill")
                .font(.system(size: 44))
                .foregroundStyle(.indigo)

            Text(viewModel.loadingTitle)
                .font(.system(.title2, design: .rounded, weight: .semibold))
                .foregroundStyle(.primary)

            ProgressView(value: viewModel.downloadProgress)
                .tint(.orange)

            Text("\(Int(viewModel.downloadProgress * 100))%")
                .font(.system(.headline, design: .rounded, weight: .semibold))
                .foregroundStyle(.primary)

            Text(viewModel.loadingMessage)
                .font(.system(.footnote, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if let fallbackError = viewModel.fallbackError {
                Text(fallbackError)
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(.orange)
                    .multilineTextAlignment(.center)
            }

            Button {
                Task { await viewModel.useHostedFallback() }
            } label: {
                if viewModel.isConnectingToFallback {
                    ProgressView()
                        .tint(.primary)
                } else {
                    Label("Chat Online While Downloading", systemImage: "cloud.fill")
                }
            }
            .font(.system(.headline, design: .rounded, weight: .semibold))
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(elevatedFill, in: Capsule())
            .foregroundStyle(.primary)
            .overlay {
                Capsule()
                    .stroke(surfaceBorder, lineWidth: 1)
            }
            .disabled(viewModel.isConnectingToFallback)

            Text("Online chat sends your prompts to the hosted Hugging Face service.")
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(28)
        .frame(maxWidth: 420)
        .background(panelFill, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(surfaceBorder, lineWidth: 1)
        }
        .padding()
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 44))
                .foregroundStyle(.orange)
            Text("Could not load model")
                .font(.system(.title2, design: .rounded, weight: .semibold))
                .foregroundStyle(.primary)
            Text(message)
                .font(.system(.body, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
            Button("Try Again") {
                viewModel.retryDownload()
            }
            .font(.system(.headline, design: .rounded, weight: .semibold))
            .padding(.horizontal, 22)
            .padding(.vertical, 14)
            .background(elevatedFill, in: Capsule())
            .foregroundStyle(.primary)
            .overlay {
                Capsule()
                    .stroke(surfaceBorder, lineWidth: 1)
            }

            Button("Chat Online Instead") {
                Task { await viewModel.useHostedFallback() }
            }
            .font(.system(.subheadline, design: .rounded, weight: .semibold))
            .foregroundStyle(.indigo)
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
                .foregroundStyle(viewModel.isLocalModelReady ? .green : .orange)
            Text(viewModel.isLocalModelReady
                 ? "Local model ready for your next chat"
                 : "Local model download failed")
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .foregroundStyle(.primary)
            Spacer()
            if viewModel.downloadError != nil {
                Button("Retry") {
                    viewModel.retryDownload()
                }
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .foregroundStyle(.primary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(viewModel.isLocalModelReady ? Color.green.opacity(0.16) : Color.orange.opacity(0.16))
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Qwen 3")
                    .font(.system(.headline, design: .rounded, weight: .semibold))
                    .foregroundStyle(.primary)
                Text(viewModel.headerSubtitle)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Circle()
                .fill(.green)
                .frame(width: 10, height: 10)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(subtleFill)
    }

    private var composer: some View {
        HStack(alignment: .bottom, spacing: 12) {
            TextField("Ask Qwen anything...", text: $viewModel.draft, axis: .vertical)
                .focused($isComposerFocused)
                .lineLimit(1...5)
                .padding(14)
                .background(panelFill, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .foregroundStyle(.primary)
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(surfaceBorder, lineWidth: 1)
                }

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
        .background(subtleFill)
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
            .foregroundStyle(.primary)
            .padding(14)
            .background(message.role == .user ? userBubbleFill : assistantBubbleFill)
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

#Preview("Light") {
    NavigationStack {
        ChatView()
    }
    .preferredColorScheme(.light)
}

#Preview("Dark") {
    NavigationStack {
        ChatView()
    }
    .preferredColorScheme(.dark)
}
