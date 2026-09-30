import SwiftUI

struct MainTabView: View {
    @Environment(AppState.self) private var appState
    let showOnboarding: () -> Void

    var body: some View {
        @Bindable var appState = appState

        TabView(selection: $appState.selectedTab) {
            Tab("Home", systemImage: "house", value: AppTab.home) {
                HomeView()
            }

            Tab("History", systemImage: "clock.arrow.circlepath", value: AppTab.history) {
                ChatsView()
            }

            Tab("Settings", systemImage: "gearshape", value: AppTab.settings) {
                SettingsView(showOnboarding: showOnboarding)
            }
        }
        .tint(.indigo)
    }
}
