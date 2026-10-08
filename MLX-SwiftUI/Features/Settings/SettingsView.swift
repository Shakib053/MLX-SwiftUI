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
                            color: .purple,
                            title: "Default Model",
                            subtitle: "Used for new chats",
                            value: appState.prefersFoundationModel && !appState.foundationModelAvailable && appState.hasUsableDefaultModel
                                ? "MLX fallback: \(appState.activeModel.shortName)"
                                : appState.defaultModelName
                        )
                    }

                    Toggle(isOn: $appState.hapticsEnabled) {
                        Label("Haptic feedback", systemImage: "waveform")
                    }
                }

                Section("About") {
                    NavigationLink {
                        FeedbackView()
                    } label: {
                        Label("Send Feedback", systemImage: "bubble.left")
                    }

                    NavigationLink {
                        LicensesView()
                            .environment(appState)
                    } label: {
                        Label("Model Licenses", systemImage: "doc.text")
                    }

                    LabeledContent("Version", value: appVersion)
                }

                #if DEBUG && targetEnvironment(simulator)
                SimulatorTestingSection()
                #endif
            }
            .navigationTitle("Settings")
        }
    }

    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(version) (\(build))"
    }
}
