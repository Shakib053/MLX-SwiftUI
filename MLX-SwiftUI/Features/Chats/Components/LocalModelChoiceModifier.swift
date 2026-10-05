import SwiftUI

struct LocalModelChoiceModifier: ViewModifier {
    @Environment(AppState.self) private var appState
    @Binding var isPresented: Bool
    let launch: () -> Void

    func body(content: Content) -> some View {
        content.confirmationDialog(
            "Apple Foundation Models Unavailable",
            isPresented: $isPresented,
            titleVisibility: .visible
        ) {
            ForEach(appState.downloadedModels) { model in
                Button("Use \(model.name)") {
                    appState.activate(model)
                    launch()
                }
            }
            Button("Manage Models") {
                appState.selectedTab = .models
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Choose a downloaded local model before starting a new chat.")
        }
    }
}

extension View {
    func localModelChoice(
        isPresented: Binding<Bool>,
        launch: @escaping () -> Void
    ) -> some View {
        modifier(LocalModelChoiceModifier(isPresented: isPresented, launch: launch))
    }
}
