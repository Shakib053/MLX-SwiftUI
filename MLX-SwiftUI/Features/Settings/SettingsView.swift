import SwiftUI
import OSLog

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    let showOnboarding: () -> Void

    var body: some View {
        @Bindable var appState = appState

        NavigationStack {
            Form {
                Section("Private tools") {
                    Label("Summarize, Rewrite, Extract, Read Image Text, and Analyze Document run only with an available on-device model.", systemImage: "lock.shield")
                    Text("Results are saved only when you tap Save. Saved results and their source appear in History.")
                    Text("Ask AI continues to use chat, which stays on device with Apple Foundation Models or MLX.")
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
                    Button {
                        appState.selectedTab = .models
                    } label: {
                        SettingsRow(
                            icon: "cpu",
                            color: .purple,
                            title: "Default model",
                            subtitle: "Used for new chats",
                            value: appState.prefersFoundationModel && !appState.foundationModelAvailable && appState.hasUsableDefaultModel
                                ? "MLX fallback: \(appState.activeModel.shortName)"
                                : appState.defaultModelName
                        )
                    }
                    .foregroundStyle(.primary)

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

                    Button {
                        AppLogger.app.info("Rate MLX Chat tapped. Add the production App Store product URL before release.")
                    } label: {
                        Label("Rate MLX Chat", systemImage: "star")
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
