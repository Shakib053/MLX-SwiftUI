import SwiftUI

struct AboutView: View {
    var body: some View {
        List {
            Section {
                VStack(spacing: 12) {
                    Image(systemName: "sparkles.rectangle.stack")
                        .font(.system(size: 40))
                        .foregroundStyle(AppPalette.accent)
                        .frame(width: 80, height: 80)
                        .background(AppPalette.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 20))

                    Text("MLX-SwiftUI")
                        .font(.title2.bold())

                    Text("An AI workspace for your iPhone and iPad.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .listRowBackground(Color.clear)
            }

            Section("About the app") {
                Text("Chat with AI, work with text and documents, and save useful results. On supported devices, Apple Foundation Models or downloaded MLX models keep your work on your device.")
                    .foregroundStyle(.secondary)
            }

            Section("Details") {
                LabeledContent("Version", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0")
            }

            Section("Support & legal") {
                NavigationLink {
                    FeedbackView()
                } label: {
                    Label("Send Feedback", systemImage: "bubble.left")
                }

                Link(destination: URL(string: "https://mlx-swiftui-privacy-policy.vercel.app/")!) {
                    Label("Privacy Policy", systemImage: "hand.raised")
                }

                NavigationLink {
                    LicensesView()
                } label: {
                    Label("Model Licenses", systemImage: "doc.text")
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(AppBackground())
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }
}
