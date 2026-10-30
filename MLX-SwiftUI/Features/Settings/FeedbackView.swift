import SwiftUI
import UIKit

struct FeedbackView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.openURL) private var openURL
    @State private var feedbackType: FeedbackType = .problem
    @State private var message = ""
    @State private var includeDeviceDetails = true
    @State private var showMailUnavailable = false

    private let supportEmail = "nusratjahan.iosdev@gmail.com"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 10) {
                    Image(systemName: "bubble.left.and.text.bubble.right.fill")
                        .font(.title2)
                        .foregroundStyle(AppPalette.accent)
                        .frame(width: 52, height: 52)
                        .appCard(cornerRadius: 16)

                    Text("Help us improve MLX Chat")
                        .font(.title2.bold())
                    Text("Tell us what happened or share an idea. Your email app will open so you can review and send your message.")
                        .foregroundStyle(.secondary)
                    Text(supportEmail)
                        .font(.subheadline)
                        .textSelection(.enabled)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Feedback type")
                        .font(.headline)
                    Picker("Feedback type", selection: $feedbackType) {
                        ForEach(FeedbackType.allCases) { type in
                            Text(type.shortTitle).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text(feedbackType == .problem ? "What happened?" : "What would you like to see?")
                        .font(.headline)
                    ZStack(alignment: .topLeading) {
                        if message.isEmpty {
                            Text(feedbackType == .problem
                                 ? "Describe the issue and the steps to reproduce it..."
                                 : "Describe your idea and how it would help...")
                                .foregroundStyle(.tertiary)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 8)
                                .allowsHitTesting(false)
                        }
                        TextEditor(text: $message)
                            .frame(minHeight: 150)
                            .scrollContentBackground(.hidden)
                            .accessibilityLabel(feedbackType == .problem ? "Describe the problem" : "Describe your suggestion")
                    }
                    .padding(12)
                    .appCard(cornerRadius: 16)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Toggle(isOn: $includeDeviceDetails) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Include device details")
                                .font(.headline)
                            Text("Helps us understand issues with a specific device or model.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .tint(AppPalette.accentFill)

                    if includeDeviceDetails {
                        Text(deviceDetails)
                            .font(.footnote.monospaced())
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                            .background(AppPalette.background, in: RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(16)
                .appCard(cornerRadius: 16)
            }
            .padding(20)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 8) {
                Button {
                    openURL(emailURL) { accepted in
                        if !accepted { showMailUnavailable = true }
                    }
                } label: {
                    Label("Email Support", systemImage: "envelope")
                        .frame(maxWidth: .infinity)
                }
                .appPrimaryButton()
                .disabled(message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Text("Addressed to \(supportEmail). Nothing is sent automatically.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
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
            Text("No email app is available. Copy \(supportEmail) and email us from another device.")
        }
    }

    private var deviceDetails: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "–"
        return "Device: \(UIDevice.current.model)\niOS: \(UIDevice.current.systemVersion)\nApp: \(version)\nModel: \(appState.defaultModelName)"
    }

    private var feedbackText: String {
        let content = message.trimmingCharacters(in: .whitespacesAndNewlines)
        let details = includeDeviceDetails ? "\n\n\(deviceDetails)" : ""
        return "MLX Chat — \(feedbackType.title)\n\n\(content)\(details)"
    }

    private var emailURL: URL {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = supportEmail
        components.queryItems = [
            URLQueryItem(name: "subject", value: "MLX Chat — \(feedbackType.title)"),
            URLQueryItem(name: "body", value: feedbackText)
        ]
        return components.url!
    }
}

private enum FeedbackType: String, CaseIterable, Identifiable {
    case problem
    case suggestion

    var id: Self { self }

    var shortTitle: String {
        switch self {
        case .problem: String(localized: "Problem")
        case .suggestion: String(localized: "Suggestion")
        }
    }

    var title: String {
        switch self {
        case .problem: String(localized: "Report a problem")
        case .suggestion: String(localized: "Suggest an improvement")
        }
    }
}
