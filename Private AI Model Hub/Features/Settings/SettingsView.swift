import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    let showOnboarding: () -> Void

    var body: some View {
        @Bindable var appState = appState

        NavigationStack {
            Form {
                Section {
                    Label("Data & privacy", systemImage: "lock.shield")
                        .font(.title3.bold())
                        .foregroundStyle(AppPalette.accent)
                    Text("With an on-device model, prompts and results are processed on this device. Task results enter History when you choose Save.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Section {
                    Picker("Appearance", selection: $appState.appearance) {
                        ForEach(AppAppearance.allCases) { appearance in
                            Label(appearance.title, systemImage: appearance.icon)
                                .tag(appearance)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Appearance")
                } footer: {
                    Text("System follows the iPhone appearance automatically.")
                }

                Section("General") {
                    NavigationLink {
                        DefaultModelView()
                    } label: {
                        SettingsRow(
                            icon: "cpu",
                            color: AppPalette.accent,
                            title: "Default Model",
                            subtitle: "Used for new chats",
                            value: appState.prefersFoundationModel && !appState.foundationModelAvailable && appState.hasUsableDefaultModel
                                ? String(localized: "MLX fallback: \(appState.activeModel.shortName)")
                                : displayedDefaultModelName
                        )
                    }
                }

                Section("About") {
                    NavigationLink {
                        AboutView()
                    } label: {
                        Label("About Private AI Model Hub", systemImage: "info.circle")
                    }
                }

                Section("Support & privacy") {
                    NavigationLink {
                        FeedbackView()
                    } label: {
                        Label("Contact Us", systemImage: "envelope")
                    }

                    Link(destination: URL(string: "https://mlx-swiftui-privacy-policy.vercel.app/")!) {
                        Label("Privacy Policy", systemImage: "hand.raised")
                    }
                }

                #if DEBUG
                Section {
                    DisclosureGroup {
                        Button("Replay introduction", systemImage: "play.circle", action: showOnboarding)
                    } label: {
                        Label("Debug", systemImage: "ladybug")
                    }
                }
                #endif

                #if DEBUG && targetEnvironment(simulator)
                SimulatorTestingSection()
                #endif
            }
            .scrollContentBackground(.hidden)
            .background(AppBackground())
            .navigationTitle("Settings")
            .mainTabBar()
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var displayedDefaultModelName: String {
        #if DEBUG && targetEnvironment(simulator)
        if appState.modelPreviewScenario != .actual { return String(localized: "Apple Foundation Models (preview)") }
        #endif
        return appState.defaultModelName
    }
}
