import Foundation
import Observation
import MLXHuggingFace
import MLXLMCommon
import MLXLLM
import HuggingFace
import Tokenizers


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

    private var session: ChatSession?
    private var didStartLoading = false

    func start() async {
        guard !didStartLoading else { return }
        didStartLoading = true
        await loadModel()
    }

    func loadModel() async {
        state = .loading
        do {
            print("shakib Starting model load")

            let model = try await #huggingFaceLoadModelContainer(
                configuration: LLMRegistry.qwen3_0_6b_4bit
            )
            print("shakib Model loaded")

            session = ChatSession(model)
            print("shakib Session created")
            state = .ready
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func sendPrompt() async {
        let prompt = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty, !isSending else { return }
        guard let session else { return }

        messages.append(ChatMessage(role: .user, text: prompt))
        messages.append(ChatMessage(role: .assistant, text: ""))
        draft = ""
        isSending = true

        do {
            let responseText = try await session.respond(to: prompt)

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
}
