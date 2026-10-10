import SwiftUI

struct DefaultModelView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        Form {
            Section {
                Label("Choose a model for new chats", systemImage: "bubble.left.and.sparkles")
                    .font(.headline)
                Text("Changing the default does not affect existing conversations.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Section {
                #if DEBUG && targetEnvironment(simulator)
                if appState.modelPreviewScenario != .actual {
                    modelRow(icon: "apple.intelligence", title: "Apple Foundation Models",
                             detail: "Built into this iPhone (preview)", selected: true)
                } else {
                    foundationModelButton
                }
                #else
                foundationModelButton
                #endif
            } header: {
                Text("Built in")
            } footer: {
                #if DEBUG && targetEnvironment(simulator)
                if appState.modelPreviewScenario == .actual && !appState.foundationModelAvailable {
                    Text("Apple Foundation Models are unavailable on this device.")
                }
                #else
                if !appState.foundationModelAvailable {
                    Text("Apple Foundation Models are unavailable on this device.")
                }
                #endif
            }

            Section {
                #if targetEnvironment(simulator)
                #if DEBUG
                if appState.modelPreviewScenario != .actual {
                    ForEach(appState.previewDownloadedModels) { model in
                        modelRow(icon: "cpu", title: model.name,
                                 detail: "Downloaded model preview · \(model.sizeLabel)", selected: false)
                    }
                } else {
                    Text("Local MLX models require a physical iPhone.")
                        .foregroundStyle(.secondary)
                }
                #else
                Text("Local MLX models require a physical iPhone.")
                    .foregroundStyle(.secondary)
                #endif
                #else
                ForEach(appState.downloadedModels) { model in
                    Button {
                        appState.activate(model)
                    } label: {
                        HStack(spacing: 12) {
                            ModelMark(model: model, size: 40)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(model.name)
                                    .font(.body.weight(.medium))
                                    .foregroundStyle(.primary)
                                Text("\(model.sizeLabel) · \(model.focus)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 8)
                            if model.id == appState.activeModelID && !appState.usesFoundationModel {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.tint)
                                    .accessibilityHidden(true)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .accessibilityAddTraits(model.id == appState.activeModelID && !appState.usesFoundationModel ? .isSelected : [])
                }
                #endif
            } header: {
                Text("Downloaded MLX models")
            } footer: {
                #if DEBUG && targetEnvironment(simulator)
                if appState.modelPreviewScenario != .actual {
                    Text("Preview only. Local MLX models cannot run in Simulator.")
                }
                #elseif !targetEnvironment(simulator)
                Text("Manage downloads in the Models tab.")
                #endif
            }
        }
        .navigationTitle("Default Model")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }

    private var foundationModelButton: some View {
        Button {
            appState.prefersFoundationModel = true
        } label: {
            modelRow(
                icon: "apple.intelligence",
                title: "Apple Foundation Models",
                detail: appState.foundationModelAvailable
                    ? "Built into this iPhone"
                    : "Unavailable on this device",
                selected: appState.usesFoundationModel
            )
        }
        .disabled(!appState.foundationModelAvailable)
    }

    private func modelRow(icon: String, title: String, detail: String, selected: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 40, height: 40)
                .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            if selected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.tint)
                    .accessibilityHidden(true)
            }
        }
        .contentShape(Rectangle())
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
