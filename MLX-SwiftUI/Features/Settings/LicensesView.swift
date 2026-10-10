import SwiftUI

struct LicensesView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        List {
            #if DEBUG && targetEnvironment(simulator)
            if appState.modelPreviewScenario != .actual {
                Text("Preview: model availability is simulated in Settings.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            #endif
            ForEach(LocalModel.catalog) { model in
                VStack(alignment: .leading, spacing: 8) {
                    Text(model.name).font(.headline)
                    Text(model.provider).font(.caption).foregroundStyle(.secondary)
                    Text(model.license).font(.footnote)
                    #if DEBUG && targetEnvironment(simulator)
                    Text(appState.previewDownloadedModels.contains(model) ? "Downloaded (preview)" : "Not downloaded")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    #else
                    Text(appState.downloadedModelIDs.contains(model.id) ? "Downloaded" : "Not downloaded")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    #endif
                    Link("Model source", destination: model.repositoryURL)
                    Link("License terms", destination: model.licenseURL)
                }
                .padding(.vertical, 6)
            }
        }
        .navigationTitle("Model Licenses")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }
}
