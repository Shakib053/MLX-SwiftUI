import SwiftUI

struct ChatLoadingView: View {
    let title: String
    let message: String
    let style: ChatVisualStyle

    var body: some View {
        VStack(spacing: 14) {
            ProgressView()
                .tint(AppPalette.accent)
            Text(title)
                .font(.system(.title2, design: .default, weight: .semibold))
                .foregroundStyle(.primary)
            Text(message)
                .font(.system(.footnote, design: .default))
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
                .foregroundStyle(AppPalette.accent)
            Text(title)
                .font(.system(.title2, design: .default, weight: .semibold))
                .foregroundStyle(.primary)
            ProgressView(value: progress)
                .tint(.orange)
            Text("\(Int(progress * 100))%")
                .font(.system(.headline, design: .default, weight: .semibold))
                .foregroundStyle(.primary)
            Text(message)
                .font(.system(.footnote, design: .default))
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
    let chooseModel: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 44))
                .foregroundStyle(.orange)
            Text("Could not load model")
                .font(.system(.title2, design: .default, weight: .semibold))
                .foregroundStyle(.primary)
            Text(message)
                .font(.system(.body, design: .default))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
            Button("Try Again", action: retry)
                .font(.system(.headline, design: .default, weight: .semibold))
                .padding(.horizontal, 22)
                .padding(.vertical, 14)
                .background(style.elevatedFill, in: Capsule())
                .foregroundStyle(.primary)
                .overlay {
                    Capsule().stroke(style.surfaceBorder, lineWidth: 1)
                }
            #if !targetEnvironment(simulator)
            Button("Choose another model", action: chooseModel)
            #endif
        }
        .padding(28)
    }
}

struct ChatConversationEmptyState: View {
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "sparkles")
                .font(.title.weight(.medium))
                .foregroundStyle(AppPalette.accent)
                .frame(width: 64, height: 64)
                .background(AppPalette.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 19))
                .accessibilityHidden(true)
            Text("How can I help?")
                .font(.title2.bold())
            Text("Start a conversation. You can revisit it in History.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 36)
        .frame(maxWidth: .infinity)
    }
}
