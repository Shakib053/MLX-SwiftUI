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

    var repositoryURL: URL {
        URL(string: "https://huggingface.co/\(repositoryID)")!
    }

    var licenseURL: URL {
        switch id {
        case "qwen", "smollm-135m", "qwen25-05b", "qwen25-15b", "qwen3-17b": URL(string: "https://www.apache.org/licenses/LICENSE-2.0")!
        case "gemma": URL(string: "https://ai.google.dev/gemma/terms")!
        default: URL(string: "https://www.llama.com/llama3_2/license/")!
        }
    }

    static let qwen = LocalModel(
        id: "qwen",
        name: "Qwen 3 0.6B",
        shortName: "Qwen 3",
        initials: "Q3",
        sizeGB: 0.48,
        sizeLabel: "0.48 GB",
        quantization: "4-bit",
        focus: String(localized: "Fast"),
        provider: "Qwen / MLX Community",
        summary: String(localized: "A compact general-purpose model suited to quick questions, summaries, and lightweight coding help."),
        license: String(localized: "Apache 2.0. The MLX Community conversion is based on Qwen3."),
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
        focus: String(
            localized: "model.focus.light",
            defaultValue: "Light",
            comment: "A lightweight AI model, not the light appearance theme."
        ),
        provider: "Google / MLX Community",
        summary: String(localized: "A compact QAT-quantized assistant from Google for writing help, summaries, and general conversation."),
        license: String(localized: "Gemma Terms of Use. The MLX Community conversion is based on Google Gemma 3."),
        colors: [.blue, .cyan],
        configuration: LLMRegistry.gemma3_1B_qat_4bit,
        contextWindowTokens: 32768
    )

    static let llama = LocalModel(
        id: "llama",
        name: "Llama 3.2 1B",
        shortName: "Llama 3.2",
        initials: "L3",
        sizeGB: 0.70,
        sizeLabel: "695 MB",
        quantization: "4-bit",
        focus: String(localized: "Quality"),
        provider: "Meta / MLX Community",
        summary: String(localized: "A stronger multilingual assistant for writing, summaries, retrieval, and general conversation."),
        license: String(localized: "Llama 3.2 Community License. Include the required Llama attribution and usage notice."),
        colors: [.orange, .pink],
        configuration: LLMRegistry.llama3_2_1B_4bit,
        contextWindowTokens: 131072
    )

    static let smolLM = LocalModel(
        id: "smollm-135m",
        name: "SmolLM 135M Instruct",
        shortName: "SmolLM 135M",
        initials: "SM",
        sizeGB: 0.0792,
        sizeLabel: "79.2 MB",
        quantization: "4-bit",
        focus: String(localized: "Lightweight"),
        provider: "Hugging Face / MLX Community",
        summary: String(localized: "A small English model for short prompts and simple chat."),
        license: String(localized: "Apache 2.0. The MLX Community conversion is based on SmolLM."),
        colors: [.mint, .teal],
        configuration: LLMRegistry.smolLM_135M_4bit,
        contextWindowTokens: 2048
    )

    static let qwen25Small = LocalModel(
        id: "qwen25-05b",
        name: "Qwen 2.5 0.5B Instruct",
        shortName: "Qwen 2.5 0.5B",
        initials: "Q2",
        sizeGB: 0.290,
        sizeLabel: "290 MB",
        quantization: "4-bit",
        focus: String(localized: "Fast"),
        provider: "Qwen / MLX Community",
        summary: String(localized: "A compact instruction-tuned model for quick questions and simple writing tasks."),
        license: String(localized: "Apache 2.0. The MLX Community conversion is based on Qwen2.5."),
        colors: [.blue, .indigo],
        configuration: ModelConfiguration(id: "mlx-community/Qwen2.5-0.5B-Instruct-4bit"),
        contextWindowTokens: 32768
    )

    static let qwen25 = LocalModel(
        id: "qwen25-15b",
        name: "Qwen 2.5 1.5B Instruct",
        shortName: "Qwen 2.5 1.5B",
        initials: "Q2",
        sizeGB: 0.881,
        sizeLabel: "881 MB",
        quantization: "4-bit",
        focus: String(localized: "General purpose"),
        provider: "Qwen / MLX Community",
        summary: String(localized: "An instruction-tuned model for conversation, writing, and structured outputs."),
        license: String(localized: "Apache 2.0. The MLX Community conversion is based on Qwen2.5."),
        colors: [.indigo, .cyan],
        configuration: LLMRegistry.qwen2_5_1_5b,
        contextWindowTokens: 32768
    )

    static let qwen3Large = LocalModel(
        id: "qwen3-17b",
        name: "Qwen 3 1.7B",
        shortName: "Qwen 3 1.7B",
        initials: "Q3",
        sizeGB: 0.984,
        sizeLabel: "984 MB",
        quantization: "4-bit",
        focus: String(localized: "Reasoning"),
        provider: "Qwen / MLX Community",
        summary: String(localized: "A multilingual model for chat, coding, and reasoning tasks."),
        license: String(localized: "Apache 2.0. The MLX Community conversion is based on Qwen3."),
        colors: [.purple, .pink],
        configuration: LLMRegistry.qwen3_1_7b_4bit,
        contextWindowTokens: 32768
    )

    static let catalog = [qwen, gemma, llama, smolLM, qwen25Small, qwen25, qwen3Large]
}
