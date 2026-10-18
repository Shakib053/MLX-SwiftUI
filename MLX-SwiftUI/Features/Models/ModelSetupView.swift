import SwiftUI

struct ModelSetupView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var selectedModel = LocalModel.qwen

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Label("Set up on-device AI", systemImage: "cpu")
                        .font(.headline)
                    Text("Apple Foundation Models isn’t available on this device. Download a model once to use chat and AI tools offline.")
                    Text("A connection is needed for the download. After that, prompts and responses run on this device.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Choose a model") {
                    ForEach(LocalModel.catalog) { model in
                        Button {
                            selectedModel = model
                            appState.dismissDownloadError()
                        } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(model.name)
                                    Text("About \(model.sizeLabel) · \(model.focus)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if selectedModel.id == model.id {
                                    Image(systemName: "checkmark.circle.fill")
                                }
                            }
                        }
                        .disabled(appState.downloadingModelID != nil)
                    }
                }

                if appState.downloadingModelID != nil {
                    Section("Downloading") {
                        ProgressView(value: appState.downloadProgress)
                        Text("\(Int(appState.downloadProgress * 100))%")
                    }
                } else {
                    Section {
                        Button(appState.downloadedModelIDs.contains(selectedModel.id)
                               ? String(localized: "Use \(selectedModel.shortName)")
                               : appState.downloadError == nil
                                   ? String(localized: "Download \(selectedModel.shortName)") : String(localized: "Retry download")) {
                            beginSetup()
                        }
                    } footer: {
                        Text("Download size is approximate. Additional space may be needed to install and run the model.")
                    }
                }

                if let error = appState.downloadError {
                    Section {
                        Text(error).foregroundStyle(.red)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppBackground())
            .navigationTitle("Model Setup")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Not now") { dismiss() }
                }
            }
        }
    }

    private func beginSetup() {
        if appState.downloadedModelIDs.contains(selectedModel.id) {
            appState.activate(selectedModel)
            dismiss()
            return
        }
        Task {
            await appState.download(selectedModel)
            guard appState.downloadedModelIDs.contains(selectedModel.id) else { return }
            appState.activate(selectedModel)
            dismiss()
        }
    }
}
