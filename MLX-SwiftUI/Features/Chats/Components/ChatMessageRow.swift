import SwiftUI
import UIKit

struct ChatMessageRow: View {
    let message: ChatMessage
    let isSending: Bool
    let isLastMessage: Bool
    /// Set when the conversation mixes replies from more than one model;
    /// assistant bubbles then show which model produced them.
    let showsModelLabel: Bool
    let style: ChatVisualStyle
    let regenerate: () -> Void

    var body: some View {
        VStack(alignment: message.role == .assistant ? .leading : .trailing, spacing: 3) {
            HStack {
                if message.role == .assistant {
                    bubble
                    Spacer(minLength: 24)
                } else {
                    Spacer(minLength: 24)
                    bubble
                }
            }

            if message.role == .assistant, !message.text.isEmpty {
                responseTools
            }

            if message.isSafetyResponse {
                Label("Safety filter", systemImage: "shield.fill")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            if message.role == .assistant, message.isInterrupted {
                Label("Response stopped — regenerate to continue", systemImage: "stop.circle.fill")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if message.role == .assistant, showsModelLabel,
               let modelName = message.modelDisplayName {
                Text(modelName)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var bubble: some View {
        Text(displayText)
            .font(.system(.body, design: .rounded))
            .foregroundStyle(.primary)
            .padding(14)
            .background(message.role == .user ? style.userBubbleFill : style.assistantBubbleFill)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .frame(maxWidth: 320, alignment: .leading)
    }

    private var responseTools: some View {
        HStack(spacing: 2) {
            Button {
                UIPasteboard.general.string = message.text
            } label: {
                Image(systemName: "doc.on.doc")
                    .frame(width: 36, height: 32)
            }
            .accessibilityLabel("Copy response")

            if isLastMessage, !message.isSafetyResponse {
                Button(action: regenerate) {
                    Image(systemName: "arrow.clockwise")
                        .frame(width: 36, height: 32)
                }
                .disabled(isSending)
                .accessibilityLabel("Regenerate response")
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .buttonStyle(.plain)
    }

    private var displayText: String {
        if message.text.isEmpty && message.role == .assistant && isSending {
            return "Thinking..."
        }
        return message.text
    }
}
