import SwiftUI
import OSLog

struct FeedbackView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label("Support email", systemImage: "envelope")
                .font(.headline)
                .foregroundStyle(AppPalette.accent)
            Text("support@localmind.app")
                .textSelection(.enabled)

            Label("Suggested template", systemImage: "doc.text")
                .font(.headline)
                .foregroundStyle(AppPalette.accent)
            Text("Include your device, iOS version, app version, active model, and steps to reproduce the issue.")
                .foregroundStyle(.secondary)

            Button("Compose Feedback Email") {
                AppLogger.app.info("Feedback compose tapped. Configure the production support address and MessageUI composer.")
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
