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
    case ready
    case failed(String)
}

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
    var draft = ""
    var isSending = false

    var loadingTitle: String {
        #if targetEnvironment(simulator)
        "Connecting to hosted fallback..."
        #else
        "Loading Qwen..."
        #endif
    }

    var loadingMessage: String {
        #if targetEnvironment(simulator)
        "Simulator builds use Hugging Face Inference Providers instead of downloading a local model."
        #else
        "The model will download the first time, then open instantly later."
        #endif
    }

    var headerSubtitle: String {
        #if targetEnvironment(simulator)
        "Simulator fallback"
        #else
        "Local chat"
        #endif
    }

    private var backend: (any ChatBackend)?
    private var didStartLoading = false

    func start() async {
        guard !didStartLoading else { return }
        didStartLoading = true
        await loadModel()
    }

    func loadModel() async {
        state = .loading
        do {
            #if targetEnvironment(simulator)
            print("[ChatViewModel] Starting Hugging Face simulator fallback")
            let token = try huggingFaceToken()
            backend = HuggingFaceAPIChatBackend(token: token)
            print("[ChatViewModel] Fallback backend created")
            #else
            print("[ChatViewModel] Starting model load")

            let model = try await #huggingFaceLoadModelContainer(
                configuration: LLMRegistry.qwen3_0_6b_4bit
            )
            print("[ChatViewModel] Model loaded")

            backend = LocalMLXChatBackend(
                session: ChatSession(
                    model,
                    additionalContext: ["enable_thinking": false]
                )
            )
            print("[ChatViewModel] Local backend created")
            #endif
            state = .ready
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func sendPrompt() async {
        let prompt = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty, !isSending else { return }
        guard let backend else { return }

        messages.append(ChatMessage(role: .user, text: prompt))
        messages.append(ChatMessage(role: .assistant, text: ""))
        draft = ""
        isSending = true

        do {
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
            isSending = false
        } catch {
            if let lastIndex = messages.indices.last {
                messages[lastIndex].text = "Error: \(error.localizedDescription)"
            }
            isSending = false
            state = .failed(error.localizedDescription)
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
        guard let token = Bundle.main.object(forInfoDictionaryKey: "HFToken") as? String,
              !token.isEmpty else {
            fatalError("Missing HF_TOKEN — check Secrets.xcconfig and Info.plist")
        }
        return token
    }
}
