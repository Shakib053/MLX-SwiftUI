//
//  ChatViewModel.swift
//  MLX-SwiftUI
//
//  Created by Kazi Tanjim Shakib on 4/6/26.
//

import Foundation
import FoundationModels
import HuggingFace
import Observation
import SwiftData
import MLX
import MLXHuggingFace
import MLXLMCommon
import MLXLLM
import Tokenizers
import OSLog

@MainActor
@Observable
final class ChatViewModel {
    var state: ChatState = .loading
    var messages: [ChatMessage] = []
    var isSending = false
    var downloadProgress = 0.0
    var downloadError: String?
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
        return "Apple Foundation Models are used when available. Local MLX models run on a physical iPhone."
        #else
        return "The selected model downloads once and is reused from the device cache on later launches."
        #endif
    }

    var headerSubtitle: String {
        if backendMode == .foundation {
            return "Apple Foundation Models • On device"
        }
        if backendMode == .local {
            return "Private on-device chat"
        }
        if case .failed = state {
            return "Model unavailable"
        }
        if downloadProgress > 0, downloadProgress < 1 {
            return "Loading local model \(Int(downloadProgress * 100))%"
        }
        return "Preparing on-device model"
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
    private var responseStreamFilter = ChatResponseSanitizer.StreamFilter()
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

    var olderMessagesOmittedFromContext: Bool {
        messages.count > modelHistoryLimit
    }

    private var modelHistoryLimit: Int {
        backendMode == .foundation
            ? ChatHistoryPolicy.maxFoundationMessages
            : ChatHistoryPolicy.maxModelMessages
    }

    /// Identifier recorded on assistant messages produced by the current backend.
    private var assistantModelID: String {
        switch backendMode {
        case .foundation: ChatBackendMode.foundationModelID
        default: currentModelID
        }
    }

    func start(
        activeModel: LocalModel,
        downloadedModelIDs: [String],
        prefersFoundationModel: Bool,
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

        loadConversationIfPresent(context: context)

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

        if conversation?.backendMode == .foundation ||
            (conversation == nil && prefersFoundationModel) {
            if startFoundationModel() { return }
        }

        let model = currentModel
        #if targetEnvironment(simulator) && !DEBUG
        startFoundationFallback(after: nil)
        #elseif DEBUG && targetEnvironment(simulator)
        if SimulatorDownloadScenario.selected == .normal {
            startFoundationFallback(after: nil)
        } else {
            startLocalModelLoad(for: model)
        }
        #else
        startLocalModelLoad(for: model)
        #endif
    }

    func switchModel(to model: LocalModel) {
        guard model.id != currentModelID || backendMode != .local else { return }

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
        downloadError = nil
        #if targetEnvironment(simulator) && !DEBUG
        startFoundationFallback(after: nil)
        #elseif DEBUG && targetEnvironment(simulator)
        if SimulatorDownloadScenario.selected == .normal {
            startFoundationFallback(after: nil)
        } else {
            startLocalModelLoad(for: model)
        }
        #else
        startLocalModelLoad(for: model)
        #endif
    }

    func switchToFoundationModel() {
        localLoadingTask?.cancel()
        responseTask?.cancel()
        backend = nil
        backendMode = nil
        #if !targetEnvironment(simulator)
        MLX.Memory.clearCache()
        #endif
        downloadError = nil
        downloadProgress = 0
        if !startFoundationModel() {
            #if targetEnvironment(simulator)
            startFoundationFallback(after: nil)
            #else
            startLocalModelLoad(for: currentModel)
            #endif
        }
    }

    private func startFoundationModel() -> Bool {
        guard SystemLanguageModel.default.isAvailable else { return false }
        backend = FoundationChatBackend()
        backendMode = .foundation
        state = .ready
        return true
    }

    func loadModel() async {
        retryDownload()
    }

    func retryDownload() {
        localLoadingTask?.cancel()
        #if targetEnvironment(simulator) && !DEBUG
        startFoundationFallback(after: nil)
        #elseif DEBUG && targetEnvironment(simulator)
        if SimulatorDownloadScenario.selected == .normal {
            startFoundationFallback(after: nil)
        } else {
            let model = LocalModel.catalog.first { $0.id == currentModelID } ?? .qwen
            startLocalModelLoad(for: model)
        }
        #else
        let model = LocalModel.catalog.first { $0.id == currentModelID } ?? .qwen
        startLocalModelLoad(for: model)
        #endif
    }

    private func startLocalModelLoad(for model: LocalModel) {
        downloadProgress = 0
        downloadError = nil
        if backend == nil {
            state = .downloading
        }

        localLoadingTask = Task { [weak self] in
            guard let self else { return }
            do {
                #if DEBUG && targetEnvironment(simulator)
                try await self.runSimulatedDownload()
                self.simulatedDownloadCompleted()
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
            startFoundationFallback(after: message)
        }
    }

    private func startFoundationFallback(after localModelError: String?) {
        guard backend == nil else { return }
        if startFoundationModel() {
            return
        }
        let message = localModelError.map {
            "\($0) Apple Foundation Models are also unavailable on this device."
        } ?? "Apple Foundation Models are unavailable on this device."
        state = .failed(message)
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

            if scenario == .localFailure, fraction >= 0.45 {
                throw ChatBackendError.simulatedLocalModelLoadFailure
            }
        }
    }

    private func simulatedDownloadCompleted() {
        downloadProgress = 1
        downloadError = nil

        // MLX cannot run in Simulator, so completion only verifies the UI flow.
        if backend == nil {
            startFoundationFallback(after: nil)
        }
    }
    #endif

    @discardableResult
    func sendPrompt(_ text: String) -> Bool {
        let prompt = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .truncated(to: ChatHistoryPolicy.maxMessageCharacters)
        guard !prompt.isEmpty, !isSending else { return false }

        if case .blocked(let category) = ChatSafetyGate.evaluate(prompt) {
            appendSafetyResponse(for: prompt, category: category)
            return true
        }

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

    private func appendSafetyResponse(for prompt: String, category: ChatSafetyCategory) {
        messages.append(ChatMessage(role: .user, text: prompt))
        messages.append(
            ChatMessage(
                role: .assistant,
                text: category.refusalMessage,
                modelID: ChatMessage.safetyModelID
            )
        )
        applyHistoryLimit()
        ensureConversation()
        persistMessages(force: true)
    }

    @discardableResult
    func regenerateLastResponse() -> Bool {
        guard !isSending,
              let lastUserMessage = messages.last(where: { $0.role == .user }),
              let backend else {
            return false
        }

        if case .blocked(let category) = ChatSafetyGate.evaluate(lastUserMessage.text) {
            if messages.last?.role == .assistant {
                messages.removeLast()
            }
            messages.append(
                ChatMessage(
                    role: .assistant,
                    text: category.refusalMessage,
                    modelID: ChatMessage.safetyModelID
                )
            )
            applyHistoryLimit()
            persistMessages(force: true)
            return true
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
                history: ChatHistoryPolicy.modelMessages(
                    Array(messages.dropLast(2)),
                    maxMessages: modelHistoryLimit
                ),
                rebuildLocalSession: rebuildLocalSession
            )
            streamedResponseText = ""
            streamedCharacterCount = 0
            responseStreamFilter = ChatResponseSanitizer.StreamFilter()
            let stream = backend.streamResponse(for: request)
            let usage = try await consumeResponseStream(stream)
            try finalizeResponse(promptTokens: usage.promptTokens, completionTokens: usage.completionTokens)
        } catch {
            cancelPendingStreamFlush()
            if error is CancellationError || Task.isCancelled {
                handleStreamCancellation()
            } else if let lastIndex = messages.indices.last {
                messages[lastIndex].text = "Error: \(error.localizedDescription)"
            }
        }
    }

    private func consumeResponseStream(
        _ stream: ChatTextStream
    ) async throws -> (promptTokens: Int?, completionTokens: Int?) {
        var receivedPromptTokens: Int?
        var receivedCompletionTokens: Int?

        for try await event in stream {
            switch event {
            case .chunk(let chunk):
                let visibleText = responseStreamFilter.append(chunk)
                if !visibleText.isEmpty {
                    appendStreamedChunk(visibleText)
                    scheduleStreamedTextFlush()
                }
            case .usage(let promptTokens, let completionTokens):
                receivedPromptTokens = promptTokens
                receivedCompletionTokens = completionTokens
            }
        }

        cancelPendingStreamFlush()
        let remainingText = responseStreamFilter.finish()
        if !remainingText.isEmpty {
            appendStreamedChunk(remainingText)
        }
        flushStreamedTextNow()
        return (receivedPromptTokens, receivedCompletionTokens)
    }

    private func finalizeResponse(promptTokens: Int?, completionTokens: Int?) throws {
        guard let lastIndex = messages.indices.last else { return }
        let finalText = ChatResponseSanitizer.clean(streamedResponseText)
        guard !finalText.isEmpty else {
            throw ChatBackendError.emptyResponse
        }
        messages[lastIndex].text = finalText
        if let promptTokens, let completionTokens {
            messages[lastIndex].promptTokens = promptTokens
            messages[lastIndex].completionTokens = completionTokens
            let modelName = self.currentModel.name
            let totalTokens = promptTokens + completionTokens
            let contextWindowTokens = self.currentModel.contextWindowTokens
            let tokenDetails = "Prompt: \(promptTokens) | Completion: \(completionTokens) | Total: \(totalTokens) | Context Window: \(contextWindowTokens) tokens"
            AppLogger.chat.debug("Token consumption — model: \(modelName, privacy: .public) | \(tokenDetails, privacy: .public)")
        } else {
            let modelName = self.currentModel.name
            let contextWindowTokens = self.currentModel.contextWindowTokens
            AppLogger.chat.info("Model loaded: \(modelName, privacy: .public), context window: \(contextWindowTokens)")
        }
    }

    /// A cancelled stream (e.g. the user switching models mid-generation) keeps
    /// whatever partial text already arrived, marked as interrupted so the UI can
    /// offer regeneration. An empty placeholder is dropped instead of persisted.
    private func handleStreamCancellation() {
        _ = responseStreamFilter.finish()
        flushStreamedTextNow()
        cancelPendingStreamFlush()
        guard let lastIndex = messages.indices.last,
              messages[lastIndex].role == .assistant else { return }
        if messages[lastIndex].text.isEmpty {
            messages.removeLast()
        } else {
            messages[lastIndex].isInterrupted = true
        }
    }
}

private extension ChatViewModel {
    /// Tokens arrive faster than the UI can re-layout comfortably; pushing each one
    /// straight into `messages` thrashes SwiftUI and SwiftData. Batching updates to
    /// ~20 per second keeps streaming smooth instead of flickering.
    func appendStreamedChunk(_ chunk: String) {
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

    func scheduleStreamedTextFlush() {
        guard pendingStreamFlushTask == nil else { return }
        pendingStreamFlushTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(50))
            guard let self, !Task.isCancelled else { return }
            self.flushStreamedTextNow()
        }
    }

    func flushStreamedTextNow() {
        cancelPendingStreamFlush()
        guard let lastIndex = messages.indices.last,
              messages[lastIndex].text != streamedResponseText else { return }
        messages[lastIndex].text = streamedResponseText
    }

    func cancelPendingStreamFlush() {
        pendingStreamFlushTask?.cancel()
        pendingStreamFlushTask = nil
    }

    func finishStreaming() {
        cancelPendingStreamFlush()
        streamedResponseText = ""
        streamedCharacterCount = 0
        responseStreamFilter = ChatResponseSanitizer.StreamFilter()
        isSending = false
        responseTask = nil
        persistMessages(force: true)
    }
}

extension ChatViewModel {
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
                persistedMessage.promptTokens = message.promptTokens
                persistedMessage.completionTokens = message.completionTokens
            } else {
                let persistedMessage = PersistedMessage(
                    id: message.id,
                    role: message.role,
                    text: message.text,
                    orderIndex: index,
                    modelID: message.modelID,
                    isInterrupted: message.isInterrupted,
                    promptTokens: message.promptTokens,
                    completionTokens: message.completionTokens,
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
            AppLogger.chat.error("Failed to persist conversation history: \(error.localizedDescription, privacy: .public)")
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

    private func loadConversationIfPresent(context: SwiftData.ModelContext) {
        guard let conversationID else { return }
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
                        isInterrupted: $0.isInterrupted,
                        promptTokens: $0.promptTokens,
                        completionTokens: $0.completionTokens
                    )
                }
                messages = ChatHistoryPolicy.storedMessages(loadedMessages)
                historyLimitReached = messages != loadedMessages
            }
        } catch {
            persistenceError = "Could not load this conversation: \(error.localizedDescription)"
        }
    }

}
