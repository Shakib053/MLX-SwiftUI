import SwiftUI
import UIKit

struct ChatMessageRow: View {
    let message: ChatMessage
    let isSending: Bool
    let isLastMessage: Bool
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

            if isLastMessage {
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
