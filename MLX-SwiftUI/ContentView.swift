import SwiftUI

struct ContentView: View {
    @State private var appState = AppState()
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some View {
        @Bindable var appState = appState

        TabView(selection: $appState.selectedTab) {
            Tab("Chats", systemImage: "bubble.left.and.bubble.right", value: 0) {
                ChatsView()
            }

            Tab("Models", systemImage: "cpu", value: 1) {
                ModelsView()
            }

            Tab("Settings", systemImage: "gearshape", value: 2) {
                SettingsView {
                    hasCompletedOnboarding = false
                }
            }
        }
        .tint(.indigo)
        .environment(appState)
        .preferredColorScheme(appState.appearance.colorScheme)
        .fullScreenCover(isPresented: Binding(
            get: { !hasCompletedOnboarding },
            set: { if !$0 { hasCompletedOnboarding = true } }
        )) {
            OnboardingView {
                hasCompletedOnboarding = true
            }
            .preferredColorScheme(appState.appearance.colorScheme)
        }
    }
}

private struct ChatsView: View {
    @Environment(AppState.self) private var appState
    @State private var searchText = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    searchField
                    emptyState
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .frame(maxWidth: .infinity)
            }
            .background(AppBackground())
            .navigationTitle("Chats")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        ChatView()
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Start new conversation")
                }
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search conversations", text: $searchText)
                .textInputAutocapitalization(.never)
                .submitLabel(.search)
        }
        .padding(.horizontal, 14)
        .frame(height: 44)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(.primary.opacity(0.06))
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(.indigo.opacity(0.12))
                    .frame(width: 92, height: 92)
                Image(systemName: "bubble.left.and.text.bubble.right")
                    .font(.system(size: 38, weight: .medium))
                    .foregroundStyle(.indigo)
            }

            VStack(spacing: 7) {
                Text(searchText.isEmpty ? "No Conversations" : "No Results")
                    .font(.title2.weight(.bold))
                Text(searchText.isEmpty
                     ? "Start a private conversation with a model that runs on this device."
                     : "There are no saved conversations matching “\(searchText)”.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            NavigationLink {
                ChatView()
            } label: {
                Label("New Conversation", systemImage: "plus")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.roundedRectangle(radius: 14))
            .tint(.indigo)
            .accessibilityHint("Opens a new chat using \(appState.activeModel.name)")

            Label("\(appState.activeModel.shortName) • On device", systemImage: "lock.fill")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .padding(28)
        .frame(maxWidth: 440)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(.primary.opacity(0.07))
        }
        .padding(.top, 40)
    }
}

private struct ModelsView: View {
    @Environment(AppState.self) private var appState
    @State private var showsCatalog = false
    @State private var detailModel: LocalModel?
    @State private var replacementTarget: LocalModel?

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 22) {
                    overviewCard

                    SectionHeader(title: "On this iPhone", actionTitle: "Add model") {
                        showsCatalog = true
                    }

                    VStack(spacing: 12) {
                        ForEach(appState.downloadedModels) { model in
                            installedModelCard(model)
                        }
                    }

                    if let suggestion = LocalModel.catalog.first(where: {
                        !appState.downloadedModelIDs.contains($0.id)
                    }) {
                        SectionHeader(
                            title: appState.downloadedModels.count == AppState.modelLimit
                                ? "Both model slots are used"
                                : "Suggested second model"
                        )
                        suggestedCard(suggestion)
                    }

                    Label {
                        Text("Switching models does not delete chats. When both slots are full, choose one to remove before adding another.")
                    } icon: {
                        Image(systemName: "info.circle")
                            .foregroundStyle(.indigo)
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(16)
                    .glassCard(cornerRadius: 18)
                }
                .padding(20)
            }
            .background(AppBackground())
            .navigationTitle("Models")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showsCatalog = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add model")
                }
            }
            .sheet(isPresented: $showsCatalog) {
                ModelCatalogView(
                    replacementTarget: $replacementTarget
                )
                .environment(appState)
            }
            .sheet(item: $detailModel) { model in
                ModelDetailView(model: model)
                    .environment(appState)
            }
            .confirmationDialog(
                "Model limit reached",
                isPresented: Binding(
                    get: { replacementTarget != nil },
                    set: { if !$0 { replacementTarget = nil } }
                ),
                titleVisibility: .visible
            ) {
                ForEach(appState.downloadedModels) { installed in
                    Button("Remove \(installed.name)", role: .destructive) {
                        guard let target = replacementTarget else { return }
                        appState.remove(installed)
                        replacementTarget = nil
                        Task { await appState.download(target) }
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("You can keep up to two downloaded models. Remove one to continue.")
            }
        }
    }

    private var overviewCard: some View {
        VStack(spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text("MODEL LIBRARY")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                    Text("\(appState.downloadedModels.count) of \(AppState.modelLimit) models")
                        .font(.title2.weight(.bold))
                }
                Spacer()
                ZStack {
                    Circle().stroke(.secondary.opacity(0.16), lineWidth: 7)
                    Circle()
                        .trim(from: 0, to: Double(appState.downloadedModels.count) / Double(AppState.modelLimit))
                        .stroke(.indigo, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text("\(appState.downloadedModels.count)")
                        .font(.headline)
                }
                .frame(width: 62, height: 62)
            }

            HStack {
                ModelStat(icon: "sparkles", label: "Active", value: appState.activeModel.shortName)
                Divider().frame(height: 36)
                ModelStat(icon: "arrow.down.circle", label: "Storage", value: String(format: "%.2f GB", appState.storageUsed))
            }

            ProgressView(value: min(appState.storageUsed / 4, 1))
                .tint(.indigo)
        }
        .padding(20)
        .glassCard(cornerRadius: 24)
    }

    private func installedModelCard(_ model: LocalModel) -> some View {
        VStack(spacing: 14) {
            HStack(spacing: 13) {
                ModelMark(model: model)
                VStack(alignment: .leading, spacing: 4) {
                    Text(model.name).font(.headline)
                    Text("\(model.sizeLabel) · \(model.quantization) · \(model.focus)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if model.id == appState.activeModelID {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.indigo)
                } else {
                    Button("Use") { appState.activate(model) }
                        .buttonStyle(.bordered)
                }
            }
            Divider()
            HStack {
                Button("Details") { detailModel = model }
                Spacer()
                Button("Remove", role: .destructive) { appState.remove(model) }
                    .disabled(appState.downloadedModels.count == 1)
            }
            .font(.subheadline.weight(.semibold))
        }
        .padding(16)
        .glassCard(cornerRadius: 20)
    }

    private func suggestedCard(_ model: LocalModel) -> some View {
        VStack(spacing: 14) {
            HStack(spacing: 13) {
                ModelMark(model: model)
                VStack(alignment: .leading, spacing: 4) {
                    Text(model.name).font(.headline)
                    Text("\(model.sizeLabel) · \(model.focus)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("Fits")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.green)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(.green.opacity(0.12), in: Capsule())
            }

            if appState.downloadingModelID == model.id {
                ProgressView(value: appState.downloadProgress)
                    .tint(.indigo)
            } else {
                HStack {
                    Button("Details") { detailModel = model }
                        .buttonStyle(.bordered)
                    Button("Download") { beginDownload(model) }
                        .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(16)
        .glassCard(cornerRadius: 20)
    }

    private func beginDownload(_ model: LocalModel) {
        if appState.downloadedModels.count >= AppState.modelLimit {
            replacementTarget = model
        } else {
            Task { await appState.download(model) }
        }
    }
}

private struct ModelCatalogView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @Binding var replacementTarget: LocalModel?
    @State private var searchText = ""
    @State private var detailModel: LocalModel?

    var filteredModels: [LocalModel] {
        guard !searchText.isEmpty else { return LocalModel.catalog }
        return LocalModel.catalog.filter {
            "\($0.name) \($0.focus) \($0.provider)"
                .localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 14) {
                    ForEach(filteredModels) { model in
                        VStack(spacing: 14) {
                            HStack(spacing: 12) {
                                ModelMark(model: model)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(model.name).font(.headline)
                                    Text("\(model.sizeLabel) · \(model.quantization) · \(model.focus)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(appState.downloadedModelIDs.contains(model.id) ? "Downloaded" : "Compatible")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(.green)
                            }
                            HStack {
                                Button("Details") { detailModel = model }
                                    .buttonStyle(.bordered)
                                Button(appState.downloadedModelIDs.contains(model.id) ? "Installed" : "Download") {
                                    if appState.downloadedModels.count >= AppState.modelLimit {
                                        replacementTarget = model
                                    } else {
                                        Task { await appState.download(model) }
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(appState.downloadedModelIDs.contains(model.id))
                            }
                        }
                        .padding(16)
                        .glassCard(cornerRadius: 20)
                    }
                }
                .padding(20)
            }
            .background(AppBackground())
            .navigationTitle("Model Catalog")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search supported models")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(item: $detailModel) { model in
                ModelDetailView(model: model)
                    .environment(appState)
            }
        }
    }
}

private struct ModelDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    let model: LocalModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    HStack(spacing: 14) {
                        ModelMark(model: model, size: 58)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(model.name).font(.title2.bold())
                            Text(model.provider).foregroundStyle(.secondary)
                        }
                    }

                    Text(model.summary)

                    HStack {
                        ModelStat(icon: "arrow.down", label: "Download", value: model.sizeLabel)
                        ModelStat(icon: "cube", label: "Quantization", value: model.quantization)
                        ModelStat(icon: "wifi.slash", label: "After download", value: "Offline")
                    }

                    detailSection("Privacy", text: "Prompts and model output stay on this device while a local model is selected.")
                    detailSection("License", text: model.license)
                    detailSection("Production requirement", text: "Display the exact source repository, model revision, conversion author, license text, and all required notices.")

                    if appState.downloadedModelIDs.contains(model.id) {
                        Button(model.id == appState.activeModelID ? "Currently Active" : "Use This Model") {
                            appState.activate(model)
                            dismiss()
                        }
                        .buttonStyle(.borderedProminent)
                        .frame(maxWidth: .infinity)
                        .disabled(model.id == appState.activeModelID)
                    }
                }
                .padding(20)
            }
            .background(AppBackground())
            .navigationTitle("Model Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private func detailSection(_ title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title).font(.headline)
            Text(text).foregroundStyle(.secondary)
        }
    }
}

private struct SettingsView: View {
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
                        appState.selectedTab = 1
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

private struct FeedbackView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                Label("Support email", systemImage: "checkmark.circle.fill")
                    .font(.headline)
                    .foregroundStyle(.green)
                Text("support@localmind.app")
                    .textSelection(.enabled)

                Label("Suggested template", systemImage: "checkmark.circle.fill")
                    .font(.headline)
                    .foregroundStyle(.green)
                Text("Include your device, iOS version, app version, active model, and steps to reproduce the issue.")
                    .foregroundStyle(.secondary)

                Button("Compose Feedback Email") {
                    print("Feedback compose tapped. Configure the production support address and MessageUI composer.")
                }
                .buttonStyle(.borderedProminent)

                Spacer()
            }
            .padding(20)
            .navigationTitle("Send Feedback")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

private struct LicensesView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    var body: some View {
        NavigationStack {
            List(appState.downloadedModels) { model in
                VStack(alignment: .leading, spacing: 8) {
                    Text(model.name).font(.headline)
                    Text(model.provider).font(.caption).foregroundStyle(.secondary)
                    Text(model.license).font(.footnote)
                }
                .padding(.vertical, 6)
            }
            .navigationTitle("Model Licenses")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}

#if DEBUG && targetEnvironment(simulator)
private struct SimulatorTestingSection: View {
    @State private var scenario = SimulatorDownloadScenario.selected

    var body: some View {
        Section {
            Picker("Conversation scenario", selection: $scenario) {
                ForEach(SimulatorDownloadScenario.allCases) { scenario in
                    Text(scenario.title).tag(scenario)
                }
            }
        } header: {
            Text("Simulator Testing")
        } footer: {
            Text("The scenario applies to the next new conversation. Hosted chat uses Hugging Face and never loads MLX.")
        }
        .onChange(of: scenario) { _, value in
            SimulatorDownloadScenario.selected = value
        }
    }
}
#endif

private struct OnboardingView: View {
    let onFinish: () -> Void
    @State private var page = 0

    private let pages = [
        ("lock.fill", "Private AI, on your iPhone", "Chat with compact language models that run locally, even when you are offline."),
        ("cpu", "Download up to two models", "Keep one fast model and one specialized model. Only the selected model runs at a time."),
        ("checkmark.shield.fill", "Designed for local use", "Switch between downloaded models and keep prompts on device without cloud routing.")
    ]

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            TabView(selection: $page) {
                ForEach(pages.indices, id: \.self) { index in
                    VStack(spacing: 24) {
                        ZStack {
                            Circle()
                                .fill(.indigo.opacity(0.14))
                                .frame(width: 150, height: 150)
                            Image(systemName: pages[index].0)
                                .font(.system(size: 62, weight: .medium))
                                .foregroundStyle(.indigo)
                        }
                        Text(pages[index].1)
                            .font(.largeTitle.bold())
                            .multilineTextAlignment(.center)
                        Text(pages[index].2)
                            .font(.title3)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(28)
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))

            Button(page == pages.count - 1 ? "Start Using MLX Chat" : "Continue") {
                if page < pages.count - 1 {
                    withAnimation { page += 1 }
                } else {
                    onFinish()
                }
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.roundedRectangle(radius: 15))
            .tint(.indigo)
            .padding(24)
        }
        .background(AppBackground())
    }
}

private struct AppBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        LinearGradient(
            colors: colorScheme == .dark
                ? [.black, Color.indigo.opacity(0.20), Color.purple.opacity(0.14)]
                : [Color(.systemGroupedBackground), Color.indigo.opacity(0.08), Color.pink.opacity(0.06)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

private struct SectionHeader: View {
    let title: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        HStack {
            Text(title)
                .font(.title3.bold())
            Spacer()
            if let actionTitle, let action {
                Button(actionTitle, action: action)
            }
        }
    }
}

private struct ModelMark: View {
    let model: LocalModel
    var size: CGFloat = 48

    var body: some View {
        Text(model.initials)
            .font(.headline.bold())
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(
                LinearGradient(colors: model.colors, startPoint: .topLeading, endPoint: .bottomTrailing),
                in: RoundedRectangle(cornerRadius: size * 0.29, style: .continuous)
            )
    }
}

private struct ModelStat: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon).foregroundStyle(.indigo)
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.caption2).foregroundStyle(.secondary)
                Text(value).font(.caption.weight(.semibold)).lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct SettingsRow: View {
    let icon: String
    let color: Color
    let title: String
    let subtitle: String
    let value: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(color, in: RoundedRectangle(cornerRadius: 7))
            VStack(alignment: .leading) {
                Text(title)
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text(value).font(.caption).foregroundStyle(.secondary)
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
        }
    }
}

private extension View {
    func glassCard(cornerRadius: CGFloat) -> some View {
        background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(.primary.opacity(0.07))
            }
    }
}

#Preview {
    ContentView()
}
