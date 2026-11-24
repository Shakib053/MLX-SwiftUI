import SwiftUI

struct ModelsView: View {
    @Environment(AppState.self) private var appState
    @State private var showsCatalog = false
    @State private var replacementTarget: LocalModel?
    @State private var removalTarget: LocalModel?
    @State private var expandedModelID: String?
    @State private var feedback: String?

    private let accent = AppPalette.accent

    private var displayedModels: [LocalModel] {
        #if DEBUG && targetEnvironment(simulator)
        return appState.previewDownloadedModels
        #else
        return appState.downloadedModels
        #endif
    }

    private var displayedFoundationAvailable: Bool {
        #if DEBUG && targetEnvironment(simulator)
        return appState.previewFoundationModelAvailable
        #else
        return appState.foundationModelAvailable
        #endif
    }

    private var displayedStorageUsed: Double {
        displayedModels.reduce(0) { $0 + $1.sizeGB }
    }

    private var displayedDefaultLabel: String {
        #if DEBUG && targetEnvironment(simulator)
        if appState.modelPreviewScenario != .actual {
            return String(localized: "Default")
        }
        #endif
        guard appState.hasUsableDefaultModel else { return String(localized: "Unavailable") }
        if appState.usesFoundationModel { return String(localized: "Default") }
        return appState.prefersFoundationModel ? String(localized: "MLX fallback") : String(localized: "Default")
    }

    private var displayedDefaultName: String {
        #if DEBUG && targetEnvironment(simulator)
        if appState.modelPreviewScenario != .actual { return "Apple Foundation Models" }
        #endif
        return appState.usesFoundationModel ? "Apple Foundation Models" : appState.defaultModelName
    }

    var body: some View {
        NavigationStack {
            List {
                    overviewCard
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)

                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("On this iPhone")
                                .font(.title2.bold())
                            Spacer()
                            #if !targetEnvironment(simulator)
                            Button("Browse catalog", systemImage: "arrow.up.right") { showsCatalog = true }
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(accent)
                            #endif
                        }

                        foundationModelCard
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)

                    #if targetEnvironment(simulator)
                    #if DEBUG
                    if appState.modelPreviewScenario != .actual {
                        Text("Model availability preview. MLX models are not downloaded or runnable in Simulator.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .listRowBackground(Color.clear)
                        ForEach(displayedModels) { model in
                            previewInstalledModelCard(model)
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                        }
                    } else {
                        simulatorUnavailableView
                    }
                    #else
                    simulatorUnavailableView
                    #endif
                    #else
                    ForEach(appState.downloadedModels) { model in
                        installedModelCard(model)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button("Delete", systemImage: "trash", role: .destructive) {
                                    removalTarget = model
                                }
                            }
                    }

                    if appState.downloadedModels.isEmpty {
                        ContentUnavailableView("No MLX models downloaded", systemImage: "square.stack.3d.up.slash")
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }

                    if appState.downloadedModels.count < AppState.modelLimit {
                        let suggestions = LocalModel.catalog.filter {
                            !appState.downloadedModelIDs.contains($0.id)
                        }
                        if !suggestions.isEmpty {
                            Text("Suggested models")
                                .font(.title2.bold())
                                .accessibilityAddTraits(.isHeader)
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                            ForEach(suggestions) { model in
                                suggestedCard(model)
                                    .listRowBackground(Color.clear)
                                    .listRowSeparator(.hidden)
                            }
                        }
                    }

                    Label {
                        Text("Switching models does not delete chats. When all slots are full, choose one to remove before adding another.")
                    } icon: {
                        Image(systemName: "info.circle")
                            .foregroundStyle(accent)
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .appCard()
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    #endif
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
            .background(AppBackground())
            .safeAreaInset(edge: .bottom) {
                if let feedback {
                    Text(feedback)
                        .font(.footnote.weight(.semibold))
                        .padding(12)
                        .background(.regularMaterial, in: Capsule())
                        .padding(.bottom, 8)
                        .allowsHitTesting(false)
                }
            }
            .task(id: feedback) {
                guard feedback != nil else { return }
                do {
                    try await Task.sleep(for: .seconds(2))
                    feedback = nil
                } catch is CancellationError {
                    return
                } catch {
                    feedback = nil
                }
            }
            .navigationTitle("Models")
            .mainTabBar()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                #if !targetEnvironment(simulator)
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showsCatalog = true } label: {
                        Image(systemName: "plus")
                            .font(.title3.weight(.medium))
                            .foregroundStyle(accent)
                            .frame(width: 40, height: 40)
                            .background(.primary.opacity(0.05), in: Circle())
                    }
                    .accessibilityLabel("Add model")
                }
                #endif
            }
            .navigationDestination(isPresented: $showsCatalog) {
                ModelCatalogView(replacementTarget: $replacementTarget)
                    .environment(appState)
            }
            .alert(
                "Model download failed",
                isPresented: Binding(
                    get: { appState.downloadError != nil },
                    set: { if !$0 { appState.dismissDownloadError() } }
                )
            ) {
                Button("OK", role: .cancel) { appState.dismissDownloadError() }
            } message: {
                Text(appState.downloadError ?? String(localized: "The model could not be downloaded."))
            }
            .alert(
                "Model deletion failed",
                isPresented: Binding(
                    get: { appState.deletionError != nil },
                    set: { if !$0 { appState.dismissDeletionError() } }
                )
            ) {
                Button("OK", role: .cancel) { appState.dismissDeletionError() }
            } message: {
                Text(appState.deletionError ?? String(localized: "The model could not be deleted."))
            }
            .alert(
                "Delete “\(removalTarget?.name ?? "")”?",
                isPresented: Binding(
                    get: { removalTarget != nil },
                    set: { if !$0 { removalTarget = nil } }
                ),
                presenting: removalTarget
            ) { model in
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    guard appState.remove(model) else { return }
                    if expandedModelID == model.id { expandedModelID = nil }
                    showFeedback(String(localized: "Model deleted · chats kept"))
                }
            } message: { model in
                Text(deletionMessage(for: model))
            }
            .confirmationDialog(
                "Model limit reached",
                isPresented: replacementDialogBinding,
                titleVisibility: .visible
            ) {
                ForEach(appState.downloadedModels) { installed in
                    Button("Remove \(installed.name)", role: .destructive) {
                        guard let target = replacementTarget else { return }
                        guard appState.remove(installed) else { return }
                        replacementTarget = nil
                        Task { await appState.download(target) }
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("You can keep up to three downloaded models. Remove one to continue.")
            }
        }
    }

    private var replacementDialogBinding: Binding<Bool> {
        Binding(
            get: { replacementTarget != nil },
            set: { if !$0 { replacementTarget = nil } }
        )
    }

    private var overviewCard: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 7) {
                    Text("DOWNLOADED MLX MODELS")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text("\(displayedModels.count) of \(AppState.modelLimit) models")
                        .font(.title.bold())
                }
                Spacer()
                ZStack {
                    Circle().stroke(.secondary.opacity(0.2), lineWidth: 7)
                    Circle()
                        .trim(from: 0, to: Double(displayedModels.count) / Double(AppState.modelLimit))
                        .stroke(accent, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text("\(displayedModels.count)")
                        .font(.title3.weight(.semibold))
                }
                .frame(width: 64, height: 64)
                .accessibilityHidden(true)
            }

            HStack(spacing: 16) {
                HStack(spacing: 12) {
                    Image(systemName: "sparkles")
                        .font(.title3)
                        .foregroundStyle(accent)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(displayedDefaultLabel)
                            .foregroundStyle(.secondary)
                        Text(displayedDefaultName)
                            .fontWeight(.semibold)
                            .lineLimit(2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Rectangle()
                    .fill(.secondary.opacity(0.25))
                    .frame(width: 1, height: 48)

                HStack(spacing: 10) {
                    Image(systemName: "arrow.down.circle")
                        .font(.title3)
                        .foregroundStyle(accent)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Storage")
                            .foregroundStyle(.secondary)
                        Text("\(displayedStorageUsed, format: .number.precision(.fractionLength(2))) GB")
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .font(.subheadline)

            ProgressView(value: Double(displayedModels.count), total: Double(AppState.modelLimit))
                .tint(accent)
                .accessibilityLabel("Downloaded model slots")
                .accessibilityValue("\(displayedModels.count) of \(AppState.modelLimit)")
        }
        .padding(20)
        .appCard()
    }

    private var foundationModelCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 13) {
                Image(systemName: "sparkles")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: 54, height: 54)
                    .background(AppPalette.accentFill, in: RoundedRectangle(cornerRadius: 16))
                VStack(alignment: .leading, spacing: 4) {
                    Text("Apple Foundation Models")
                        .font(.headline)
                    Text(displayedFoundationAvailable ? String(localized: "Built into this iPhone") : String(localized: "Unavailable on this device"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                if displayedFoundationAvailable {
                    if appState.usesFoundationModel || !appState.foundationModelAvailable {
                        Text("Default")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(accent)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(accent.opacity(0.2), in: Capsule())
                    } else {
                        Button("Use") { appState.prefersFoundationModel = true }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(accent)
                    }
                }
            }

            if !displayedFoundationAvailable {
                #if targetEnvironment(simulator)
                Text("Foundation Models are unavailable here. Local MLX models require a physical iPhone.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                #else
                Text(appState.downloadedModels.isEmpty
                     ? String(localized: "Download an MLX model to start chatting on this iPhone.")
                     : String(localized: "New chats will try \(appState.activeModel.name) on this iPhone. If it cannot load, the app will show an error."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                #endif
            }
        }
        .padding(18)
        .appCard()
    }

    private var simulatorUnavailableView: some View {
        ContentUnavailableView("Local MLX models require a physical iPhone", systemImage: "iphone")
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
    }

    #if DEBUG && targetEnvironment(simulator)
    private func previewInstalledModelCard(_ model: LocalModel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 13) {
                ModelMark(model: model, size: 54)
                VStack(alignment: .leading, spacing: 4) {
                    Text(model.name).font(.headline)
                    Text("\(model.sizeLabel) · \(model.quantization) · \(model.focus)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            inlineDetails(model)
            Divider()
            detailsButton(model)
        }
        .padding(18)
        .appCard()
    }
    #endif

    private func installedModelCard(_ model: LocalModel) -> some View {
        VStack(spacing: 16) {
            HStack(spacing: 13) {
                ModelMark(model: model, size: 54)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 7) {
                        Text(model.name)
                            .font(.headline)
                            .lineLimit(2)
                        if model.id == appState.activeModelID && !appState.usesFoundationModel {
                            Text(appState.prefersFoundationModel ? String(localized: "Fallback") : String(localized: "Default"))
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(accent)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(accent.opacity(0.2), in: Capsule())
                        }
                    }
                    Text("\(model.sizeLabel) · \(model.quantization) · \(model.focus)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                if model.id != appState.activeModelID || appState.prefersFoundationModel {
                    Button("Use") {
                        appState.activate(model)
                        showFeedback(String(localized: "\(model.name) is now the default"))
                    }
                    .buttonStyle(.borderless)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(accent)
                } else {
                    Text("In use")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            inlineDetails(model)
            Divider()
            HStack {
                detailsButton(model)
                Spacer()
                Button("Delete", role: .destructive) { removalTarget = model }
                    .buttonStyle(.borderless)
            }
            .font(.subheadline.weight(.semibold))
        }
        .padding(18)
        .appCard()
    }

    private func suggestedCard(_ model: LocalModel) -> some View {
        VStack(spacing: 16) {
            HStack(spacing: 13) {
                ModelMark(model: model, size: 54)
                VStack(alignment: .leading, spacing: 4) {
                    Text(model.name).font(.headline)
                    Text("\(model.sizeLabel) · \(model.focus)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("Fits")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.green)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.green.opacity(0.16), in: Capsule())
            }

            inlineDetails(model)
            if appState.downloadingModelID == model.id {
                let progress = appState.downloadProgress
                ProgressView(value: progress) {
                    if progress >= 1 {
                        Text("Preparing model…")
                    } else {
                        Text("Downloading…")
                    }
                } currentValueLabel: {
                    Text(min(progress, progress >= 1 ? 1 : 0.99), format: .percent.precision(.fractionLength(0)))
                        .monospacedDigit()
                }
                .tint(accent)
            }

            HStack {
                detailsButton(model)
                Spacer()
                if appState.downloadingModelID != model.id {
                    Button("Download", systemImage: "arrow.down") {
                        Task {
                            await appState.download(model)
                            if appState.downloadedModelIDs.contains(model.id) {
                                showFeedback(String(localized: "Download complete"))
                            }
                        }
                    }
                    .appPrimaryButton()
                    .disabled(appState.downloadingModelID != nil)
                }
            }
            .font(.subheadline.weight(.semibold))
        }
        .padding(18)
        .appCard()
    }

    @ViewBuilder
    private func inlineDetails(_ model: LocalModel) -> some View {
        if expandedModelID == model.id {
            Text(model.summary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func detailsButton(_ model: LocalModel) -> some View {
        Button(expandedModelID == model.id ? String(localized: "Hide details") : String(localized: "Details")) {
            expandedModelID = expandedModelID == model.id ? nil : model.id
        }
        .buttonStyle(.borderless)
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(accent)
    }

    private func showFeedback(_ message: String) {
        feedback = message
        AccessibilityNotification.Announcement(message).post()
    }

    private func deletionMessage(for model: LocalModel) -> String {
        let removal = String(localized: "This removes the model (\(model.sizeLabel)) from your iPhone.")
        let recovery = String(localized: "Your chats are kept, and you can download it again anytime.")
        guard model.id == appState.activeModelID, !appState.usesFoundationModel else {
            return "\(removal) \(recovery)"
        }

        let nextModel: String
        if let replacement = appState.downloadedModels.first(where: { $0.id != model.id }) {
            nextModel = String(localized: "New chats will use \(replacement.name).")
        } else if appState.foundationModelAvailable {
            nextModel = String(localized: "New chats will use Apple Foundation Models.")
        } else {
            nextModel = String(localized: "Download a model to start new chats.")
        }
        return "\(removal) \(nextModel) \(recovery)"
    }
}
