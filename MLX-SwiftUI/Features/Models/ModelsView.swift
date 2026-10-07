import SwiftUI

struct ModelsView: View {
    @Environment(AppState.self) private var appState
    @State private var showsCatalog = false
    @State private var replacementTarget: LocalModel?

    private let accent = Color(red: 0.43, green: 0.42, blue: 1)

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 28) {
                    overviewCard

                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("On this iPhone")
                                .font(.title2.bold())
                            Spacer()
                            Button("Add model") { showsCatalog = true }
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(accent)
                        }

                        foundationModelCard

                        ForEach(appState.downloadedModels) { model in
                            installedModelCard(model)
                        }
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
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .background(AppBackground())
            .navigationTitle("Models")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
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
            .confirmationDialog(
                "Model limit reached",
                isPresented: replacementDialogBinding,
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
                    Text("\(appState.downloadedModels.count) of \(AppState.modelLimit) models")
                        .font(.title.bold())
                }
                Spacer()
                ZStack {
                    Circle().stroke(.secondary.opacity(0.2), lineWidth: 7)
                    Circle()
                        .trim(from: 0, to: Double(appState.downloadedModels.count) / Double(AppState.modelLimit))
                        .stroke(accent, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text("\(appState.downloadedModels.count)")
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
                        Text(appState.hasUsableDefaultModel
                             ? (appState.usesFoundationModel ? "Default" :
                                appState.prefersFoundationModel ? "MLX fallback" : "Default")
                             : "Unavailable")
                            .foregroundStyle(.secondary)
                        Text(appState.usesFoundationModel ? "Apple Foundation Models" : appState.defaultModelName)
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
                        Text(String(format: "%.2f GB", appState.storageUsed))
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
                        .frame(width: geometry.size.width * min(appState.storageUsed / 3, 1))
                }
            }
            .frame(height: 6)
            .accessibilityLabel("Model storage, \(String(format: "%.2f", appState.storageUsed)) gigabytes")
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
                    Text(appState.foundationModelAvailable ? "Built into this iPhone" : "Unavailable on this device")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                if appState.usesFoundationModel {
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

            if !appState.foundationModelAvailable {
                #if targetEnvironment(simulator)
                Text("Foundation Models are unavailable here. Local MLX models require a physical iPhone.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                #else
                Text("New chats will try \(appState.activeModel.name) on this iPhone. If it cannot load, the app will show an error.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                #endif
            }
        }
        .padding(18)
        .modelCardBackground()
    }

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
                Button("Remove", role: .destructive) { appState.remove(model) }
                    .disabled(appState.downloadedModels.count == 1)
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
