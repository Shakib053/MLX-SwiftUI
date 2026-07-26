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

struct ModelStat: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon).foregroundStyle(.indigo)
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.caption2).foregroundStyle(.secondary)
                Text(value).font(.caption.weight(.semibold)).lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
