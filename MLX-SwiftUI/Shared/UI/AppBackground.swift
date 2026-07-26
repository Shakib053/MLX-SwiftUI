import SwiftUI

struct AppBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        LinearGradient(
            colors: colorScheme == .dark
                ? [.black, Color.indigo.opacity(0.20), Color.purple.opacity(0.14)]
                : [Color(.systemGroupedBackground), Color.indigo.opacity(0.08), Color.pink.opacity(0.06)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}
