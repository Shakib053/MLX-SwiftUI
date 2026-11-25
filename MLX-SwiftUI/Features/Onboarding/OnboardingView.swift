import SwiftUI

struct OnboardingView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var step = Step.welcome
    @State private var selectedModel = LocalModel.qwen
    @AccessibilityFocusState private var headingFocused: Bool

    let onFinish: (LocalModel?) -> Void

    private enum Step: Int, CaseIterable {
        case welcome, privacy, model, ready

        var eyebrow: LocalizedStringKey {
            switch self {
            case .welcome: "A more personal AI"
            case .privacy: "Privacy, by design"
            case .model: "Make it yours"
            case .ready: "You’re all set"
            }
        }

        var title: LocalizedStringKey {
            switch self {
            case .welcome: "Meet AI that stays with you."
            case .privacy: "Your data stays on your phone."
            case .model: "Choose your first AI model."
            case .ready: "Your AI journey starts here."
            }
        }

        var message: LocalizedStringKey {
            switch self {
            case .welcome: "Chat, explore ideas, and get things done with a workspace built for on-device AI."
            case .privacy: "With a downloaded model, your prompts and responses are processed on your phone."
            case .model: "Start with a lightweight model. You can download more or switch models later."
            case .ready:
                #if targetEnvironment(simulator)
                "Your workspace is ready. You can download your selected model on an iPhone."
                #else
                "Get started to set up your selected model in the workspace."
                #endif
            }
        }
    }

    private var dark: Bool { colorScheme == .dark }
    private var accent: Color {
        dark ? Color(red: 0.65, green: 0.60, blue: 1) : Color(red: 0.36, green: 0.29, blue: 0.79)
    }
    private var surface: Color { dark ? Color(red: 0.11, green: 0.11, blue: 0.14) : .white }
    private var soft: Color { dark ? Color(red: 0.19, green: 0.17, blue: 0.30) : Color(red: 0.94, green: 0.93, blue: 1) }
    private var line: Color { .primary.opacity(0.12) }
    private var gradient: LinearGradient {
        LinearGradient(
            colors: [Color(red: 0.47, green: 0.39, blue: 0.93), Color(red: 0.34, green: 0.26, blue: 0.77)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    progress
                    VStack(alignment: .leading, spacing: 9) {
                        Text(step.eyebrow)
                            .font(.caption.weight(.heavy))
                            .tracking(1.5)
                            .textCase(.uppercase)
                            .foregroundStyle(accent)
                        Text(step.title)
                            .font(.largeTitle.bold())
                            .tracking(-0.8)
                            .accessibilityAddTraits(.isHeader)
                            .accessibilityFocused($headingFocused)
                        Text(step.message)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    stepContent
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.vertical, 8)
            }
            .id(step)
            .transition(.opacity)
            footer
        }
        .frame(maxWidth: 470)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(surface.ignoresSafeArea())
        .preferredColorScheme(appState.appearance.colorScheme)
    }

    private var header: some View {
        HStack(spacing: 8) {
            (Text(verbatim: "MLX") + Text(verbatim: "·").foregroundColor(accent))
                .font(.subheadline.weight(.heavy))
                .tracking(2)
            Spacer()
            Button {
                appState.appearance = dark ? .light : .dark
            } label: {
                Image(systemName: dark ? "sun.max" : "moon")
                    .frame(width: 36, height: 36)
                    .background(soft, in: Circle())
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel(dark ? Text("Switch to light appearance") : Text("Switch to dark appearance"))
            if step != .ready {
                Button {
                    onFinish(nil)
                } label: {
                    Text("Skip")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 24)
        .padding(.bottom, 5)
    }

    private var progress: some View {
        HStack(spacing: 7) {
            ForEach(Step.allCases, id: \.rawValue) { segment in
                Capsule()
                    .fill(segment.rawValue <= step.rawValue ? accent : line)
                    .frame(height: 4)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(step.rawValue + 1) of \(Step.allCases.count)")
    }

    @ViewBuilder private var stepContent: some View {
        switch step {
        case .welcome:
            artwork("cpu", height: 234)
            feature("sparkles", "Your own AI space", "Chat and work with AI tools in one place.")
            feature("lock", "Private by default", "Run supported models directly on your phone.")
        case .privacy:
            artwork("lock.shield.fill", height: 174)
            privacyPoint("On-device prompts", "Supported local models process your prompts and responses on your phone.")
            Divider()
            privacyPoint("Control over saved results", "Private tool results are saved when you choose Save.")
            Divider()
            privacyPoint("Your models, your choice", "Choose which compatible models to download, use, or remove.")
            #if targetEnvironment(simulator)
            note("Simulator chat can use a hosted service that receives your prompts. Local MLX downloads require an iPhone.")
            #else
            note("An internet connection is needed to download models. Chat shows which model is in use.")
            #endif
        case .model:
            modelRow(.qwen, description: "Quick responses · lightweight")
            modelRow(.gemma, description: "Everyday tasks · balanced")
            modelRow(.llama, description: "General-purpose chat")
            note("Model sizes are approximate. Storage and performance vary by model and device.")
        case .ready:
            artwork("sparkles", height: 194)
            HStack(spacing: 12) {
                ModelMark(model: selectedModel, size: 43)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(selectedModel.name).font(.subheadline.bold())
                    Text("About \(sizeLabel(for: selectedModel)) · \(selectedModel.quantization)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(13)
            .background(cardBorder())
            setupNote
        }
    }

    private func artwork(_ symbol: String, height: CGFloat) -> some View {
        ZStack {
            ForEach(step == .welcome ? [150.0, 192.0, 236.0] : [150.0], id: \.self) { diameter in
                Circle()
                    .strokeBorder(accent.opacity(0.22), style: StrokeStyle(
                        lineWidth: 1, dash: diameter == 150 ? [4, 4] : []
                    ))
                    .frame(width: diameter, height: diameter)
            }
            Image(systemName: symbol)
                .font(.system(size: 53, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 112, height: 112)
                .background(gradient, in: RoundedRectangle(cornerRadius: step == .ready ? 56 : 30))
                .shadow(color: accent.opacity(0.33), radius: 16, y: 10)

            if step == .welcome {
                Label("On-device AI", systemImage: "sparkle")
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(16)
                Label("Your data", systemImage: "lock")
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(16)
            } else if step == .ready {
                Image(systemName: "sparkle")
                    .font(.title3)
                    .foregroundStyle(accent)
                    .offset(x: -94, y: -46)
                Image(systemName: "sparkle")
                    .font(.caption)
                    .foregroundStyle(accent)
                    .offset(x: 96, y: 38)
            }
        }
        .labelStyle(OnboardingBadgeStyle(surface: surface, accent: accent))
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .background(soft.gradient)
        .clipShape(.rect(cornerRadius: 26))
        .accessibilityHidden(true)
        .dynamicTypeSize(...DynamicTypeSize.xLarge)
    }

    private func feature(_ icon: String, _ title: LocalizedStringKey, _ message: LocalizedStringKey) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(accent)
                .frame(width: 38, height: 38)
                .background(soft, in: RoundedRectangle(cornerRadius: 12))
                .accessibilityHidden(true)
            rowCopy(title, message)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(cardBorder())
        .accessibilityElement(children: .combine)
    }

    private func privacyPoint(_ title: LocalizedStringKey, _ message: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .accessibilityHidden(true)
            rowCopy(title, message)
        }
        .accessibilityElement(children: .combine)
    }

    private func rowCopy(_ title: LocalizedStringKey, _ message: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.subheadline.bold())
            Text(message).font(.caption).foregroundStyle(.secondary)
        }
    }

    private func modelRow(_ model: LocalModel, description: LocalizedStringKey) -> some View {
        let selected = selectedModel == model
        return Button {
            selectedModel = model
        } label: {
            HStack(spacing: 11) {
                ModelMark(model: model, size: 43)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(model.name).font(.subheadline.bold())
                    Text(description).font(.caption).foregroundStyle(.secondary)
                    Text("~\(sizeLabel(for: model)) · \(model.quantization)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: selected ? "circle.inset.filled" : "circle")
                    .foregroundStyle(selected ? accent : Color.secondary)
                    .accessibilityHidden(true)
            }
            .padding(12)
            .background(selected ? soft : surface, in: .rect(cornerRadius: 16))
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(selected ? accent : line, lineWidth: selected ? 1.5 : 1)
            }
            .contentShape(.rect(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func sizeLabel(for model: LocalModel) -> String {
        model == .qwen ? "480 MB" : model.sizeLabel
    }

    private func cardBorder() -> some View {
        RoundedRectangle(cornerRadius: 16).strokeBorder(line)
    }

    private func note(_ message: LocalizedStringKey) -> some View {
        Label(message, systemImage: "info.circle")
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    @ViewBuilder private var setupNote: some View {
        #if targetEnvironment(simulator)
        note("Local model downloads require a physical iPhone. Simulator chat may use a hosted service.")
        #else
        if appState.downloadedModelIDs.contains(selectedModel.id) {
            note("This model is already downloaded and will become your default.")
        } else if appState.downloadedModelIDs.count >= AppState.modelLimit {
            note("Remove a downloaded model in the Models tab to make room for this selection.")
        } else {
            note("Your download starts when you enter the workspace. It requires an internet connection and enough free storage.")
        }
        #endif
    }

    private var footer: some View {
        VStack(spacing: 9) {
            HStack(spacing: 10) {
                if step != .welcome {
                    Button {
                        go(to: step.rawValue - 1)
                    } label: {
                        Text("Back")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .background {
                                Capsule().strokeBorder(line)
                            }
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                Button {
                    if step == .ready {
                        onFinish(selectedModel)
                    } else {
                        go(to: step.rawValue + 1)
                    }
                } label: {
                    Label {
                        Text(step == .ready ? "Get started" : "Continue")
                    } icon: {
                        Image(systemName: "arrow.right")
                    }
                    .labelStyle(OnboardingActionStyle())
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(gradient, in: Capsule())
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            Text("Private AI. Right on your phone.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 10)
    }

    private func go(to index: Int) {
        guard let destination = Step(rawValue: index) else { return }
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.24)) {
            step = destination
        }
        headingFocused = true
    }
}

private struct OnboardingBadgeStyle: LabelStyle {
    let surface: Color
    let accent: Color

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 5) {
            configuration.icon
            configuration.title
        }
        .font(.caption.bold())
        .foregroundStyle(accent)
        .padding(9)
        .background(surface, in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct OnboardingActionStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 8) {
            configuration.title
            configuration.icon.accessibilityHidden(true)
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 9)
        .padding(.vertical, 8)
    }
}
