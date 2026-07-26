import SwiftUI

struct MainTabView: View {
    @Environment(AppState.self) private var appState
    let showOnboarding: () -> Void

    var body: some View {
        @Bindable var appState = appState

        TabView(selection: $appState.selectedTab) {
            Tab("Chats", systemImage: "bubble.left.and.bubble.right", value: AppTab.chats) {
                ChatsView()
            }

            Tab("Models", systemImage: "cpu", value: AppTab.models) {
                ModelsView()
            }

            Tab("Settings", systemImage: "gearshape", value: AppTab.settings) {
                SettingsView(showOnboarding: showOnboarding)
            }
        }
        .tint(.indigo)
    }
}
