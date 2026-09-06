import Foundation
import HuggingFace
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
                    let stream = session.streamResponse(to: request.prompt)
                    for try await chunk in stream {
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
        var messages: [ChatCompletion.Message] = [
            ChatCompletion.Message.system(request.systemPrompt)
        ]
        messages.append(contentsOf: request.history.compactMap { message in
            guard !message.text.isEmpty else { return nil }
            switch message.role {
            case .user:
                return ChatCompletion.Message.user(message.text)
            case .assistant:
                return ChatCompletion.Message.assistant(message.text)
            }
        })
        messages.append(ChatCompletion.Message.user(request.prompt))

        let stream = client.chatCompletionStream(
            model: model,
            messages: messages,
            temperature: request.temperature,
            maxTokens: request.maxTokens
        )

        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    for try await chunk in stream {
                        if let content = chunk.choices.first?.message.content?.plainText, !content.isEmpty {
                            continuation.yield(.chunk(content))
                        }
                        if let usage = chunk.usage {
                            continuation.yield(.usage(
                                promptTokens: usage.promptTokens,
                                completionTokens: usage.completionTokens
                            ))
                        }
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
