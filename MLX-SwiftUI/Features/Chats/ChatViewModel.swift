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

    func start(model: LocalModel, context: SwiftData.ModelContext) async {
        guard !didStartLoading else { return }
        didStartLoading = true
        modelContext = context

        if let conversationID {
            var descriptor = FetchDescriptor<Conversation>(
                predicate: #Predicate { $0.id == conversationID }
            )
            descriptor.fetchLimit = 1

            do {
                if let savedConversation = try context.fetch(descriptor).first {
                    conversation = savedConversation
                    let loadedMessages = savedConversation.orderedMessages.map {
                        ChatMessage(id: $0.id, role: $0.role, text: $0.text)
                    }
                    messages = ChatHistoryPolicy.storedMessages(loadedMessages)
                    historyLimitReached = messages != loadedMessages
                }
            } catch {
                persistenceError = "Could not load this conversation: \(error.localizedDescription)"
            }
        }

        currentModelID = model.id
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
                let localHistory = ChatHistoryPolicy.modelMessages(self.messages)
                    .filter { !$0.text.isEmpty }
                    .map { message in
                        switch message.role {
                        case .user: Chat.Message.user(message.text)
                        case .assistant: Chat.Message.assistant(message.text)
                        }
                    }
                let localBackend = LocalMLXChatBackend(
                    model: container,
                    history: localHistory,
                    instructions: ChatRequest.defaultSystemPrompt,
                    additionalContext: ["enable_thinking": false]
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
        messages.append(ChatMessage(role: .assistant, text: ""))
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
        messages.append(ChatMessage(role: .assistant, text: ""))
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
        defer {
            isSending = false
            responseTask = nil
        }

        do {
            try Task.checkCancellation()
            let request = ChatRequest(
                prompt: prompt,
                history: ChatHistoryPolicy.modelMessages(Array(messages.dropLast(2))),
                rebuildLocalSession: rebuildLocalSession
            )
            var responseText = ""
            let stream = backend.streamResponse(for: request)

            for try await chunk in stream {
                if responseText.count < ChatHistoryPolicy.maxMessageCharacters {
                    responseText.append(contentsOf: chunk)
                    responseText = responseText.truncated(to: ChatHistoryPolicy.maxMessageCharacters)
                }

                if let lastIndex = messages.indices.last {
                    messages[lastIndex].text = responseText
                    persistMessages()
                }
            }

            if let lastIndex = messages.indices.last {
                let finalText = ChatResponseSanitizer.clean(responseText)
                guard !finalText.isEmpty else {
                    throw ChatBackendError.emptyResponse
                }
                messages[lastIndex].text = finalText
                persistMessages(force: true)
            }
        } catch {
            if let lastIndex = messages.indices.last {
                messages[lastIndex].text = "Error: \(error.localizedDescription)"
                persistMessages(force: true)
            }
        }
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
            } else {
                let persistedMessage = PersistedMessage(
                    id: message.id,
                    role: message.role,
                    text: message.text,
                    orderIndex: index,
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
