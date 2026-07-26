import Foundation
import Observation
import SwiftUI

enum AppAppearance: String, CaseIterable, Identifiable {
    case light
    case dark
    case system

    var id: String { rawValue }

    var title: String {
        rawValue.capitalized
    }

    var icon: String {
        switch self {
        case .light: "sun.max"
        case .dark: "moon"
        case .system: "circle.lefthalf.filled"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .light: .light
        case .dark: .dark
        case .system: nil
        }
    }
}

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
        license: "Apache 2.0. Production builds should include the exact model repository, revision, conversion source, and full notices.",
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

@MainActor
@Observable
final class AppState {
    static let modelLimit = 2

    var selectedTab = 0
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
        print("Prototype model download completed: \(model.name). Wire this catalog entry to the MLX downloader for production.")
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
