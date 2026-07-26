import SwiftUI

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
        license: "Apache 2.0. Production builds should include the exact model repository, " +
            "revision, conversion source, and full notices.",
        colors: [.indigo, .purple]
    )

    static let smol = LocalModel(
        id: "smol",
        name: "SmolLM2 1.7B",
        shortName: "SmolLM2",
        initials: "SL",
        sizeGB: 1.10,
        sizeLabel: "1.10 GB",
        quantization: "4-bit",
        focus: "Balanced writing",
        provider: "Hugging Face / MLX Community",
        summary: "A small writing-oriented assistant with more capacity for drafting and rewriting.",
        license: "Apache 2.0. Verify and ship the complete notices from the exact downloaded model revision.",
        colors: [.green, .teal]
    )

    static let coder = LocalModel(
        id: "coder",
        name: "Tiny Coder 1.1B",
        shortName: "Tiny Coder",
        initials: "TC",
        sizeGB: 0.76,
        sizeLabel: "0.76 GB",
        quantization: "4-bit",
        focus: "Code",
        provider: "Prototype catalog",
        summary: "A catalog preview for a compact code-focused model.",
        license: "Placeholder catalog metadata. Confirm the source model and license before enabling a real download.",
        colors: [.orange, .pink]
    )

    static let catalog = [qwen, smol, coder]
}
