import Foundation

enum ChatBackendError: LocalizedError {
    case emptyResponse
    case promptTooLong
    case simulatedLocalModelLoadFailure

    var errorDescription: String? {
        switch self {
        case .emptyResponse:
            return String(localized: "The model returned an empty response.")
        case .promptTooLong:
            return String(localized: "This message is too long for the selected model. Shorten it and try again.")
        case .simulatedLocalModelLoadFailure:
            return String(localized: "Simulated local model download failure")
        }
    }
}

enum ChatState: Equatable {
    case loading
    case downloading
    case ready
    case needsModel
    case failed(String)
}

enum ChatBackendMode: Equatable {
    case foundation
    case local

    static let foundationModelID = "foundation"
}

#if DEBUG
enum SimulatorDownloadScenario: String, CaseIterable, Identifiable {
    case normal
    case slow
    case cached
    case localFailure

    static let defaultsKey = "simulatorDownloadScenario"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .normal: String(localized: "Apple Foundation Models")
        case .slow: String(localized: "Slow download (60 seconds)")
        case .cached: String(localized: "Cached model")
        case .localFailure: String(localized: "Local download failure")
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
    var promptTokens: Int?
    var completionTokens: Int?

    init(
        id: UUID = UUID(),
        role: Role,
        text: String,
        modelID: String = "",
        isInterrupted: Bool = false,
        promptTokens: Int? = nil,
        completionTokens: Int? = nil
    ) {
        self.id = id
        self.role = role
        self.text = text
        self.modelID = modelID
        self.isInterrupted = isInterrupted
        self.promptTokens = promptTokens
        self.completionTokens = completionTokens
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
            return String(localized: "Safety filter")
        }
        if modelID == "hosted" {
            return "Apple Foundation Models"
        }
        if modelID == ChatBackendMode.foundationModelID {
            return "Apple Foundation Models"
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
