import Foundation
import HuggingFace
import MLXHuggingFace
import MLXLMCommon
import Tokenizers

enum MLXModelLoader {
    static func load(
        configuration: ModelConfiguration,
        progressHandler: @Sendable @escaping (Progress) -> Void
    ) async throws -> ModelContainer {
        let container = try await #huggingFaceLoadModelContainer(
            configuration: configuration,
            progressHandler: progressHandler
        )
        return container
    }
}
