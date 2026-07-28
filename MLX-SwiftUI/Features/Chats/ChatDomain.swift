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
    let id: UUID
    let role: Role
    var text: String

    init(id: UUID = UUID(), role: Role, text: String) {
        self.id = id
        self.role = role
        self.text = text
    }

    enum Role: Equatable {
        case user
        case assistant
    }
}

extension String {
    func truncated(to length: Int) -> String {
        guard count > length else { return self }
        return String(prefix(length - 1)) + "…"
    }
}
