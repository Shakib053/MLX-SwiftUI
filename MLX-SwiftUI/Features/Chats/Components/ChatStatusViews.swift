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
    let style: ChatVisualStyle

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
            Text("Messages are processed on this device and saved in your local history.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 80)
        .frame(maxWidth: .infinity)
    }
}
