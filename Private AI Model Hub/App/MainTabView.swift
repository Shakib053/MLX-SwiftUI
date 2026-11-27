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

            Tab("Models", systemImage: "cpu", value: AppTab.models) {
                ModelsView()
            }

            Tab("History", systemImage: "clock.arrow.circlepath", value: AppTab.history) {
                ChatsView()
            }

            Tab("Settings", systemImage: "gearshape", value: AppTab.settings) {
                SettingsView(showOnboarding: showOnboarding)
            }
        }
        .tint(AppPalette.accent)
    }
}

extension View {
    @ViewBuilder
    func mainTabBar(keepsPositionDuringKeyboard: Bool = false) -> some View {
        if keepsPositionDuringKeyboard {
            ZStack(alignment: .bottom) {
                self.safeAreaInset(edge: .bottom, spacing: 0) {
                    MainTabBar().hidden().accessibilityHidden(true)
                }

                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    MainTabBar()
                }
                .ignoresSafeArea(.keyboard, edges: .bottom)
            }
            .toolbar(.hidden, for: .tabBar)
        } else {
            toolbar(.hidden, for: .tabBar)
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    MainTabBar()
                }
        }
    }
}

private struct MainTabBar: View {
    @Environment(AppState.self) private var appState
    @Environment(\.self) private var environment

    private var tabAppearance: EnvironmentValues {
        var appearance = environment
        appearance.colorScheme = appState.appearance.colorScheme ?? environment.colorScheme
        return appearance
    }

    var body: some View {
        let appearance = tabAppearance
        let background = Color(AppPalette.background.resolve(in: appearance))
        let accent = Color(AppPalette.accent.resolve(in: appearance))

        HStack(spacing: 4) {
            tab("Home", systemImage: "house", selection: .home, accent: accent)
            tab("Models", systemImage: "cpu", selection: .models, accent: accent)
            tab("History", systemImage: "clock.arrow.circlepath", selection: .history, accent: accent)
            tab("Settings", systemImage: "gearshape", selection: .settings, accent: accent)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(alignment: .top) {
            background.ignoresSafeArea(edges: .bottom)
        }
        .overlay(alignment: .top) {
            Divider()
        }
    }

    private func tab(_ title: LocalizedStringKey, systemImage: String, selection: AppTab, accent: Color) -> some View {
        let isSelected = appState.selectedTab == selection

        return Button {
            appState.selectedTab = selection
        } label: {
            VStack(spacing: 3) {
                Image(systemName: systemImage)
                    .font(.body.weight(.semibold))
                    .accessibilityHidden(true)
                Text(title)
                    .font(.caption2.weight(isSelected ? .semibold : .regular))
            }
            .foregroundStyle(isSelected ? accent : Color.secondary)
            .frame(maxWidth: .infinity, minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
