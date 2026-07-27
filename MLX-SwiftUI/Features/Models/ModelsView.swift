import SwiftUI

struct ModelsView: View {
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
                        Text(
                            "Switching models does not delete chats. " +
                            "When both slots are full, choose one to remove before adding another."
                        )
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
                ModelCatalogView(replacementTarget: $replacementTarget)
                    .environment(appState)
            }
            .sheet(item: $detailModel) { model in
                ModelDetailView(model: model)
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
                Text("You can keep up to two downloaded models. Remove one to continue.")
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
                ModelStat(
                    icon: "arrow.down.circle",
                    label: "Storage",
                    value: String(format: "%.2f GB", appState.storageUsed)
                )
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
