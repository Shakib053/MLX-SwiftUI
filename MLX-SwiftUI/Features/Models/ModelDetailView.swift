import SwiftUI

struct ModelDetailView: View {
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

                    detailSection(
                        "Privacy",
                        text: "Prompts and model output stay on this device while a local model is selected."
                    )
                    detailSection("License", text: model.license)
                    detailSection(
                        "Production requirement",
                        text: "The app downloads the MLX Community checkpoint for \(model.repositoryID). " +
                            "Display the exact model revision, license text, and required notices."
                    )

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
