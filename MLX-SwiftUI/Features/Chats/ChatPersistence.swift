import Foundation
import SwiftData

@Model
final class Conversation {
    @Attribute(.unique) var id: UUID
    var title: String
    var createdAt: Date
    var updatedAt: Date
    var modelID: String
    var backendModeRawValue: String
    var isPinned: Bool = false

    @Relationship(deleteRule: .cascade, inverse: \PersistedMessage.conversation)
    var messages: [PersistedMessage]

    init(
        id: UUID = UUID(),
        title: String = "New Conversation",
        createdAt: Date = .now,
        updatedAt: Date = .now,
        modelID: String,
        backendMode: ChatBackendMode? = nil,
        isPinned: Bool = false,
        messages: [PersistedMessage] = []
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.modelID = modelID
        self.backendModeRawValue = backendMode?.rawValue ?? ""
        self.isPinned = isPinned
        self.messages = messages
    }

    var backendMode: ChatBackendMode? {
        get { ChatBackendMode(rawValue: backendModeRawValue) }
        set { backendModeRawValue = newValue?.rawValue ?? "" }
    }

    var orderedMessages: [PersistedMessage] {
        messages.sorted { $0.orderIndex < $1.orderIndex }
    }

    var latestMessage: PersistedMessage? {
        orderedMessages.last
    }
}

@Model
final class PersistedMessage {
    @Attribute(.unique) var id: UUID
    var roleRawValue: String
    var text: String
    var createdAt: Date
    var orderIndex: Int
    /// Model that produced this message (LocalModel id, or "hosted" for the
    /// online fallback). Empty for messages written before this field existed.
    var modelID: String = ""
    /// True when generation was cancelled (e.g. a mid-chat model switch)
    /// and the stored text is only a partial reply.
    var isInterrupted: Bool = false
    var conversation: Conversation?

    init(
        id: UUID = UUID(),
        role: ChatMessage.Role,
        text: String,
        createdAt: Date = .now,
        orderIndex: Int,
        modelID: String = "",
        isInterrupted: Bool = false,
        conversation: Conversation? = nil
    ) {
        self.id = id
        self.roleRawValue = role.rawValue
        self.text = text
        self.createdAt = createdAt
        self.orderIndex = orderIndex
        self.modelID = modelID
        self.isInterrupted = isInterrupted
        self.conversation = conversation
    }

    var role: ChatMessage.Role {
        ChatMessage.Role(rawValue: roleRawValue)
    }
}

extension ChatBackendMode {
    var rawValue: String {
        switch self {
        case .local: "local"
        case .hosted: "hosted"
        }
    }

    init?(rawValue: String) {
        switch rawValue {
        case "local": self = .local
        case "hosted": self = .hosted
        default: return nil
        }
    }
}

extension ChatMessage.Role {
    var rawValue: String {
        switch self {
        case .user: "user"
        case .assistant: "assistant"
        }
    }

    init(rawValue: String) {
        self = rawValue == "user" ? .user : .assistant
    }
}
