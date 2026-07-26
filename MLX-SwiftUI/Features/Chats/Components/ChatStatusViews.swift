import SwiftUI

struct ChatLoadingView: View {
    let title: String
    let message: String
    let style: ChatVisualStyle

    var body: some View {
        VStack(spacing: 14) {
            ProgressView()
                .tint(.indigo)
            Text(title)
                .font(.system(.title2, design: .rounded, weight: .semibold))
                .foregroundStyle(.primary)
            Text(message)
                .font(.system(.footnote, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(28)
        .background(style.panelFill, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(style.surfaceBorder, lineWidth: 1)
        }
    }
}

struct ChatDownloadView: View {
    let title: String
    let message: String
    let progress: Double
    let fallbackError: String?
    let isConnecting: Bool
    let style: ChatVisualStyle
    let useHostedFallback: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "arrow.down.circle.fill")
                .font(.system(size: 44))
                .foregroundStyle(.indigo)
            Text(title)
                .font(.system(.title2, design: .rounded, weight: .semibold))
                .foregroundStyle(.primary)
            ProgressView(value: progress)
                .tint(.orange)
            Text("\(Int(progress * 100))%")
                .font(.system(.headline, design: .rounded, weight: .semibold))
                .foregroundStyle(.primary)
            Text(message)
                .font(.system(.footnote, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if let fallbackError {
                Text(fallbackError)
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(.orange)
                    .multilineTextAlignment(.center)
            }

            Button(action: useHostedFallback) {
                if isConnecting {
                    ProgressView().tint(.primary)
                } else {
                    Label("Chat Online While Downloading", systemImage: "cloud.fill")
                }
            }
            .font(.system(.headline, design: .rounded, weight: .semibold))
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(style.elevatedFill, in: Capsule())
            .foregroundStyle(.primary)
            .overlay {
                Capsule().stroke(style.surfaceBorder, lineWidth: 1)
            }
            .disabled(isConnecting)

            Text("Online chat sends your prompts to the hosted Hugging Face service.")
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(28)
        .frame(maxWidth: 420)
        .background(style.panelFill, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(style.surfaceBorder, lineWidth: 1)
        }
        .padding()
    }
}

struct ChatErrorView: View {
    let message: String
    let style: ChatVisualStyle
    let retry: () -> Void
    let useHostedFallback: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 44))
                .foregroundStyle(.orange)
            Text("Could not load model")
                .font(.system(.title2, design: .rounded, weight: .semibold))
                .foregroundStyle(.primary)
            Text(message)
                .font(.system(.body, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
            Button("Try Again", action: retry)
                .font(.system(.headline, design: .rounded, weight: .semibold))
                .padding(.horizontal, 22)
                .padding(.vertical, 14)
                .background(style.elevatedFill, in: Capsule())
                .foregroundStyle(.primary)
                .overlay {
                    Capsule().stroke(style.surfaceBorder, lineWidth: 1)
                }
            Button("Chat Online Instead", action: useHostedFallback)
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .foregroundStyle(.indigo)
        }
        .padding(28)
    }
}

struct ChatConversationEmptyState: View {
    let backendMode: ChatBackendMode?

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "sparkles")
                .font(.system(size: 34, weight: .medium))
                .foregroundStyle(.indigo)
            Text("How can I help?")
                .font(.title2.bold())
            Text(
                backendMode == .hosted
                    ? "Messages are sent to the hosted Hugging Face model and are not saved by this app."
                    : "Messages are processed by your selected local model " +
                        "and are not saved after leaving this conversation."
            )
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 80)
        .frame(maxWidth: .infinity)
    }
}

struct ChatLocalModelStatusBanner: View {
    let isReady: Bool
    let hasError: Bool
    let retry: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: isReady ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(isReady ? .green : .orange)
            Text(isReady ? "Local model ready for your next chat" : "Local model download failed")
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .foregroundStyle(.primary)
            Spacer()
            if hasError {
                Button("Retry", action: retry)
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .foregroundStyle(.primary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(isReady ? Color.green.opacity(0.16) : Color.orange.opacity(0.16))
    }
}
