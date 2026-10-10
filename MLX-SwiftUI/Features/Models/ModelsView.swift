import SwiftUI

struct ModelsView: View {
    @Environment(AppState.self) private var appState
    @State private var showsCatalog = false
    @State private var replacementTarget: LocalModel?

    private let accent = Color(red: 0.43, green: 0.42, blue: 1)

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
            return "Default"
        }
        #endif
        guard appState.hasUsableDefaultModel else { return "Unavailable" }
        if appState.usesFoundationModel { return "Default" }
        return appState.prefersFoundationModel ? "MLX fallback" : "Default"
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
                            Button("Add model") { showsCatalog = true }
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
                            .swipeActions(edge: .trailing) {
                                Button("Delete", systemImage: "trash", role: .destructive) {
                                    appState.remove(model)
                                }
                            }
                    }

                    if appState.downloadedModels.isEmpty {
                        ContentUnavailableView("No MLX models downloaded", systemImage: "square.stack.3d.up.slash")
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }

                    if let suggestion = LocalModel.catalog.first(where: {
                        !appState.downloadedModelIDs.contains($0.id)
                    }) {
                        VStack(alignment: .leading, spacing: 16) {
                            Text(appState.downloadedModels.count == AppState.modelLimit
                                 ? "All model slots are used" : "Suggested model")
                                .font(.title2.bold())
                            suggestedCard(suggestion)
                        }
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
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
                    .modelCardBackground()
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    #endif
            }
            .listStyle(.plain)
            .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
            .background(AppBackground())
            .navigationTitle("Models")
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
                Text(appState.downloadError ?? "The model could not be downloaded.")
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
                Text(appState.deletionError ?? "The model could not be deleted.")
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
                        Text(String(format: "%.2f GB", displayedStorageUsed))
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .font(.subheadline)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(.secondary.opacity(0.25))
                    Capsule().fill(accent)
                        .frame(width: geometry.size.width * min(displayedStorageUsed / 3, 1))
                }
            }
            .frame(height: 6)
            .accessibilityLabel("Model storage, \(String(format: "%.2f", displayedStorageUsed)) gigabytes")
        }
        .padding(20)
        .modelCardBackground()
    }

    private var foundationModelCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 13) {
                Image(systemName: "sparkles")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: 54, height: 54)
                    .background(accent.gradient, in: RoundedRectangle(cornerRadius: 16))
                VStack(alignment: .leading, spacing: 4) {
                    Text("Apple Foundation Models")
                        .font(.headline)
                    Text(displayedFoundationAvailable ? "Built into this iPhone" : "Unavailable on this device")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                if displayedFoundationAvailable {
                    Text("Default")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(accent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(accent.opacity(0.2), in: Capsule())
                } else if appState.foundationModelAvailable {
                    Button("Use") { appState.prefersFoundationModel = true }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(accent)
                }
            }

            if !displayedFoundationAvailable {
                #if targetEnvironment(simulator)
                Text("Foundation Models are unavailable here. Local MLX models require a physical iPhone.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                #else
                Text(appState.downloadedModels.isEmpty
                     ? "Download an MLX model to start chatting on this iPhone."
                     : "New chats will try \(appState.activeModel.name) on this iPhone. If it cannot load, the app will show an error.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                #endif
            }
        }
        .padding(18)
        .modelCardBackground()
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
            Divider()
            NavigationLink("Details") {
                ModelDetailView(model: model)
                    .environment(appState)
            }
            .font(.subheadline.weight(.semibold))
        }
        .padding(18)
        .modelCardBackground()
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
                            Text(appState.prefersFoundationModel ? "Fallback" : "Default")
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
                    Button("Use") { appState.activate(model) }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(accent)
                }
            }
            Divider()
            HStack {
                NavigationLink {
                    ModelDetailView(model: model)
                        .environment(appState)
                } label: {
                    Text("Details")
                }
                .foregroundStyle(accent)
                Spacer()
                Button("Delete", role: .destructive) { appState.remove(model) }
            }
            .font(.subheadline.weight(.semibold))
        }
        .padding(18)
        .modelCardBackground()
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

            if appState.downloadingModelID == model.id {
                ProgressView(value: appState.downloadProgress)
                    .tint(accent)
            } else {
                HStack(spacing: 8) {
                    NavigationLink {
                        ModelDetailView(model: model)
                            .environment(appState)
                    } label: {
                        Text("Details")
                            .frame(minWidth: 78)
                    }
                    .buttonStyle(.bordered)
                    .tint(accent)
                    Button("Download") { beginDownload(model) }
                        .buttonStyle(.borderedProminent)
                        .tint(accent)
                }
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
            }
        }
        .padding(18)
        .modelCardBackground()
    }

    private func beginDownload(_ model: LocalModel) {
        if appState.downloadedModels.count >= AppState.modelLimit {
            replacementTarget = model
        } else {
            Task { await appState.download(model) }
        }
    }
}

private extension View {
    func modelCardBackground() -> some View {
        background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(.primary.opacity(0.1))
                }
        }
    }
}
