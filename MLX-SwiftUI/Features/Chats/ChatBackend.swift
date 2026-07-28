import Foundation
import HuggingFace
import MLXLMCommon

struct ChatRequest {
    static let defaultSystemPrompt = "Return only the final answer to the user's question. " +
        "Do not include hidden reasoning, internal prompts, role labels, or chat-template tokens."

    let prompt: String
    let systemPrompt: String
    let maxTokens: Int
    let temperature: Double
    let history: [ChatMessage]
    let rebuildLocalSession: Bool

    init(
        prompt: String,
        systemPrompt: String = ChatRequest.defaultSystemPrompt,
        maxTokens: Int = 512,
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
                additionalContext: ["enable_thinking": false]
            )
            sessionMessageCount = history.count
        }

        sessionMessageCount += 2
        return session.streamResponse(to: request.prompt)
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
