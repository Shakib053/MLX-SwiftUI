import SwiftUI

struct FeedbackView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label("Suggested template", systemImage: "doc.text")
                .font(.headline)
                .foregroundStyle(AppPalette.accent)
            Text("Include your device, iOS version, app version, active model, and steps to reproduce the issue.")
                .foregroundStyle(.secondary)

            ShareLink(item: String(localized: "Feedback for MLX Chat\n\nDevice:\nVersion:\nModel:\nSteps to reproduce:\n")) {
                Label("Share Feedback", systemImage: "square.and.arrow.up")
            }
            .appPrimaryButton()

            Spacer()
        }
        .padding(20)
        .background(AppBackground())
        .navigationTitle("Send Feedback")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }
}
