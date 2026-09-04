import Foundation

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

    /// Identifier recorded on assistant messages produced by the hosted
    /// Hugging Face fallback rather than an on-device model.
    static let hostedModelID = "hosted"
}

enum ChatEnvironment {
    /// The hosted Hugging Face chat fallback is only offered in the simulator,
    /// where MLX cannot run. Physical devices always use the on-device MLX model.
    static var supportsHostedChat: Bool {
        #if DEBUG && targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }
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
        case .normal: "Hosted Hugging Face chat"
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
    static let safetyModelID = "safety-filter"

    let id: UUID
    let role: Role
    var text: String
    var modelID: String
    var isInterrupted: Bool

    init(
        id: UUID = UUID(),
        role: Role,
        text: String,
        modelID: String = "",
        isInterrupted: Bool = false
    ) {
        self.id = id
        self.role = role
        self.text = text
        self.modelID = modelID
        self.isInterrupted = isInterrupted
    }

    enum Role: Equatable {
        case user
        case assistant
    }
}

extension ChatMessage {
    /// Short label naming the model that produced this assistant message.
    /// Nil for user messages and legacy messages with no recorded model.
    var modelDisplayName: String? {
        guard role == .assistant, !modelID.isEmpty else { return nil }
        if modelID == Self.safetyModelID {
            return "Safety filter"
        }
        if modelID == ChatBackendMode.hostedModelID {
            return "Hugging Face"
        }
        return LocalModel.catalog.first { $0.id == modelID }?.shortName ?? modelID
    }

    var isSafetyResponse: Bool {
        modelID == Self.safetyModelID
    }
}

extension String {
    func truncated(to length: Int) -> String {
        guard length > 0 else { return "" }
        guard count > length else { return self }
        return String(prefix(length - 1)) + "…"
    }
}

enum ChatHistoryPolicy {
    // These limits keep the SwiftData store and the chat list bounded on device.
    static let maxStoredMessages = 200
    static let maxMessageCharacters = 20_000
    static let maxStoredCharacters = 500_000

    // Rehydrating the entire store into an LLM context can exceed a model's context
    // window even when the store itself is healthy.
    static let maxModelMessages = 60
    static let maxModelCharacters = 120_000

    static func normalized(_ messages: [ChatMessage]) -> [ChatMessage] {
        messages.map { message in
            ChatMessage(
                id: message.id,
                role: message.role,
                text: message.text.truncated(to: maxMessageCharacters),
                modelID: message.modelID,
                isInterrupted: message.isInterrupted
            )
        }
    }

    static func storedMessages(_ messages: [ChatMessage]) -> [ChatMessage] {
        trim(normalized(messages), maxMessages: maxStoredMessages, maxCharacters: maxStoredCharacters)
    }

    static func modelMessages(_ messages: [ChatMessage]) -> [ChatMessage] {
        trim(normalized(messages), maxMessages: maxModelMessages, maxCharacters: maxModelCharacters)
    }

    /// History seeded into a freshly loaded model. Trailing empty or interrupted
    /// assistant turns are dropped so a model switch never replays a cancelled
    /// partial reply to the next model as if it were a complete answer.
    static func modelSeed(_ messages: [ChatMessage]) -> [ChatMessage] {
        var seeded = modelMessages(messages)
        while let last = seeded.last,
              last.text.isEmpty || (last.role == .assistant && last.isInterrupted) {
            seeded.removeLast()
        }
        return seeded
    }

    private static func trim(
        _ messages: [ChatMessage],
        maxMessages: Int,
        maxCharacters: Int
    ) -> [ChatMessage] {
        guard !messages.isEmpty else { return [] }

        var result: [ChatMessage] = []
        var characterCount = 0
        for message in messages.reversed() {
            guard result.count < maxMessages else { break }
            let nextCount = characterCount + message.text.count
            guard nextCount <= maxCharacters || result.isEmpty else { break }
            result.append(message)
            characterCount = nextCount
        }

        result.reverse()
        while result.first?.role == .assistant {
            result.removeFirst()
        }
        return result
    }
}
