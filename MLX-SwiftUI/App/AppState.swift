import Foundation
import Observation
import WidgetKit
import HuggingFace
import MLXLMCommon
import OSLog

@MainActor
@Observable
final class AppState {
    static let modelLimit = 3

    var selectedTab: AppTab = .home
    var prefersFoundationModel: Bool {
        didSet { UserDefaults.standard.set(prefersFoundationModel, forKey: "prefersFoundationModel") }
    }
    var appearance: AppAppearance {
        didSet {
            UserDefaults.standard.set(appearance.rawValue, forKey: "appAppearance")
        }
    }
    var hapticsEnabled = true
    var downloadedModelIDs: [String]
    var activeModelID: String
    var downloadingModelID: String?
    var downloadProgress = 0.0
    var downloadError: String?

    private let downloadedModelsKey = "downloadedModelIDs"
    private let activeModelKey = "activeModelID"

    init() {
        prefersFoundationModel = UserDefaults.standard.object(forKey: "prefersFoundationModel") as? Bool ?? true
        let saved = UserDefaults.standard.string(forKey: "appAppearance")
        appearance = AppAppearance(rawValue: saved ?? "") ?? .system

        let savedIDs = UserDefaults.standard.stringArray(forKey: downloadedModelsKey) ?? []
        let validIDs = savedIDs.filter { savedID in
            LocalModel.catalog.contains { model in model.id == savedID }
        }
        let initialDownloadedIDs = validIDs.isEmpty ? [LocalModel.qwen.id] : validIDs
        downloadedModelIDs = initialDownloadedIDs

        let savedActiveID = UserDefaults.standard.string(forKey: activeModelKey)
        activeModelID = initialDownloadedIDs.contains(savedActiveID ?? "")
            ? savedActiveID!
            : initialDownloadedIDs[0]

        updateWidget()
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
        prefersFoundationModel = false
        persistModelState()
        updateWidget()
        AppLogger.app.info("Activated model: \(model.name, privacy: .public)")
    }

    func download(_ model: LocalModel) async {
        guard !downloadedModelIDs.contains(model.id), downloadingModelID == nil else { return }
        guard downloadedModelIDs.count < Self.modelLimit else {
            AppLogger.app.warning("Model limit reached before downloading \(model.name, privacy: .public)")
            return
        }

        downloadingModelID = model.id
        downloadProgress = 0
        downloadError = nil
        defer {
            downloadingModelID = nil
            downloadProgress = 0
        }

        #if targetEnvironment(simulator)
        downloadError = "Local model downloads are available on a physical iPhone."
        return
        #else
        do {
            _ = try await MLXModelLoader.load(
                configuration: model.configuration,
                progressHandler: { [weak self] progress in
                    Task { @MainActor [weak self] in
                        self?.downloadProgress = max(
                            self?.downloadProgress ?? 0,
                            min(max(progress.fractionCompleted, 0), 1)
                        )
                    }
                }
            )

            guard !Task.isCancelled else { return }
            downloadedModelIDs.append(model.id)
            persistModelState()
            updateWidget()
        } catch is CancellationError {
            return
        } catch {
            downloadError = error.localizedDescription
            AppLogger.app.error("Model download failed: \(model.name, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
        #endif

    }

    func dismissDownloadError() {
        downloadError = nil
    }

    func remove(_ model: LocalModel) {
        guard downloadedModelIDs.count > 1 else {
            AppLogger.app.warning("Cannot remove the last downloaded model")
            return
        }
        downloadedModelIDs.removeAll { $0 == model.id }
        if activeModelID == model.id {
            activeModelID = downloadedModelIDs[0]
        }
        persistModelState()
        removeCachedFiles(for: model)
        AppLogger.app.info("Removed model: \(model.name, privacy: .public)")
        updateWidget()
    }

    private func persistModelState() {
        UserDefaults.standard.set(downloadedModelIDs, forKey: downloadedModelsKey)
        UserDefaults.standard.set(activeModelID, forKey: activeModelKey)
    }

    private func removeCachedFiles(for model: LocalModel) {
        let components = model.repositoryID.split(separator: "/", maxSplits: 1).map(String.init)
        guard components.count == 2 else { return }

        let repo = Repo.ID(namespace: components[0], name: components[1])
        let cache = HubCache.default
        let paths = [
            cache.repoDirectory(repo: repo, kind: .model),
            cache.metadataDirectory(repo: repo, kind: .model),
            cache.lockPath(for: cache.repoDirectory(repo: repo, kind: .model))
        ]

        for path in paths where FileManager.default.fileExists(atPath: path.path) {
            try? FileManager.default.removeItem(at: path)
        }
    }

    private func updateWidget() {
        SharedWidgetData.save(activeModelName: activeModel.name)

        AppLogger.app.debug("Updated widget model to \(SharedWidgetData.activeModelName, privacy: .public)")

        WidgetCenter.shared.reloadTimelines(
            ofKind: "MLX_SwiftUIWidget"
        )
    }
}
