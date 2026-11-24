import SwiftUI

struct ModelDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    let model: LocalModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 14) {
                    ModelMark(model: model, size: 58)
                    Text(model.name).font(.largeTitle.bold()).accessibilityAddTraits(.isHeader)
                    Text(model.provider).font(.subheadline).foregroundStyle(.white.opacity(0.82))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
                .background(AppPalette.hero, in: RoundedRectangle(cornerRadius: 24))

                Text(model.summary)

                ViewThatFits(in: .horizontal) {
                    HStack { modelStats }
                    VStack(spacing: 8) { modelStats }
                }

                detailSection("Repository", text: model.repositoryID)

                detailSection(
                    "Privacy",
                    text: String(localized: "Prompts and model output stay on this device while a local model is selected.")
                )
                detailSection("License", text: model.license)

                if appState.downloadedModelIDs.contains(model.id) {
                    Button(model.id == appState.activeModelID && !appState.prefersFoundationModel
                           ? String(localized: "Currently Active") : String(localized: "Use This Model")) {
                        appState.activate(model)
                        dismiss()
                    }
                    .appPrimaryButton()
                    .frame(maxWidth: .infinity)
                    .disabled(model.id == appState.activeModelID && !appState.prefersFoundationModel)
                }
            }
            .padding(20)
        }
        .background(AppBackground())
        .navigationTitle("Model Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }

    @ViewBuilder private var modelStats: some View {
        ModelStat(icon: "arrow.down", label: "Download", value: model.sizeLabel)
        ModelStat(icon: "cube", label: "Quantization", value: model.quantization)
        ModelStat(icon: "wifi.slash", label: "After download", value: String(localized: "Offline"))
    }

    private func detailSection(_ title: LocalizedStringKey, text: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title).font(.headline)
            Text(text).foregroundStyle(.secondary)
        }
    }
}
