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
            OnboardingView { model in
                hasCompletedOnboarding = true
                if let model {
                    appState.selectedTab = .home
                    #if !targetEnvironment(simulator)
                    appState.setUpStarterModel(model)
                    #endif
                }
            }
            .environment(appState)
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
