//
//  ChatViewModel.swift
//  MLX-SwiftUI
//
//  Created by Kazi Tanjim Shakib on 4/6/26.
//

import Foundation
import Observation
import MLXHuggingFace
import MLXLMCommon
import MLXLLM
import HuggingFace
import Tokenizers

struct ChatRequest {
    let prompt: String
    let systemPrompt: String
    let maxTokens: Int
    let temperature: Double

    init(
        prompt: String,
        systemPrompt: String = "Return only the final answer to the user's question. Do not include hidden reasoning, internal prompts, role labels, or chat-template tokens.",
        maxTokens: Int = 512,
        temperature: Double = 0.7
    ) {
        self.prompt = prompt
        self.systemPrompt = systemPrompt
        self.maxTokens = maxTokens
        self.temperature = temperature
    }
}

typealias ChatTextStream = AsyncThrowingStream<String, Error>

protocol ChatBackend {
    func streamResponse(for request: ChatRequest) -> ChatTextStream
}

extension ChatBackend {
    func streamResponse(to prompt: String) -> ChatTextStream {
        streamResponse(for: ChatRequest(prompt: prompt))
    }
}

private enum ChatStreamAdapter {
    static func textStream<Source: AsyncSequence>(
        from source: Source,
        text: @escaping (Source.Element) -> String?
    ) -> ChatTextStream {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    for try await event in source {
                        guard let chunk = text(event), !chunk.isEmpty else {
                            continue
                        }
                        continuation.yield(chunk)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
}

struct LocalMLXChatBackend: ChatBackend {
    private let session: ChatSession

    init(session: ChatSession) {
        self.session = session
    }

    func streamResponse(for request: ChatRequest) -> ChatTextStream {
        session.streamResponse(to: request.prompt)
    }
}

struct HuggingFaceAPIChatBackend: ChatBackend {
    private let model = "Qwen/Qwen3-4B-Instruct-2507"
    private let client: InferenceClient

    init(token: String, urlSession: URLSession = .shared) {
        self.client = InferenceClient(
            session: urlSession,
            host: URL(string: "https://router.huggingface.co")!,
            bearerToken: token
        )
    }

    func streamResponse(for request: ChatRequest) -> ChatTextStream {
        let stream = client.chatCompletionStream(
            model: model,
            messages: [
                ChatCompletion.Message.system(request.systemPrompt),
                ChatCompletion.Message.user(request.prompt)
            ],
            temperature: request.temperature,
            maxTokens: request.maxTokens
        )

        return ChatStreamAdapter.textStream(from: stream) { chunk in
            chunk.choices.first?.message.content?.plainText
        }
    }
}

private extension ChatCompletion.Message.Content {
    var plainText: String {
        switch self {
        case .text(let text):
            return text
        case .mixed(let items):
            return items.compactMap { item in
                if case .text(let text) = item {
                    return text
                }
                return nil
            }
            .joined()
        }
    }
}

private enum ChatResponseSanitizer {
    private static let unavailableAnswer = "I could not produce a final answer. Please try again."

    static func clean(_ response: String) -> String {
        let original = response.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !original.isEmpty else { return original }

        let protected = protectingFencedCodeBlocks(in: original)
        var cleaned = protected.text
        cleaned = extractingFinalAnswer(from: cleaned)
        guard !cleaned.isEmpty else { return unavailableAnswer }

        cleaned = replacingTemplateTokens(in: cleaned)
        cleaned = keepingFinalAssistantTurn(from: cleaned)
        cleaned = removingRoleWrapperLines(from: cleaned)
        cleaned = removingLeadingRoleLabels(from: cleaned)
        cleaned = restoringFencedCodeBlocks(in: cleaned, blocks: protected.blocks)
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)

        return cleaned.isEmpty ? unavailableAnswer : cleaned
    }

    private static func protectingFencedCodeBlocks(in text: String) -> (text: String, blocks: [String]) {
        var remaining = text
        var protected = ""
        var blocks: [String] = []

        while let openingFence = remaining.range(of: "```") {
            protected += String(remaining[..<openingFence.lowerBound])
            let afterOpeningFence = openingFence.upperBound..<remaining.endIndex

            guard let closingFence = remaining.range(of: "```", range: afterOpeningFence) else {
                protected += String(remaining[openingFence.lowerBound...])
                return (protected, blocks)
            }

            let blockRange = openingFence.lowerBound..<closingFence.upperBound
            let placeholder = "__CHAT_CODE_BLOCK_\(blocks.count)__"
            blocks.append(String(remaining[blockRange]))
            protected += placeholder
            remaining = String(remaining[closingFence.upperBound...])
        }

        protected += remaining
        return (protected, blocks)
    }

    private static func restoringFencedCodeBlocks(in text: String, blocks: [String]) -> String {
        var restored = text

        for index in blocks.indices {
            restored = restored.replacingOccurrences(
                of: "__CHAT_CODE_BLOCK_\(index)__",
                with: blocks[index]
            )
        }

        return restored
    }

    private static func extractingFinalAnswer(from text: String) -> String {
        if let finalThinkTag = text.range(of: "</think>", options: [.caseInsensitive, .backwards]) {
            return String(text[finalThinkTag.upperBound...])
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let withoutPairedThinkingBlocks = text.replacingOccurrences(
            of: #"(?is)<think>.*?</think>"#,
            with: "",
            options: .regularExpression
        )

        if withoutPairedThinkingBlocks.range(
            of: #"(?is)<think\b[^>]*>"#,
            options: .regularExpression
        ) != nil {
            return ""
        }

        return withoutPairedThinkingBlocks
    }

    private static func replacingTemplateTokens(in text: String) -> String {
        var cleaned = text
        let tokens = [
            "<|im_start|>",
            "<|im_end|>",
            "<|assistant|>",
            "<|user|>",
            "<|system|>",
            "<s>",
            "</s>"
        ]

        for token in tokens {
            cleaned = cleaned.replacingOccurrences(of: token, with: "\n")
        }

        return cleaned
    }

    private static func keepingFinalAssistantTurn(from text: String) -> String {
        let pattern = #"(?im)^\s*(?:\*\*)?assistant(?:\*\*)?\s*:?\s*$|^\s*(?:\*\*)?assistant(?:\*\*)?\s*:\s*"#
        guard let match = text.range(of: pattern, options: .regularExpression) else {
            return text
        }

        var searchRange = match.upperBound..<text.endIndex
        var lastMatch = match

        while let next = text.range(of: pattern, options: .regularExpression, range: searchRange) {
            lastMatch = next
            searchRange = next.upperBound..<text.endIndex
        }

        return String(text[lastMatch.upperBound...])
    }

    private static func removingRoleWrapperLines(from text: String) -> String {
        let roleNames: Set<String> = ["assistant", "user", "system"]
        let filteredLines = text.split(separator: "\n", omittingEmptySubsequences: false).filter { line in
            let normalized = line.trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: "*`_: "))
                .lowercased()
            return !roleNames.contains(normalized)
        }

        return filteredLines.joined(separator: "\n")
    }

    private static func removingLeadingRoleLabels(from text: String) -> String {
        var cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let pattern = #"(?is)^\s*(?:\*\*)?(?:assistant|system|user)(?:\*\*)?\s*:\s*"#

        while let range = cleaned.range(of: pattern, options: .regularExpression) {
            cleaned.removeSubrange(range)
            cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return cleaned
    }
}

enum ChatBackendError: LocalizedError {
    case missingHuggingFaceToken(String)
    case invalidResponse
    case emptyResponse
    case apiError(statusCode: Int, message: String?)

    var errorDescription: String? {
        switch self {
        case .missingHuggingFaceToken(let diagnostics):
            return "Missing Hugging Face token. \(diagnostics)"
        case .invalidResponse:
            return "The fallback service returned an invalid response."
        case .emptyResponse:
            return "The fallback service returned an empty response."
        case .apiError(let statusCode, let message):
            if let message, !message.isEmpty {
                return "Hugging Face fallback failed with HTTP \(statusCode): \(message)"
            }
            return "Hugging Face fallback failed with HTTP \(statusCode)."
        }
    }
}

enum ChatState: Equatable {
    case loading
    case downloading
    case ready
    case failed(String)
}

enum ChatBackendMode: Equatable {
    case local
    case hosted
}

#if DEBUG
enum SimulatorDownloadScenario: String, CaseIterable, Identifiable {
    case normal
    case slow
    case cached
    case localFailure
    case hostedFailure
    case bothUnavailable
    case hostedOnly

    static let defaultsKey = "simulatorDownloadScenario"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .normal: "Normal download (20 seconds)"
        case .slow: "Slow download (60 seconds)"
        case .cached: "Cached model"
        case .localFailure: "Local download failure"
        case .hostedFailure: "Hosted fallback failure"
        case .bothUnavailable: "Both unavailable"
        case .hostedOnly: "Hosted only"
        }
    }

    static var selected: SimulatorDownloadScenario {
        get {
            guard let value = UserDefaults.standard.string(forKey: defaultsKey),
                  let scenario = SimulatorDownloadScenario(rawValue: value) else {
                return .normal
            }
            return scenario
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: defaultsKey)
        }
    }
}
#endif

struct ChatMessage: Identifiable, Equatable {
    let id = UUID()
    let role: Role
    var text: String

    enum Role { 
        case user
        case assistant
    }
}

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

    var loadingTitle: String {
        state == .downloading ? "Downloading Qwen for offline chat" : "Preparing Qwen..."
    }

    var loadingMessage: String {
        #if DEBUG && targetEnvironment(simulator)
        "Simulator is reproducing the device download flow. No MLX model is being downloaded."
        #else
        "The model downloads once and is reused from the device cache on later launches."
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

    func start() async {
        guard !didStartLoading else { return }
        didStartLoading = true
        #if DEBUG && targetEnvironment(simulator)
        if SimulatorDownloadScenario.selected == .hostedOnly {
            await connectHosted(isInitialLoad: true)
        } else {
            startLocalModelLoad()
        }
        #else
        startLocalModelLoad()
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
        startLocalModelLoad()
    }

    private func startLocalModelLoad() {
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
                let model = try await #huggingFaceLoadModelContainer(
                    configuration: LLMRegistry.qwen3_0_6b_4bit,
                    progressHandler: { progress in
                        let fraction = progress.fractionCompleted
                        Task { @MainActor [weak self] in
                            self?.updateDownloadProgress(fraction)
                        }
                    }
                )
                let localBackend = LocalMLXChatBackend(
                    session: ChatSession(
                        model,
                        additionalContext: ["enable_thinking": false]
                    )
                )
                self.localDownloadCompleted(with: localBackend)
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

    private func localDownloadCompleted(with localBackend: any ChatBackend) {
        downloadProgress = 1
        isLocalModelReady = true
        downloadError = nil

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

            if (scenario == .localFailure || scenario == .bothUnavailable), fraction >= 0.45 {
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
        let prompt = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty, !isSending else { return false }
        guard let backend else { return false }

        isSending = true
        messages.append(ChatMessage(role: .user, text: prompt))
        messages.append(ChatMessage(role: .assistant, text: ""))

        responseTask = Task { [weak self] in
            await self?.generateResponse(for: prompt, using: backend)
        }
        return true
    }

    private func generateResponse(for prompt: String, using backend: any ChatBackend) async {
        defer {
            isSending = false
            responseTask = nil
        }

        do {
            try Task.checkCancellation()
            let request = ChatRequest(prompt: prompt)
            var responseText = ""
            let stream = backend.streamResponse(for: request)

            for try await chunk in stream {
                responseText += chunk

                if let lastIndex = messages.indices.last {
                    messages[lastIndex].text = responseText
                }
            }

            if let lastIndex = messages.indices.last {
                let finalText = ChatResponseSanitizer.clean(responseText)
                guard !finalText.isEmpty else {
                    throw ChatBackendError.emptyResponse
                }
                messages[lastIndex].text = finalText
            }
        } catch {
            if let lastIndex = messages.indices.last {
                messages[lastIndex].text = "Error: \(error.localizedDescription)"
            }
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
                "Add HF_TOKEN to Secrets.xcconfig or to the Xcode scheme environment, then clean and rebuild the simulator app."
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
