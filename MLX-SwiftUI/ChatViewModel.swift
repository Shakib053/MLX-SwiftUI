import Foundation
import Observation
import MLXHuggingFace
import MLXLMCommon
import MLXLLM
import HuggingFace
import Tokenizers

protocol ChatBackend {
    func respond(to prompt: String) async throws -> String
}

struct LocalMLXChatBackend: ChatBackend {
    private let session: ChatSession

    init(session: ChatSession) {
        self.session = session
    }

    func respond(to prompt: String) async throws -> String {
        try await session.respond(to: prompt)
    }
}

struct HuggingFaceAPIChatBackend: ChatBackend {
    private let apiURL = URL(string: "https://router.huggingface.co/v1/chat/completions")!
    private let model = "Qwen/Qwen3-4B-Thinking-2507"
    private let token: String
    private let urlSession: URLSession

    init(token: String, urlSession: URLSession = .shared) {
        self.token = token
        self.urlSession = urlSession
    }

    func respond(to prompt: String) async throws -> String {
        var request = URLRequest(url: apiURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(
            HuggingFaceChatRequest(
                model: model,
                messages: [.init(role: "user", content: prompt)],
                maxTokens: 512,
                temperature: 0.7,
                reasoningEffort: "low"
            )
        )

        let (data, response) = try await urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ChatBackendError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let apiError = try? JSONDecoder().decode(HuggingFaceErrorResponse.self, from: data)
            throw ChatBackendError.apiError(
                statusCode: httpResponse.statusCode,
                message: apiError?.error ?? String(data: data, encoding: .utf8)
            )
        }

        let decoded = try JSONDecoder().decode(HuggingFaceChatResponse.self, from: data)
        guard let content = decoded.choices.first?.message.content.trimmingCharacters(in: .whitespacesAndNewlines),
              !content.isEmpty else {
            throw ChatBackendError.emptyResponse
        }

        return content
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

private struct HuggingFaceChatRequest: Encodable {
    let model: String
    let messages: [Message]
    let maxTokens: Int
    let temperature: Double
    let reasoningEffort: String

    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case maxTokens = "max_tokens"
        case temperature
        case reasoningEffort = "reasoning_effort"
    }

    struct Message: Encodable {
        let role: String
        let content: String
    }
}

private struct HuggingFaceChatResponse: Decodable {
    let choices: [Choice]

    struct Choice: Decodable {
        let message: Message
    }

    struct Message: Decodable {
        let content: String
    }
}

private struct HuggingFaceErrorResponse: Decodable {
    let error: String?
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

            backend = LocalMLXChatBackend(session: ChatSession(model))
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
            let responseText = try await backend.respond(to: prompt)

            if let lastIndex = messages.indices.last {
                messages[lastIndex].text = responseText
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
        let token = Secrets.hfToken

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
