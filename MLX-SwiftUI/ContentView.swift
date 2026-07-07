import SwiftUI

struct ContentView: View {
    @State private var viewModel = ChatViewModel()
    @FocusState private var isComposerFocused: Bool

    var body: some View {
        ZStack {
            background

            switch viewModel.state {
            case .loading:
                loadingView
            case .ready:
                chatView
            case .failed(let message):
                errorView(message)
            }
        }
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
                Task { await viewModel.loadModel() }
            }
            .font(.system(.headline, design: .rounded, weight: .semibold))
            .padding(.horizontal, 22)
            .padding(.vertical, 14)
            .background(.white.opacity(0.14), in: Capsule())
            .foregroundStyle(.white)
        }
        .padding(28)
    }

    private var chatView: some View {
        VStack(spacing: 0) {
            header

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
                .onChange(of: viewModel.messages.count) { _ in
                    if let lastID = viewModel.messages.last?.id {
                        withAnimation(.easeOut(duration: 0.2)) {
                            proxy.scrollTo(lastID, anchor: .bottom)
                        }
                    }
                }
            }

            composer
        }
        .onAppear {
            isComposerFocused = true
        }
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
            if message.role == .assistant { bubbleBody(message) ; Spacer(minLength: 24) }
            else { Spacer(minLength: 24) ; bubbleBody(message) }
        }
    }

    private func bubbleBody(_ message: ChatMessage) -> some View {
        Text(message.text.isEmpty && message.role == .assistant && viewModel.isSending ? "…" : message.text)
            .font(.system(.body, design: .rounded))
            .foregroundStyle(message.role == .user ? .black : .white)
            .padding(14)
            .background(message.role == .user ? Color.white.opacity(0.9) : Color.white.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .frame(maxWidth: 320, alignment: .leading)
    }
}

#Preview {
    ContentView()
}
