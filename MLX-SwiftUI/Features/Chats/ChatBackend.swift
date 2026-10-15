import Foundation
import FoundationModels
import MLX
import MLXLMCommon

struct ChatRequest {
    static let defaultSystemPrompt = "You are a helpful, respectful, and honest assistant."

    let prompt: String
    let systemPrompt: String
    let maxTokens: Int
    let temperature: Double
    let history: [ChatMessage]
    let contextWindowTokens: Int?

    init(
        prompt: String,
        systemPrompt: String = ChatRequest.defaultSystemPrompt,
        maxTokens: Int = 2048,
        temperature: Double = 0.7,
        history: [ChatMessage] = [],
        contextWindowTokens: Int? = nil
    ) {
        self.prompt = prompt
        self.systemPrompt = systemPrompt
        self.maxTokens = maxTokens
        self.temperature = temperature
        self.history = history
        self.contextWindowTokens = contextWindowTokens
    }
}

struct ChatContextUsage {
    let inputTokens: Int
    let windowTokens: Int
    let omittedMessages: Int
}

enum ChatResponseStreamEvent {
    case chunk(String)
    case context(ChatContextUsage)
    case usage(promptTokens: Int, completionTokens: Int)
}

typealias ChatTextStream = AsyncThrowingStream<ChatResponseStreamEvent, Error>

protocol ChatBackend {
    func streamResponse(for request: ChatRequest) -> ChatTextStream
}

struct FoundationChatBackend: ChatBackend {
    func streamResponse(for request: ChatRequest) -> ChatTextStream {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let session = LanguageModelSession(instructions: request.systemPrompt)
                    let (prompt, usage) = try await selectContext(for: request)
                    continuation.yield(.context(usage))
                    var previous = ""
                    let options = GenerationOptions(maximumResponseTokens: min(1_024, usage.windowTokens - usage.inputTokens - 128))
                    for try await partial in session.streamResponse(to: prompt, options: options) {
                        let content = partial.content
                        let delta = String(content.dropFirst(previous.count))
                        if !delta.isEmpty { continuation.yield(.chunk(delta)) }
                        previous = content
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private func selectContext(for request: ChatRequest) async throws -> (String, ChatContextUsage) {
        let model = SystemLanguageModel.default
        let window = model.contextSize
        let reserve = min(1_024, window / 4) + 128
        var history: [ChatMessage] = []
        var candidate = request.history.count
        func formattedPrompt(_ messages: [ChatMessage]) -> String {
            let prefix = messages.map { "\($0.role == .user ? "User" : "Assistant"): \($0.text)" }
                .joined(separator: "\n")
            return prefix.isEmpty ? request.prompt : "\(prefix)\nUser: \(request.prompt)"
        }
        func count(_ prompt: String) async throws -> Int {
            if #available(iOS 26.4, *) {
                return try await model.tokenCount(for: prompt)
            }
            return (prompt.count + 2) / 3
        }
        var inputCount = try await count(formattedPrompt([]))
        guard inputCount + reserve <= window else { throw ChatBackendError.promptTooLong }
        while candidate >= 2 {
            guard request.history[candidate - 2].role == .user,
                  request.history[candidate - 1].role == .assistant,
                  !request.history[candidate - 1].isInterrupted,
                  !request.history[candidate - 1].text.isEmpty else {
                candidate -= 1
                continue
            }
            let next = Array(request.history[(candidate - 2)...(candidate - 1)]) + history
            let nextCount = try await count(formattedPrompt(next))
            guard nextCount + reserve <= window else { break }
            history = next
            inputCount = nextCount
            candidate -= 2
        }
        return (formattedPrompt(history), ChatContextUsage(
            inputTokens: inputCount,
            windowTokens: window,
            omittedMessages: request.history.count - history.count
        ))
    }
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
                        continuation.yield(.chunk(chunk))
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

final class LocalMLXChatBackend: ChatBackend {
    private let model: ModelContainer

    init(model: ModelContainer) {
        self.model = model
    }

    func streamResponse(for request: ChatRequest) -> ChatTextStream {
        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let (history, usage) = try await selectContext(for: request)
                    continuation.yield(.context(usage))
                    let window = usage.windowTokens
                    let session = ChatSession(
                        self.model,
                        instructions: request.systemPrompt,
                        history: history.map { $0.role == .user ? .user($0.text) : .assistant($0.text) },
                        generateParameters: GenerateParameters(
                            maxTokens: min(request.maxTokens, window - usage.inputTokens - 128),
                            temperature: Float(request.temperature)
                        ),
                        additionalContext: ["enable_thinking": true]
                    )
                    let promptTokens = try await self.model.perform { _, tokenizer in
                        tokenizer.encode(text: request.prompt).count
                    }
                    var fullResponseText = ""
                    let stream = session.streamResponse(to: request.prompt)
                    for try await chunk in stream {
                        fullResponseText += chunk
                        continuation.yield(.chunk(chunk))
                    }
                    let completionTokens = try await self.model.perform { _, tokenizer in
                        tokenizer.encode(text: fullResponseText).count
                    }
                    continuation.yield(.usage(
                        promptTokens: promptTokens,
                        completionTokens: completionTokens
                    ))
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

    private func selectContext(for request: ChatRequest) async throws -> ([ChatMessage], ChatContextUsage) {
        let window = request.contextWindowTokens ?? 8_192
        let reserve = min(request.maxTokens, window / 4) + 128
        var history: [ChatMessage] = []
        var candidate = request.history.count
        func count(_ messages: [ChatMessage]) async throws -> Int {
            var chat: [Chat.Message] = [.system(request.systemPrompt)]
            chat += messages.map { message in
                message.role == .user ? .user(message.text) : .assistant(message.text)
            }
            chat.append(.user(request.prompt))
            let input = try await model.prepare(input: UserInput(
                chat: chat,
                additionalContext: ["enable_thinking": true]
            ))
            return input.text.tokens.size
        }
        var inputCount = try await count([])
        guard inputCount + reserve <= window else { throw ChatBackendError.promptTooLong }
        while candidate >= 2 {
            guard request.history[candidate - 2].role == .user,
                  request.history[candidate - 1].role == .assistant,
                  !request.history[candidate - 1].isInterrupted,
                  !request.history[candidate - 1].text.isEmpty else {
                candidate -= 1
                continue
            }
            let next = Array(request.history[(candidate - 2)...(candidate - 1)]) + history
            let nextCount = try await count(next)
            guard nextCount + reserve <= window else { break }
            history = next
            inputCount = nextCount
            candidate -= 2
        }
        return (history, ChatContextUsage(
            inputTokens: inputCount,
            windowTokens: window,
            omittedMessages: request.history.count - history.count
        ))
    }
}
