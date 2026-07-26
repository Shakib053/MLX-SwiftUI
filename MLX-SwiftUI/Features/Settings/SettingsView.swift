import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @State private var showsFeedback = false
    @State private var showsLicenses = false
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
                        appState.selectedTab = .models
                    } label: {
                        SettingsRow(
                            icon: "cpu",
                            color: .purple,
                            title: "Default model",
                            subtitle: "Used for new chats",
                            value: appState.activeModel.name
                        )
                    }
                    .foregroundStyle(.primary)

                    Toggle(isOn: $appState.hapticsEnabled) {
                        Label("Haptic feedback", systemImage: "waveform")
                    }
                }

                Section("About") {
                    Button {
                        showsFeedback = true
                    } label: {
                        Label("Send Feedback", systemImage: "bubble.left")
                    }

                    Button {
                        print("Rate MLX Chat tapped. Add the production App Store product URL before release.")
                    } label: {
                        Label("Rate MLX Chat", systemImage: "star")
                    }

                    Button {
                        showsLicenses = true
                    } label: {
                        Label("Model Licenses", systemImage: "doc.text")
                    }

                    LabeledContent("Version", value: appVersion)

                    Button("Replay Onboarding") {
                        showOnboarding()
                    }
                }

                #if DEBUG && targetEnvironment(simulator)
                SimulatorTestingSection()
                #endif
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showsFeedback) {
                FeedbackView()
            }
            .sheet(isPresented: $showsLicenses) {
                LicensesView()
                    .environment(appState)
            }
        }
    }

    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(version) (\(build))"
    }
}
