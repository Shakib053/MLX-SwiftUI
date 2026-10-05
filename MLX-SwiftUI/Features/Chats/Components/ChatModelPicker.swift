import SwiftUI
import FoundationModels

struct ChatModelPicker: View {
    @Environment(AppState.self) private var appState
    @Binding var isPresented: Bool
    let selectedBackend: ChatBackendMode?
    let selectedModelID: String

    var body: some View {
        NavigationStack {
            List {
                if SystemLanguageModel.default.isAvailable {
                    Button {
                        appState.prefersFoundationModel = true
                        isPresented = false
                    } label: {
                        HStack {
                            Label("Apple Foundation Models", systemImage: "sparkles")
                            Spacer()
                            if selectedBackend == .foundation {
                                Image(systemName: "checkmark").foregroundStyle(.indigo)
                            }
                        }
                    }
                }
                ForEach(appState.downloadedModels) { model in
                    Button {
                        select(model)
                    } label: {
                        HStack(spacing: 12) {
                            Text(model.initials)
                                .font(.caption.bold())
                                .foregroundStyle(.white)
                                .frame(width: 38, height: 38)
                                .background(
                                    LinearGradient(
                                        colors: model.colors,
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    in: RoundedRectangle(cornerRadius: 11)
                                )
                            VStack(alignment: .leading) {
                                Text(model.name).foregroundStyle(.primary)
                                Text("\(model.focus) • \(model.sizeLabel)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if model.id == selectedModelID && selectedBackend == .local {
                                Image(systemName: "checkmark").foregroundStyle(.indigo)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Choose Model")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func select(_ model: LocalModel) {
        appState.activate(model)
        isPresented = false
    }
}
