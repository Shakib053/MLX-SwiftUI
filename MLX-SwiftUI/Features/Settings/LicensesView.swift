import SwiftUI

struct LicensesView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        List(appState.downloadedModels) { model in
            VStack(alignment: .leading, spacing: 8) {
                Text(model.name).font(.headline)
                Text(model.provider).font(.caption).foregroundStyle(.secondary)
                Text(model.license).font(.footnote)
            }
            .padding(.vertical, 6)
        }
        .navigationTitle("Model Licenses")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }
}
