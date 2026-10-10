import SwiftUI

struct SettingsRow: View {
    let icon: String
    let color: Color
    let title: String
    let subtitle: String
    let value: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(color, in: RoundedRectangle(cornerRadius: 7))
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
                Text(value)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
    }
}

#if DEBUG && targetEnvironment(simulator)
enum SimulatorModelPreviewScenario: String, CaseIterable, Identifiable {
    case foundationOnly
    case foundationAndGemma
    case foundationQwenAndGemma
    case actual

    static let defaultsKey = "simulatorModelPreviewScenario"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .foundationOnly: "Foundation Models only"
        case .foundationAndGemma: "Foundation Models + Gemma"
        case .foundationQwenAndGemma: "Foundation Models + Qwen + Gemma"
        case .actual: "Actual Simulator"
        }
    }

    var modelIDs: [String] {
        switch self {
        case .foundationOnly, .actual: []
        case .foundationAndGemma: [LocalModel.gemma.id]
        case .foundationQwenAndGemma: [LocalModel.qwen.id, LocalModel.gemma.id]
        }
    }

    static var selected: Self {
        get {
            Self(rawValue: UserDefaults.standard.string(forKey: defaultsKey) ?? "") ?? .actual
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: defaultsKey)
        }
    }
}

struct SimulatorTestingSection: View {
    @Environment(AppState.self) private var appState
    @State private var scenario = SimulatorDownloadScenario.selected

    var body: some View {
        Section {
            Picker("Conversation scenario", selection: $scenario) {
                ForEach(SimulatorDownloadScenario.allCases) { scenario in
                    Text(scenario.title).tag(scenario)
                }
            }
            Picker("Model screens", selection: Binding(
                get: { appState.modelPreviewScenario },
                set: {
                    appState.modelPreviewScenario = $0
                    SimulatorModelPreviewScenario.selected = $0
                }
            )) {
                ForEach(SimulatorModelPreviewScenario.allCases) { preview in
                    Text(preview.title).tag(preview)
                }
            }
        } header: {
            Text("Simulator Testing")
        } footer: {
            Text(
                "The scenario applies to the next new conversation. " +
                "Apple Foundation Models are used when available; local MLX loading is simulated. " +
                "Model screens preview changes display only and never download MLX models."
            )
        }
        .onChange(of: scenario) { _, value in
            SimulatorDownloadScenario.selected = value
        }
    }
}
#endif
