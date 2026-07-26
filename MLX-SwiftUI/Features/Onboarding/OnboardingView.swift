import SwiftUI

struct OnboardingView: View {
    let onFinish: () -> Void
    @State private var page = 0

    private let pages = [
        (
            "lock.fill",
            "Private AI, on your iPhone",
            "Chat with compact language models that run locally, even when you are offline."
        ),
        (
            "cpu",
            "Download up to two models",
            "Keep one fast model and one specialized model. Only the selected model runs at a time."
        ),
        (
            "checkmark.shield.fill",
            "Designed for local use",
            "Switch between downloaded models and keep prompts on device without cloud routing."
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
                                .fill(.indigo.opacity(0.14))
                                .frame(width: 150, height: 150)
                            Image(systemName: pages[index].0)
                                .font(.system(size: 62, weight: .medium))
                                .foregroundStyle(.indigo)
                        }
                        Text(pages[index].1)
                            .font(.largeTitle.bold())
                            .multilineTextAlignment(.center)
                        Text(pages[index].2)
                            .font(.title3)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(28)
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))

            Button(page == pages.count - 1 ? "Start Using MLX Chat" : "Continue") {
                if page < pages.count - 1 {
                    withAnimation { page += 1 }
                } else {
                    onFinish()
                }
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.roundedRectangle(radius: 15))
            .tint(.indigo)
            .padding(24)
        }
        .background(AppBackground())
    }
}
