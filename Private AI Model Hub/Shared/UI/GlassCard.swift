import SwiftUI

extension View {
    func appPrimaryButton() -> some View {
        buttonStyle(.borderedProminent)
            .buttonBorderShape(.roundedRectangle(radius: 16))
            .tint(AppPalette.accentFill)
    }

    func appCard(cornerRadius: CGFloat = 20) -> some View {
        background(AppPalette.card, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(AppPalette.border)
                    .allowsHitTesting(false)
            }
    }
}
