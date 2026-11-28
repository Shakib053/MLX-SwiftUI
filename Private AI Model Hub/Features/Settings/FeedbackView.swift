import SwiftUI

struct FeedbackView: View {
    @Environment(\.openURL) private var openURL
    @State private var message = ""
    @State private var showMailUnavailable = false

    private let supportEmail = "nusratjahan.iosdev@gmail.com"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Send feedback")
                        .font(.title.bold())
                    Text("Your email app will open so you can review and send your message.")
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Your feedback")
                        .font(.headline)
                    ZStack(alignment: .topLeading) {
                        if message.isEmpty {
                            Text("Please share your feedback or suggestions.")
                                .foregroundStyle(.tertiary)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 8)
                                .allowsHitTesting(false)
                                .accessibilityHidden(true)
                        }
                        TextEditor(text: $message)
                            .frame(minHeight: 150)
                            .scrollContentBackground(.hidden)
                            .accessibilityLabel("Your feedback")
                            .accessibilityHint("Please share your feedback or suggestions.")
                    }
                    .padding(12)
                    .appCard(cornerRadius: 16)
                }
            }
            .padding(20)
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                openURL(emailURL) { accepted in
                    if !accepted { showMailUnavailable = true }
                }
            } label: {
                Label("Open Email Draft", systemImage: "envelope")
                    .frame(maxWidth: .infinity)
            }
            .appPrimaryButton()
            .disabled(message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(.regularMaterial)
        }
        .background(AppBackground())
        .navigationTitle("Contact Us")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .alert("Email Unavailable", isPresented: $showMailUnavailable) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("No email app could open the draft. Set up an email app on this device and try again.")
        }
    }

    private var emailURL: URL {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = supportEmail
        components.queryItems = [
            URLQueryItem(name: "subject", value: "Private AI Model Hub Feedback"),
            URLQueryItem(name: "body", value: message.trimmingCharacters(in: .whitespacesAndNewlines))
        ]
        return components.url!
    }
}
