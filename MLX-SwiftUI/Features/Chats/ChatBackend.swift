import Foundation
import FoundationModels
import MLXLMCommon

struct ChatRequest {
    static let defaultSystemPrompt = "You are a helpful, respectful, and honest assistant."

    let prompt: String
    let systemPrompt: String
    let maxTokens: Int
    let temperature: Double
    let history: [ChatMessage]
    let rebuildLocalSession: Bool

    init(
        prompt: String,
        systemPrompt: String = ChatRequest.defaultSystemPrompt,
        maxTokens: Int = 2048,
        temperature: Double = 0.7,
        history: [ChatMessage] = [],
        rebuildLocalSession: Bool = false
    ) {
        self.prompt = prompt
        self.systemPrompt = systemPrompt
        self.maxTokens = maxTokens
        self.temperature = temperature
        self.history = history
        self.rebuildLocalSession = rebuildLocalSession
    }
}

enum ChatResponseStreamEvent {
    case chunk(String)
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
                    let history = request.history.map { message in
                        "\(message.role == .user ? "User" : "Assistant"): \(message.text)"
                    }.joined(separator: "\n")
                    let prompt = history.isEmpty ? request.prompt : "\(history)\nUser: \(request.prompt)"
                    var previous = ""
                    for try await partial in session.streamResponse(to: prompt) {
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
    private var session: ChatSession
    private var sessionMessageCount: Int

    init(
        model: ModelContainer,
        history: [Chat.Message] = [],
        instructions: String,
        additionalContext: [String: any Sendable]
    ) {
        self.model = model
        self.session = ChatSession(
            model,
            instructions: instructions,
            history: history,
            additionalContext: additionalContext
        )
        self.sessionMessageCount = history.count
    }

    func streamResponse(for request: ChatRequest) -> ChatTextStream {
        if request.rebuildLocalSession ||
            sessionMessageCount + 2 > ChatHistoryPolicy.maxModelMessages {
            let history = request.history.compactMap { message -> Chat.Message? in
                guard !message.text.isEmpty else { return nil }
                switch message.role {
                case .user: return .user(message.text)
                case .assistant: return .assistant(message.text)
                }
            }
            session = ChatSession(
                model,
                instructions: request.systemPrompt,
                history: history,
                additionalContext: ["enable_thinking": true]
            )
            sessionMessageCount = history.count
        }

        sessionMessageCount += 2

        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
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
}
