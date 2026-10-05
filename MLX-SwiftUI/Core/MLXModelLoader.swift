import Foundation
import HuggingFace
import MLXHuggingFace
import MLXLMCommon
import MLXLLM
import Tokenizers

enum MLXModelLoader {
    static func cachedDirectory(for model: LocalModel) -> URL? {
        guard case .id(let id, let revision) = model.configuration.id else { return nil }
        let components = id.split(separator: "/", maxSplits: 1).map(String.init)
        guard components.count == 2 else { return nil }

        let repo = Repo.ID(namespace: components[0], name: components[1])
        let cache = HubCache.default
        guard let config = cache.cachedFilePath(
            repo: repo, kind: .model, revision: revision, filename: "config.json"
        ), hasNonemptyFile(config) else { return nil }

        let directory = config.deletingLastPathComponent()
        let files = FileManager.default
        guard hasNonemptyFile(directory.appendingPathComponent("tokenizer.json")),
              hasNonemptyFile(directory.appendingPathComponent("tokenizer_config.json")) else {
            return nil
        }

        let index = directory.appendingPathComponent("model.safetensors.index.json")
        if files.fileExists(atPath: index.path) {
            guard let data = try? Data(contentsOf: index),
                  let manifest = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let weights = manifest["weight_map"] as? [String: String],
                  !weights.isEmpty else { return nil }
            let shards = Set(weights.values)
            guard shards.allSatisfy({
                !$0.contains("/") && !$0.contains("..") &&
                hasNonemptyFile(directory.appendingPathComponent($0))
            }) else {
                return nil
            }
        } else {
            guard hasNonemptyFile(directory.appendingPathComponent("model.safetensors")) else {
                return nil
            }
        }

        return directory
    }

    static func loadCached(_ model: LocalModel) async throws -> ModelContainer {
        guard let directory = cachedDirectory(for: model) else {
            throw CachedModelError.notInstalled
        }
        return try await LLMModelFactory.shared.loadContainer(
            from: directory,
            using: #huggingFaceTokenizerLoader()
        )
    }

    static func download(
        _ model: LocalModel,
        progressHandler: @MainActor @Sendable @escaping (Progress) -> Void
    ) async throws {
        guard case .id(let id, let revision) = model.configuration.id,
              let repo = Repo.ID(rawValue: id) else { throw CachedModelError.notInstalled }
        _ = try await HubClient().downloadSnapshot(
            of: repo,
            revision: revision,
            matching: ["*.safetensors", "*.json", "*.jinja"],
            progressHandler: progressHandler
        )
    }

    private static func hasNonemptyFile(_ url: URL) -> Bool {
        let resolved = url.resolvingSymlinksInPath()
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: resolved.path),
              let size = attributes[.size] as? NSNumber else { return false }
        return size.intValue > 0
    }
}

enum CachedModelError: LocalizedError {
    case notInstalled

    var errorDescription: String? {
        "This model is not downloaded. Download it before using it offline."
    }
}
