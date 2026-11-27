import SwiftUI

struct ModelMark: View {
    let model: LocalModel
    var size: CGFloat = 48

    var body: some View {
        Text(model.initials)
            .font(.headline.bold())
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(
                LinearGradient(colors: model.colors, startPoint: .topLeading, endPoint: .bottomTrailing),
                in: RoundedRectangle(cornerRadius: size * 0.29, style: .continuous)
            )
    }
}

struct ModelMemoryBadge: View {
    @Environment(\.colorScheme) private var colorScheme

    let model: LocalModel

    var body: some View {
        let isDark = colorScheme == .dark
        let foreground = isDark ? Color(red: 1, green: 0.75, blue: 0.43) : Color(red: 0.48, green: 0.22, blue: 0.04)
        let background = isDark ? Color(red: 0.25, green: 0.14, blue: 0.06) : Color(red: 1, green: 0.92, blue: 0.82)

        if model.hasHigherRAMUse {
            Text("Higher RAM use")
                .font(.caption.weight(.semibold))
                .foregroundStyle(foreground)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(background, in: Capsule())
        }
    }
}

struct ModelMemoryNote: View {
    var body: some View {
        Text("This model can use more memory, especially in longer chats, and may run slowly on older iPhones.")
            .font(.subheadline)
            .foregroundStyle(.secondary)
    }
}

struct ModelDownloadButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "arrow.down")
                    .accessibilityHidden(true)
                Text("Download")
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 32)
        }
        .appPrimaryButton()
    }
}

struct ModelStat: View {
    let icon: String
    let label: LocalizedStringKey
    let value: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon).foregroundStyle(AppPalette.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.caption2).foregroundStyle(.secondary)
                Text(value).font(.caption.weight(.semibold)).lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
