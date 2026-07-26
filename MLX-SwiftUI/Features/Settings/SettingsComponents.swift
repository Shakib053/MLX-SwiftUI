import SwiftUI

struct SettingsRow: View {
    let icon: String
    let color: Color
    let title: String
    let subtitle: String
    let value: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(color, in: RoundedRectangle(cornerRadius: 7))
            VStack(alignment: .leading) {
                Text(title)
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text(value).font(.caption).foregroundStyle(.secondary)
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
        }
    }
}

#if DEBUG && targetEnvironment(simulator)
struct SimulatorTestingSection: View {
    @State private var scenario = SimulatorDownloadScenario.selected

    var body: some View {
        Section {
            Picker("Conversation scenario", selection: $scenario) {
                ForEach(SimulatorDownloadScenario.allCases) { scenario in
                    Text(scenario.title).tag(scenario)
                }
            }
        } header: {
            Text("Simulator Testing")
        } footer: {
            Text(
                "The scenario applies to the next new conversation. " +
                "Hosted chat uses Hugging Face and never loads MLX."
            )
        }
        .onChange(of: scenario) { _, value in
            SimulatorDownloadScenario.selected = value
        }
    }
}
#endif
