import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    let showOnboarding: () -> Void

    var body: some View {
        @Bindable var appState = appState

        NavigationStack {
            Form {
                Section {
                    Label("Private by design", systemImage: "lock.shield")
                        .font(.headline)
                    Text("Your chats and private tools use an available on-device model. Task results are saved only when you choose Save.")
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
                        Label("About MLX-SwiftUI", systemImage: "info.circle")
                    }
                }

                Section("Extended Features") {
                    NavigationLink {
                        FeedbackView()
                    } label: {
                        Label("Send Feedback", systemImage: "bubble.left")
                    }

                    Link(destination: URL(string: "https://mlx-swiftui-privacy-policy.vercel.app/")!) {
                        Label("Privacy Policy", systemImage: "hand.raised")
                    }
                }

                #if DEBUG && targetEnvironment(simulator)
                SimulatorTestingSection()
                #endif
            }
            .scrollContentBackground(.hidden)
            .background(AppBackground())
            .navigationTitle("Settings")
        }
    }

    private var displayedDefaultModelName: String {
        #if DEBUG && targetEnvironment(simulator)
        if appState.modelPreviewScenario != .actual { return String(localized: "Apple Foundation Models (preview)") }
        #endif
        return appState.defaultModelName
    }
}
