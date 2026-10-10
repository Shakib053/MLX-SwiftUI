import Foundation
import FoundationModels
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
        didSet {
            UserDefaults.standard.set(prefersFoundationModel, forKey: "prefersFoundationModel")
            updateWidget()
        }
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
    var deletionError: String?

    private let downloadedModelsKey = "downloadedModelIDs"
    private let activeModelKey = "activeModelID"

    init() {
        prefersFoundationModel = UserDefaults.standard.object(forKey: "prefersFoundationModel") as? Bool ?? true
        let saved = UserDefaults.standard.string(forKey: "appAppearance")
        appearance = AppAppearance(rawValue: saved ?? "") ?? .system

        #if targetEnvironment(simulator)
        let initialDownloadedIDs: [String] = []
        #else
        let savedIDs = UserDefaults.standard.stringArray(forKey: downloadedModelsKey) ?? []
        let validIDs = savedIDs.filter { savedID in
            LocalModel.catalog.contains { model in model.id == savedID }
        }
        let initialDownloadedIDs = validIDs
        #endif
        downloadedModelIDs = initialDownloadedIDs

        let savedActiveID = UserDefaults.standard.string(forKey: activeModelKey)
        activeModelID = initialDownloadedIDs.contains(savedActiveID ?? "")
            ? savedActiveID!
            : (initialDownloadedIDs.first ?? "")

        updateWidget()
    }

    var downloadedModels: [LocalModel] {
        downloadedModelIDs.compactMap { id in
            LocalModel.catalog.first { $0.id == id }
        }
    }

    #if DEBUG && targetEnvironment(simulator)
    var modelPreviewScenario = SimulatorModelPreviewScenario.selected

    var previewDownloadedModels: [LocalModel] {
        modelPreviewScenario.modelIDs.compactMap { id in
            LocalModel.catalog.first { $0.id == id }
        }
    }

    var previewFoundationModelAvailable: Bool {
        modelPreviewScenario == .actual ? foundationModelAvailable : true
    }
    #endif

    var activeModel: LocalModel {
        LocalModel.catalog.first { $0.id == activeModelID } ?? .qwen
    }

    var foundationModelAvailable: Bool {
        SystemLanguageModel.default.isAvailable
    }

    var usesFoundationModel: Bool {
        prefersFoundationModel && foundationModelAvailable
    }

    var defaultModelName: String {
        if usesFoundationModel { return "Apple Foundation Models" }
        #if targetEnvironment(simulator)
        return foundationModelAvailable ? "Apple Foundation Models" : "Unavailable in Simulator"
        #else
        return downloadedModelIDs.isEmpty ? "No MLX model downloaded" : activeModel.name
        #endif
    }

    var hasUsableDefaultModel: Bool {
        #if targetEnvironment(simulator)
        return foundationModelAvailable
        #else
        return !downloadedModelIDs.isEmpty || usesFoundationModel
        #endif
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
            if activeModelID.isEmpty { activeModelID = model.id }
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

    @discardableResult
    func remove(_ model: LocalModel) -> Bool {
        guard downloadedModelIDs.contains(model.id), downloadingModelID != model.id else { return false }
        do {
            try removeCachedFiles(for: model)
        } catch {
            deletionError = error.localizedDescription
            AppLogger.app.error("Model deletion failed: \(model.name, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return false
        }
        downloadedModelIDs.removeAll { $0 == model.id }
        if activeModelID == model.id {
            activeModelID = downloadedModelIDs.first ?? ""
        }
        persistModelState()
        AppLogger.app.info("Removed model: \(model.name, privacy: .public)")
        updateWidget()
        return true
    }

    func dismissDeletionError() {
        deletionError = nil
    }

    private func persistModelState() {
        UserDefaults.standard.set(downloadedModelIDs, forKey: downloadedModelsKey)
        UserDefaults.standard.set(activeModelID, forKey: activeModelKey)
    }

    private func removeCachedFiles(for model: LocalModel) throws {
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
            try FileManager.default.removeItem(at: path)
        }
    }

    private func updateWidget() {
        SharedWidgetData.save(activeModelName: defaultModelName)

        AppLogger.app.debug("Updated widget model to \(SharedWidgetData.activeModelName, privacy: .public)")

        WidgetCenter.shared.reloadTimelines(
            ofKind: "MLX_SwiftUIWidget"
        )
    }
}
