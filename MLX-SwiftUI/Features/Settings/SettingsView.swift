import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @State private var showsModels = false
    let showOnboarding: () -> Void

    var body: some View {
        @Bindable var appState = appState

        NavigationStack {
            Form {
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
                        showsModels = true
                    } label: {
                        SettingsRow(
                            icon: "cpu",
                            color: .purple,
                            title: "Default model",
                            subtitle: "Used for new chats",
                            value: appState.prefersFoundationModel ? "Apple Foundation Models" : appState.activeModel.name
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
                        print("Rate MLX Chat tapped. Add the production App Store product URL before release.")
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
            .sheet(isPresented: $showsModels) {
                ModelsView()
            }
        }
    }

    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(version) (\(build))"
    }
}
