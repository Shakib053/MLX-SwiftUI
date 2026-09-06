import SwiftUI
import MLXLLM
import MLXLMCommon

struct LocalModel: Identifiable, Equatable {
    let id: String
    let name: String
    let shortName: String
    let initials: String
    let sizeGB: Double
    let sizeLabel: String
    let quantization: String
    let focus: String
    let provider: String
    let summary: String
    let license: String
    let colors: [Color]
    let configuration: ModelConfiguration

    let contextWindowTokens: Int

    var repositoryID: String {
        if case .id(let id, _) = configuration.id {
            return id
        }
        return configuration.name
    }

    static let qwen = LocalModel(
        id: "qwen",
        name: "Qwen 3 0.6B",
        shortName: "Qwen 3",
        initials: "Q3",
        sizeGB: 0.48,
        sizeLabel: "0.48 GB",
        quantization: "4-bit",
        focus: "Fast",
        provider: "Qwen / MLX Community",
        summary: "A compact general-purpose model suited to quick questions, summaries, and lightweight coding help.",
        license: "Apache 2.0. The MLX Community conversion is based on Qwen3.",
        colors: [.indigo, .purple],
        configuration: LLMRegistry.qwen3_0_6b_4bit,
        contextWindowTokens: 32768
    )

    static let gemma = LocalModel(
        id: "gemma",
        name: "Gemma 3 1B",
        shortName: "Gemma 3",
        initials: "G3",
        sizeGB: 0.68,
        sizeLabel: "698 MB",
        quantization: "4-bit",
        focus: "Light",
        provider: "Google / MLX Community",
        summary: "A compact QAT-quantized assistant from Google for writing help, summaries, and general conversation.",
        license: "Gemma Terms of Use. The MLX Community conversion is based on Google Gemma 3.",
        colors: [.blue, .cyan],
        configuration: LLMRegistry.gemma3_1B_qat_4bit,
        contextWindowTokens: 8192
    )

    static let llama = LocalModel(
        id: "llama",
        name: "Llama 3.2 1B",
        shortName: "Llama 3.2",
        initials: "L3",
        sizeGB: 0.70,
        sizeLabel: "695 MB",
        quantization: "4-bit",
        focus: "Quality",
        provider: "Meta / MLX Community",
        summary: "A stronger multilingual assistant for writing, summaries, retrieval, and general conversation.",
        license: "Llama 3.2 Community License. Include the required Llama attribution and usage notice.",
        colors: [.orange, .pink],
        configuration: LLMRegistry.llama3_2_1B_4bit,
        contextWindowTokens: 131072
    )

    static let catalog = [qwen, gemma, llama]
}
