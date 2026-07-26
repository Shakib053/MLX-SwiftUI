import SwiftUI

struct FeedbackView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                Label("Support email", systemImage: "checkmark.circle.fill")
                    .font(.headline)
                    .foregroundStyle(.green)
                Text("support@localmind.app")
                    .textSelection(.enabled)

                Label("Suggested template", systemImage: "checkmark.circle.fill")
                    .font(.headline)
                    .foregroundStyle(.green)
                Text("Include your device, iOS version, app version, active model, and steps to reproduce the issue.")
                    .foregroundStyle(.secondary)

                Button("Compose Feedback Email") {
                    print("Feedback compose tapped. Configure the production support address and MessageUI composer.")
                }
                .buttonStyle(.borderedProminent)

                Spacer()
            }
            .padding(20)
            .navigationTitle("Send Feedback")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
