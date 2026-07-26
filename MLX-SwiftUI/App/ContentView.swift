import SwiftUI

struct ContentView: View {
    @State private var appState = AppState()
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some View {
        MainTabView {
            hasCompletedOnboarding = false
        }
        .environment(appState)
        .preferredColorScheme(appState.appearance.colorScheme)
        .fullScreenCover(isPresented: onboardingBinding) {
            OnboardingView {
                hasCompletedOnboarding = true
            }
            .preferredColorScheme(appState.appearance.colorScheme)
        }
    }

    private var onboardingBinding: Binding<Bool> {
        Binding(
            get: { !hasCompletedOnboarding },
            set: { if !$0 { hasCompletedOnboarding = true } }
        )
    }
}

#Preview {
    ContentView()
}
