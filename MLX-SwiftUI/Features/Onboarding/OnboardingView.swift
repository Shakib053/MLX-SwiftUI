import SwiftUI

struct OnboardingView: View {
    let onFinish: () -> Void
    @State private var page = 0

    private let pages = [
        (
            "lock.fill",
            "Start with on-device AI",
            "Private tools use an available on-device model. Ask AI opens chat, which shows which model is in use."
        ),
        (
            "cpu",
            "Choose your model",
            "Foundation Models is the default. You can also choose an MLX model and keep up to three downloaded models."
        ),
        (
            "checkmark.shield.fill",
            "Know where chat runs",
            "Private tool results are saved only when you choose Save. Chat uses MLX on iPhone or the labeled hosted fallback in Simulator when the system model is unavailable."
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
