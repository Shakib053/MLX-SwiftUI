import SwiftUI

struct ModelCatalogView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @Binding var replacementTarget: LocalModel?
    @State private var searchText = ""
    @State private var detailModel: LocalModel?

    private var filteredModels: [LocalModel] {
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
                        modelCard(model)
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

    private func modelCard(_ model: LocalModel) -> some View {
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
                    beginDownload(model)
                }
                .buttonStyle(.borderedProminent)
                .disabled(appState.downloadedModelIDs.contains(model.id))
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
