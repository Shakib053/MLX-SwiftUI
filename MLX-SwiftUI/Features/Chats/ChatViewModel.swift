//
//  ChatViewModel.swift
//  MLX-SwiftUI
//
//  Created by Kazi Tanjim Shakib on 4/6/26.
//

import Foundation
import Observation
import SwiftData
import HuggingFace
import MLX
import MLXHuggingFace
import MLXLMCommon
import MLXLLM
import Tokenizers

@MainActor
@Observable
final class ChatViewModel {
    var state: ChatState = .loading
    var messages: [ChatMessage] = []
    var isSending = false
    var downloadProgress = 0.0
    var downloadError: String?
    var fallbackError: String?
    var isConnectingToFallback = false
    var isLocalModelReady = false
    var backendMode: ChatBackendMode?
    var isRenaming = false
    var renameText = ""
    var persistenceError: String?
    var historyLimitReached = false
    private(set) var loadedModelID: String?

    var loadingTitle: String {
        let modelName = LocalModel.catalog.first { $0.id == currentModelID }?.shortName ?? "model"
        return state == .downloading
            ? "Downloading \(modelName) for offline chat"
            : "Preparing \(modelName)..."
    }

    var loadingMessage: String {
        #if DEBUG && targetEnvironment(simulator)
        "Simulator uses the hosted fallback. Local MLX models run on a physical iPhone."
        #else
        "The selected model downloads once and is reused from the device cache on later launches."
        #endif
    }

    var headerSubtitle: String {
        if backendMode == .local {
            return "Private on-device chat"
        }
        if isLocalModelReady {
            return "Online fallback • Local model ready for next chat"
        }
        if downloadError != nil {
            return "Online fallback • Local download failed"
        }
        if downloadProgress > 0, downloadProgress < 1 {
            return "Online fallback • Local model \(Int(downloadProgress * 100))%"
        }
        return "Online fallback"
    }

    private var backend: (any ChatBackend)?
    private var didStartLoading = false
    private var localLoadingTask: Task<Void, Never>?
    private var responseTask: Task<Void, Never>?
    private var lastPersistenceDate = Date.distantPast
    private var currentModelID = LocalModel.qwen.id
    private var streamedResponseText = ""
    private var streamedCharacterCount = 0
    private var pendingStreamFlushTask: Task<Void, Never>?
    private var modelContext: SwiftData.ModelContext?
    private let conversationID: UUID?
    private var conversation: Conversation?

    init(conversationID: UUID? = nil) {
        self.conversationID = conversationID
    }

    var conversationTitle: String {
        conversation?.title ?? "New Conversation"
    }

    var hasConversation: Bool {
        conversation != nil
    }

    var isPinned: Bool {
        conversation?.isPinned ?? false
    }

    /// The model this chat session is using, which may differ from the app-wide
    /// active model while an existing conversation restores its recorded model.
    var currentModel: LocalModel {
        LocalModel.catalog.first { $0.id == currentModelID } ?? .qwen
    }

    /// Identifier recorded on assistant messages produced by the current backend.
    private var assistantModelID: String {
        backendMode == .hosted ? ChatBackendMode.hostedModelID : currentModelID
    }

    func start(
        activeModel: LocalModel,
        downloadedModelIDs: [String],
        context: SwiftData.ModelContext
    ) async {
        guard !didStartLoading else { return }
        didStartLoading = true
        modelContext = context

        #if !targetEnvironment(simulator)
        // Cap MLX's allocator cache so freed model weights are returned to the
        // system instead of lingering between model switches.
        MLX.Memory.cacheLimit = 20 * 1024 * 1024
        #endif

        if let conversationID {
            var descriptor = FetchDescriptor<Conversation>(
                predicate: #Predicate { $0.id == conversationID }
            )
            descriptor.fetchLimit = 1

            do {
                if let savedConversation = try context.fetch(descriptor).first {
                    conversation = savedConversation
                    let loadedMessages = savedConversation.orderedMessages.map {
                        ChatMessage(
                            id: $0.id,
                            role: $0.role,
                            text: $0.text,
                            modelID: $0.modelID,
                            isInterrupted: $0.isInterrupted
                        )
                    }
                    messages = ChatHistoryPolicy.storedMessages(loadedMessages)
                    historyLimitReached = messages != loadedMessages
                }
            } catch {
                persistenceError = "Could not load this conversation: \(error.localizedDescription)"
            }
        }

        // Continue a stored conversation on the model it was started with when
        // that model is still on the device; otherwise use the app-wide choice.
        let savedModelID = conversation?.modelID
        if let savedModelID,
           LocalModel.catalog.contains(where: { $0.id == savedModelID }),
           downloadedModelIDs.contains(savedModelID) {
            currentModelID = savedModelID
        } else {
            currentModelID = activeModel.id
        }

        let model = currentModel
        #if DEBUG && targetEnvironment(simulator)
        if SimulatorDownloadScenario.selected == .normal ||
            SimulatorDownloadScenario.selected == .hostedOnly {
            await connectHosted(isInitialLoad: true)
        } else {
            startLocalModelLoad(for: model)
        }
        #else
        startLocalModelLoad(for: model)
        #endif
    }

    func switchModel(to model: LocalModel) {
        guard model.id != currentModelID else { return }

        currentModelID = model.id
        localLoadingTask?.cancel()
        responseTask?.cancel()
        backend = nil
        #if !targetEnvironment(simulator)
        // The old container was just released; drop its cached GPU allocations
        // so the incoming model starts with a clean memory budget.
        MLX.Memory.clearCache()
        #endif
        backendMode = nil
        isLocalModelReady = false
        downloadError = nil
        fallbackError = nil
        #if DEBUG && targetEnvironment(simulator)
        if SimulatorDownloadScenario.selected == .normal ||
            SimulatorDownloadScenario.selected == .hostedOnly {
            Task { await connectHosted(isInitialLoad: true) }
        } else {
            startLocalModelLoad(for: model)
        }
        #else
        startLocalModelLoad(for: model)
        #endif
    }

    func loadModel() async {
        retryDownload()
    }

    func useHostedFallback() async {
        guard ChatEnvironment.supportsHostedChat else { return }
        await connectHosted(isInitialLoad: false)
    }

    func retryDownload() {
        localLoadingTask?.cancel()
        let model = LocalModel.catalog.first { $0.id == currentModelID } ?? .qwen
        startLocalModelLoad(for: model)
    }

    private func startLocalModelLoad(for model: LocalModel) {
        downloadProgress = 0
        downloadError = nil
        fallbackError = nil
        isLocalModelReady = false
        if backend == nil {
            state = .downloading
        }

        localLoadingTask = Task { [weak self] in
            guard let self else { return }
            do {
                #if DEBUG && targetEnvironment(simulator)
                try await self.runSimulatedDownload()
                await self.simulatedDownloadCompleted()
                #else
                let container = try await #huggingFaceLoadModelContainer(
                    configuration: model.configuration,
                    progressHandler: { progress in
                        let fraction = progress.fractionCompleted
                        Task { @MainActor [weak self] in
                            self?.updateDownloadProgress(fraction)
                        }
                    }
                )
                let localHistory = ChatHistoryPolicy.modelSeed(self.messages)
                    .compactMap { message -> Chat.Message? in
                        guard !message.text.isEmpty else { return nil }
                        switch message.role {
                        case .user: return .user(message.text)
                        case .assistant: return .assistant(message.text)
                        }
                    }
                let localBackend = LocalMLXChatBackend(
                    model: container,
                    history: localHistory,
                    instructions: ChatRequest.defaultSystemPrompt,
                    additionalContext: ["enable_thinking": true]
                )
                self.localDownloadCompleted(with: localBackend, modelID: model.id)
                #endif
            } catch is CancellationError {
                return
            } catch {
                self.localDownloadFailed(error.localizedDescription)
            }
        }
    }

    private func updateDownloadProgress(_ fraction: Double) {
        downloadProgress = max(downloadProgress, min(max(fraction, 0), 1))
    }

    private func localDownloadCompleted(with localBackend: any ChatBackend, modelID: String) {
        guard modelID == currentModelID else { return }
        downloadProgress = 1
        isLocalModelReady = true
        downloadError = nil
        loadedModelID = modelID

        guard backend == nil else { return }
        backend = localBackend
        backendMode = .local
        state = .ready
    }

    private func localDownloadFailed(_ message: String) {
        downloadError = message
        if backend == nil {
            state = .failed(message)
        }
    }

    private func connectHosted(isInitialLoad: Bool) async {
        guard ChatEnvironment.supportsHostedChat else { return }
        guard backend == nil else { return }
        isConnectingToFallback = true
        fallbackError = nil
        if isInitialLoad {
            state = .loading
        }

        do {
            #if DEBUG && targetEnvironment(simulator)
            let scenario = SimulatorDownloadScenario.selected
            if scenario == .hostedFailure || scenario == .bothUnavailable {
                throw ChatBackendError.apiError(statusCode: 503, message: "Simulated hosted fallback failure")
            }
            #endif
            let token = try huggingFaceToken()
            backend = HuggingFaceAPIChatBackend(token: token)
            backendMode = .hosted
            state = .ready
        } catch {
            fallbackError = error.localizedDescription
            if isInitialLoad || downloadError != nil {
                let message = downloadError.map { "\($0) Online fallback also failed: \(error.localizedDescription)" }
                    ?? error.localizedDescription
                state = .failed(message)
            } else {
                state = .downloading
            }
        }
        isConnectingToFallback = false
    }

    #if DEBUG && targetEnvironment(simulator)
    private func runSimulatedDownload() async throws {
        let scenario = SimulatorDownloadScenario.selected
        if scenario == .cached {
            updateDownloadProgress(1)
            return
        }

        let duration: Double = scenario == .slow ? 60 : 20
        let steps = Int(duration * 5)
        for step in 1...steps {
            try Task.checkCancellation()
            try await Task.sleep(for: .milliseconds(200))
            let fraction = Double(step) / Double(steps)
            updateDownloadProgress(fraction)

            if scenario == .localFailure || scenario == .bothUnavailable, fraction >= 0.45 {
                throw ChatBackendError.apiError(
                    statusCode: 500,
                    message: "Simulated local model download failure"
                )
            }
        }
    }

    private func simulatedDownloadCompleted() async {
        downloadProgress = 1
        isLocalModelReady = true
        downloadError = nil

        // MLX cannot run in Simulator, so completion only verifies the UI flow.
        if backend == nil {
            await connectHosted(isInitialLoad: true)
        }
    }
    #endif

    @discardableResult
    func sendPrompt(_ text: String) -> Bool {
        let prompt = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .truncated(to: ChatHistoryPolicy.maxMessageCharacters)
        guard !prompt.isEmpty, !isSending else { return false }
        guard let backend else { return false }

        isSending = true
        messages.append(ChatMessage(role: .user, text: prompt))
        messages.append(ChatMessage(role: .assistant, text: "", modelID: assistantModelID))
        applyHistoryLimit()

        ensureConversation()
        persistMessages(force: true)

        responseTask = Task { [weak self] in
            await self?.generateResponse(for: prompt, using: backend)
        }
        return true
    }

    @discardableResult
    func regenerateLastResponse() -> Bool {
        guard !isSending,
              let lastUserMessage = messages.last(where: { $0.role == .user }),
              let backend else {
            return false
        }

        if messages.last?.role == .assistant {
            messages.removeLast()
        }
        isSending = true
        messages.append(ChatMessage(role: .assistant, text: "", modelID: assistantModelID))
        applyHistoryLimit()
        persistMessages(force: true)
        responseTask = Task { [weak self] in
            await self?.generateResponse(
                for: lastUserMessage.text,
                using: backend,
                rebuildLocalSession: true
            )
        }
        return true
    }

    private func generateResponse(
        for prompt: String,
        using backend: any ChatBackend,
        rebuildLocalSession: Bool = false
    ) async {
        defer { finishStreaming() }

        do {
            try Task.checkCancellation()
            let request = ChatRequest(
                prompt: prompt,
                history: ChatHistoryPolicy.modelMessages(Array(messages.dropLast(2))),
                rebuildLocalSession: rebuildLocalSession
            )
            streamedResponseText = ""
            streamedCharacterCount = 0
            let stream = backend.streamResponse(for: request)

            for try await chunk in stream {
                appendStreamedChunk(chunk)
                scheduleStreamedTextFlush()
            }

            cancelPendingStreamFlush()
            if let lastIndex = messages.indices.last {
                let finalText = ChatResponseSanitizer.clean(streamedResponseText)
                guard !finalText.isEmpty else {
                    throw ChatBackendError.emptyResponse
                }
                messages[lastIndex].text = finalText
            }
        } catch {
            cancelPendingStreamFlush()
            if error is CancellationError || Task.isCancelled {
                handleStreamCancellation()
            } else if let lastIndex = messages.indices.last {
                messages[lastIndex].text = "Error: \(error.localizedDescription)"
            }
        }
    }

    /// A cancelled stream (e.g. the user switching models mid-generation) keeps
    /// whatever partial text already arrived, marked as interrupted so the UI can
    /// offer regeneration. An empty placeholder is dropped instead of persisted.
    private func handleStreamCancellation() {
        flushStreamedTextNow()
        guard let lastIndex = messages.indices.last,
              messages[lastIndex].role == .assistant else { return }
        if messages[lastIndex].text.isEmpty {
            messages.removeLast()
        } else {
            messages[lastIndex].isInterrupted = true
        }
    }

    /// Tokens arrive faster than the UI can re-layout comfortably; pushing each one
    /// straight into `messages` thrashes SwiftUI and SwiftData. Batching updates to
    /// ~20 per second keeps streaming smooth instead of flickering.
    private func appendStreamedChunk(_ chunk: String) {
        let remainingCapacity = ChatHistoryPolicy.maxMessageCharacters - streamedCharacterCount
        guard remainingCapacity > 0 else { return }
        if chunk.count <= remainingCapacity {
            streamedResponseText += chunk
            streamedCharacterCount += chunk.count
        } else {
            streamedResponseText += chunk.prefix(remainingCapacity)
            streamedCharacterCount = ChatHistoryPolicy.maxMessageCharacters
        }
    }

    private func scheduleStreamedTextFlush() {
        guard pendingStreamFlushTask == nil else { return }
        pendingStreamFlushTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(50))
            guard let self, !Task.isCancelled else { return }
            self.flushStreamedTextNow()
        }
    }

    private func flushStreamedTextNow() {
        cancelPendingStreamFlush()
        guard let lastIndex = messages.indices.last,
              messages[lastIndex].text != streamedResponseText else { return }
        messages[lastIndex].text = streamedResponseText
    }

    private func cancelPendingStreamFlush() {
        pendingStreamFlushTask?.cancel()
        pendingStreamFlushTask = nil
    }

    private func finishStreaming() {
        cancelPendingStreamFlush()
        streamedResponseText = ""
        streamedCharacterCount = 0
        isSending = false
        responseTask = nil
        persistMessages(force: true)
    }

    func renameConversation(to title: String) {
        let cleanedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedTitle.isEmpty, let conversation else { return }
        let oldTitle = conversation.title
        conversation.title = cleanedTitle
        conversation.updatedAt = .now
        if !saveContext() {
            conversation.title = oldTitle
        }
    }

    func togglePin() {
        guard let conversation else { return }
        let oldValue = conversation.isPinned
        conversation.isPinned.toggle()
        if !saveContext() {
            conversation.isPinned = oldValue
        }
    }

    func beginRenaming() {
        guard let conversation else { return }
        renameText = conversation.title
        isRenaming = true
    }

    func cancelRenaming() {
        isRenaming = false
    }

    func saveRenamedConversation() {
        renameConversation(to: renameText)
        isRenaming = false
    }

    func deleteConversation() {
        guard let conversation, let modelContext else { return }
        modelContext.delete(conversation)
        _ = saveContext()
        self.conversation = nil
    }

    private func ensureConversation() {
        guard conversation == nil, let modelContext else { return }
        let firstPrompt = messages.first(where: { $0.role == .user })?.text ?? "New Conversation"
        let newConversation = Conversation(
            title: firstPrompt.truncated(to: 60),
            modelID: currentModelID,
            backendMode: backendMode
        )
        modelContext.insert(newConversation)
        conversation = newConversation
    }

    private func persistMessages(force: Bool = false) {
        guard let conversation else { return }
        let limitedMessages = ChatHistoryPolicy.storedMessages(messages)
        if limitedMessages != messages {
            historyLimitReached = true
            messages = limitedMessages
        }
        conversation.modelID = currentModelID
        conversation.backendMode = backendMode
        conversation.updatedAt = .now

        let currentIDs = Set(messages.map(\.id))
        for persistedMessage in conversation.messages where !currentIDs.contains(persistedMessage.id) {
            modelContext?.delete(persistedMessage)
        }

        var persistedByID = Dictionary(uniqueKeysWithValues: conversation.messages.map { ($0.id, $0) })
        for (index, message) in messages.enumerated() {
            if let persistedMessage = persistedByID[message.id] {
                persistedMessage.text = message.text
                persistedMessage.orderIndex = index
                persistedMessage.modelID = message.modelID
                persistedMessage.isInterrupted = message.isInterrupted
            } else {
                let persistedMessage = PersistedMessage(
                    id: message.id,
                    role: message.role,
                    text: message.text,
                    orderIndex: index,
                    modelID: message.modelID,
                    isInterrupted: message.isInterrupted,
                    conversation: conversation
                )
                conversation.messages.append(persistedMessage)
                persistedByID[message.id] = persistedMessage
            }
        }
        let shouldSave = force || Date.now.timeIntervalSince(lastPersistenceDate) >= 0.25
        if shouldSave {
            _ = saveContext()
        }
    }

    @discardableResult
    private func saveContext() -> Bool {
        guard let modelContext else {
            persistenceError = "Could not save conversation history because storage is unavailable."
            return false
        }
        do {
            try modelContext.save()
            lastPersistenceDate = .now
            persistenceError = nil
            return true
        } catch {
            persistenceError = "Could not save conversation history: \(error.localizedDescription)"
            print(persistenceError ?? "Failed to persist conversation history")
            return false
        }
    }

    private func applyHistoryLimit() {
        let limitedMessages = ChatHistoryPolicy.storedMessages(messages)
        if limitedMessages != messages {
            messages = limitedMessages
            historyLimitReached = true
        }
    }

    private func huggingFaceToken() throws -> String {
        let possibleKeys = ["HuggingFaceToken", "HF_TOKEN"]
        let infoPlistValues = possibleKeys.compactMap { key -> String? in
            guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String else {
                return nil
            }
            return sanitizedToken(value)
        }
        let token = infoPlistValues.first ?? Secrets.hfToken

        guard !token.isEmpty else {
            throw ChatBackendError.missingHuggingFaceToken(
                "Add HF_TOKEN to Secrets.xcconfig or to the Xcode scheme environment, " +
                "then clean and rebuild the simulator app."
            )
        }
        return token
    }

    private func sanitizedToken(_ value: String) -> String? {
        let token = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty, !token.hasPrefix("$(") else {
            return nil
        }
        return token
    }
}

enum Secrets {
    static var hfToken: String {
        guard let token = Bundle.main.object(forInfoDictionaryKey: "HFToken") as? String else {
            return ""
        }
        let sanitized = token.trimmingCharacters(in: .whitespacesAndNewlines)
        return sanitized.hasPrefix("$(") ? "" : sanitized
    }
}
