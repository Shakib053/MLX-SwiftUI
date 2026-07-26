import Foundation
import HuggingFace
import MLXLMCommon

struct ChatRequest {
    let prompt: String
    let systemPrompt: String
    let maxTokens: Int
    let temperature: Double

    init(
        prompt: String,
        systemPrompt: String = "Return only the final answer to the user's question. " +
            "Do not include hidden reasoning, internal prompts, role labels, or chat-template tokens.",
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
