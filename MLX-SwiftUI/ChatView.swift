//
//  ChatView.swift
//  MLX-SwiftUI
//
//  Created by Kazi Tanjim Shakib on 4/6/26.
//

import SwiftUI
import UIKit

struct ChatView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(AppState.self) private var appState
    @State private var viewModel = ChatViewModel()
    @State private var composerText = ""
    @State private var composerID = UUID()
    @State private var showsModelPicker = false
    @State private var showsDeleteConfirmation = false
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
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 1) {
                    Text("New Conversation")
                        .font(.headline)
                    HStack(spacing: 4) {
                        Circle()
                            .fill(viewModel.backendMode == .hosted ? .blue : .green)
                            .frame(width: 6, height: 6)
                        Text(viewModel.backendMode == .hosted
                             ? "Hugging Face • Online"
                             : "\(appState.activeModel.shortName) • On device")
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        print("Rename conversation tapped. Conversation persistence is not enabled.")
                    } label: {
                        Label("Rename", systemImage: "pencil")
                    }
                    Button {
                        print("Pin conversation tapped. Conversation persistence is not enabled.")
                    } label: {
                        Label("Pin", systemImage: "pin")
                    }
                    Button {
                        print("Export conversation tapped. Add a document exporter after conversation persistence is enabled.")
                    } label: {
                        Label("Export", systemImage: "square.and.arrow.up")
                    }
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
        .sheet(isPresented: $showsModelPicker) {
            modelPicker
        }
        .alert("Delete this conversation?", isPresented: $showsDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                viewModel.messages.removeAll()
                print("Deleted the in-memory conversation.")
            }
        } message: {
            Text("This clears the current in-memory messages. No conversation history is stored.")
        }
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
            if viewModel.backendMode == .hosted,
               viewModel.isLocalModelReady || viewModel.downloadError != nil {
                localModelStatusBanner
            }

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        if viewModel.messages.isEmpty {
                            conversationEmptyState
                        }
                        ForEach(viewModel.messages) { message in
                            VStack(alignment: message.role == .assistant ? .leading : .trailing, spacing: 3) {
                                bubble(for: message)
                                if message.role == .assistant, !message.text.isEmpty {
                                    messageTools(for: message)
                                }
                            }
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

    private var conversationEmptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "sparkles")
                .font(.system(size: 34, weight: .medium))
                .foregroundStyle(.indigo)
            Text("How can I help?")
                .font(.title2.bold())
            Text(viewModel.backendMode == .hosted
                 ? "Messages are sent to the hosted Hugging Face model and are not saved by this app."
                 : "Messages are processed by your selected local model and are not saved after leaving this conversation.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 80)
        .frame(maxWidth: .infinity)
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

    private var composer: some View {
        VStack(spacing: 9) {
            HStack {
                Button {
                    showsModelPicker = true
                } label: {
                    Label(appState.activeModel.name, systemImage: "cpu")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)

                Spacer()

                Label(
                    viewModel.backendMode == .hosted ? "Online via Hugging Face" : "Private by default",
                    systemImage: viewModel.backendMode == .hosted ? "cloud.fill" : "lock.fill"
                )
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
            }

            HStack(alignment: .bottom, spacing: 9) {
                Button {
                    print("Attach file tapped. ChatRequest currently accepts text only; connect a system fileImporter when multimodal context is supported.")
                } label: {
                    Image(systemName: "paperclip")
                        .font(.system(size: 18, weight: .semibold))
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Attach file")

                TextField("Message MLX Chat", text: composerTextBinding, axis: .vertical)
                    .focused($isComposerFocused)
                    .lineLimit(1...5)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .background(panelFill, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .foregroundStyle(.primary)
                    .overlay {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(surfaceBorder, lineWidth: 1)
                    }
                    .disabled(viewModel.isSending)

                Button {
                    sendCurrentPrompt()
                } label: {
                    Image(systemName: viewModel.isSending ? "hourglass" : "arrow.up")
                        .font(.system(size: 18, weight: .bold))
                        .frame(width: 44, height: 44)
                        .background(.indigo)
                        .foregroundStyle(.white)
                        .clipShape(Circle())
                }
                .disabled(trimmedComposerText.isEmpty || viewModel.isSending)
                .opacity(trimmedComposerText.isEmpty || viewModel.isSending ? 0.45 : 1)
            }
        }
        .id(composerID)
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(.ultraThinMaterial)
        .onChange(of: viewModel.isSending) { wasSending, isSending in
            if wasSending && !isSending {
                composerText = ""
                composerID = UUID()
                Task { @MainActor in
                    await Task.yield()
                    isComposerFocused = true
                }
            }
        }
    }

    private var trimmedComposerText: String {
        composerText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var composerTextBinding: Binding<String> {
        Binding(
            get: { composerText },
            set: { newValue in
                guard !viewModel.isSending else { return }
                composerText = newValue
            }
        )
    }

    private func sendCurrentPrompt() {
        guard viewModel.sendPrompt(trimmedComposerText) else { return }

        isComposerFocused = false
        composerText = ""
        composerID = UUID()
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

    private func messageTools(for message: ChatMessage) -> some View {
        HStack(spacing: 2) {
            Button {
                UIPasteboard.general.string = message.text
            } label: {
                Image(systemName: "doc.on.doc")
                    .frame(width: 36, height: 32)
            }
            .accessibilityLabel("Copy response")

            if message.id == viewModel.messages.last?.id {
                Button {
                    _ = viewModel.regenerateLastResponse()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .frame(width: 36, height: 32)
                }
                .disabled(viewModel.isSending)
                .accessibilityLabel("Regenerate response")
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .buttonStyle(.plain)
    }

    private var modelPicker: some View {
        NavigationStack {
            List {
                ForEach(appState.downloadedModels) { model in
                    Button {
                        appState.activate(model)
                        if model.id != LocalModel.qwen.id {
                            print("\(model.name) selected in the UX. ChatViewModel currently loads Qwen; connect this selection to an MLX configuration before production.")
                        }
                        showsModelPicker = false
                    } label: {
                        HStack(spacing: 12) {
                            Text(model.initials)
                                .font(.caption.bold())
                                .foregroundStyle(.white)
                                .frame(width: 38, height: 38)
                                .background(
                                    LinearGradient(colors: model.colors, startPoint: .topLeading, endPoint: .bottomTrailing),
                                    in: RoundedRectangle(cornerRadius: 11)
                                )
                            VStack(alignment: .leading) {
                                Text(model.name).foregroundStyle(.primary)
                                Text("\(model.focus) • \(model.sizeLabel)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if model.id == appState.activeModelID {
                                Image(systemName: "checkmark").foregroundStyle(.indigo)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Choose Model")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showsModelPicker = false }
                }
            }
        }
        .presentationDetents([.medium])
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
