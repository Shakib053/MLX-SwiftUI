import SwiftUI

struct ModelCatalogView: View {
    @Environment(AppState.self) private var appState
    @Binding var replacementTarget: LocalModel?
    @State private var searchText = ""

    private var filteredModels: [LocalModel] {
        guard !searchText.isEmpty else { return LocalModel.catalog }
        return LocalModel.catalog.filter {
            "\($0.name) \($0.focus) \($0.provider)"
                .localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
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
        .toolbar(.hidden, for: .tabBar)
        .onAppear { appState.refreshInstalledModels() }
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
                Text(appState.downloadedModelIDs.contains(model.id) ? "Downloaded" :
                        appState.downloadingModelID == model.id ? "Downloading" : "Not downloaded")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(appState.downloadedModelIDs.contains(model.id) ? Color.green : Color.secondary)
            }
            if appState.downloadingModelID == model.id {
                ProgressView(value: appState.downloadProgress)
            }
            HStack {
                NavigationLink {
                    ModelDetailView(model: model)
                        .environment(appState)
                } label: {
                    Text("Details")
                }
                    .buttonStyle(.bordered)
                Button(appState.downloadedModelIDs.contains(model.id) ? "Installed" :
                        appState.downloadingModelID == model.id ? "Downloading" : "Download") {
                    beginDownload(model)
                }
                .buttonStyle(.borderedProminent)
                .disabled(appState.downloadedModelIDs.contains(model.id) || appState.downloadingModelID != nil)
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
