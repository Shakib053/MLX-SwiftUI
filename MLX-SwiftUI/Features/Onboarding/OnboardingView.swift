import SwiftUI

struct OnboardingView: View {
    let onFinish: () -> Void
    @State private var page = 0

    private let pages = [
        OnboardingPage(
            symbol: "lock.fill",
            title: "Start with on-device AI",
            message: "Private tools use an available on-device model. Ask AI opens chat, which shows which model is in use."
        ),
        OnboardingPage(
            symbol: "cpu",
            title: "Choose your model",
            message: "Apple Foundation Models runs when available. Otherwise, choose an MLX model to download. You can keep up to three downloaded models."
        ),
        OnboardingPage(
            symbol: "checkmark.shield.fill",
            title: "Know where chat runs",
            message: "Private tool results are saved only when you choose Save. Chat uses an available on-device model and shows which one is in use."
        )
    ]

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            TabView(selection: $page) {
                ForEach(pages.indices, id: \.self) { index in
                    VStack(spacing: 24) {
                        ZStack {
                            Circle()
                                .fill(AppPalette.accent.opacity(0.14))
                                .frame(width: 150, height: 150)
                            Image(systemName: pages[index].symbol)
                                .font(.system(size: 62, weight: .medium))
                                .foregroundStyle(AppPalette.accent)
                        }
                        Text(pages[index].title)
                            .font(.largeTitle.bold())
                            .multilineTextAlignment(.center)
                        Text(pages[index].message)
                            .font(.title3)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(28)
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))

            Button(page == pages.count - 1 ? String(localized: "Start Using MLX Chat") : String(localized: "Continue")) {
                if page < pages.count - 1 {
                    withAnimation { page += 1 }
                } else {
                    onFinish()
                }
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .appPrimaryButton()
            .padding(24)
        }
        .background(AppBackground())
    }
}

private struct OnboardingPage {
    let symbol: String
    let title: LocalizedStringKey
    let message: LocalizedStringKey
}
