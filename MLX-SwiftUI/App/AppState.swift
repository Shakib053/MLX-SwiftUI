import Foundation
import Observation

@MainActor
@Observable
final class AppState {
    static let modelLimit = 2

    var selectedTab: AppTab = .chats
    var appearance: AppAppearance {
        didSet {
            UserDefaults.standard.set(appearance.rawValue, forKey: "appAppearance")
        }
    }
    var hapticsEnabled = true
    var downloadedModelIDs: [String] = [LocalModel.qwen.id]
    var activeModelID = LocalModel.qwen.id
    var downloadingModelID: String?
    var downloadProgress = 0.0

    init() {
        let saved = UserDefaults.standard.string(forKey: "appAppearance")
        appearance = AppAppearance(rawValue: saved ?? "") ?? .system
    }

    var downloadedModels: [LocalModel] {
        downloadedModelIDs.compactMap { id in
            LocalModel.catalog.first { $0.id == id }
        }
    }

    var activeModel: LocalModel {
        LocalModel.catalog.first { $0.id == activeModelID } ?? .qwen
    }

    var storageUsed: Double {
        downloadedModels.reduce(0) { $0 + $1.sizeGB }
    }

    func activate(_ model: LocalModel) {
        guard downloadedModelIDs.contains(model.id) else { return }
        activeModelID = model.id
        print("Activated model: \(model.name)")
    }

    func download(_ model: LocalModel) async {
        guard !downloadedModelIDs.contains(model.id), downloadingModelID == nil else { return }
        guard downloadedModelIDs.count < Self.modelLimit else {
            print("Model limit reached; choose a model to remove before downloading \(model.name).")
            return
        }

        downloadingModelID = model.id
        downloadProgress = 0
        print("Prototype model download started: \(model.name)")

        for step in 1...20 {
            guard !Task.isCancelled else { break }
            try? await Task.sleep(for: .milliseconds(90))
            downloadProgress = Double(step) / 20
        }

        if !downloadedModelIDs.contains(model.id) {
            downloadedModelIDs.append(model.id)
        }
        downloadingModelID = nil
        downloadProgress = 0
        print(
            "Prototype model download completed: \(model.name). " +
            "Wire this catalog entry to the MLX downloader for production."
        )
    }

    func remove(_ model: LocalModel) {
        guard downloadedModelIDs.count > 1 else {
            print("At least one model must remain downloaded.")
            return
        }
        downloadedModelIDs.removeAll { $0 == model.id }
        if activeModelID == model.id {
            activeModelID = downloadedModelIDs[0]
        }
        print("Removed model from prototype library: \(model.name)")
    }
}
