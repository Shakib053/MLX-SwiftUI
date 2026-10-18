import SwiftUI

struct ChatVisualStyle {
    let colorScheme: ColorScheme

    var background: some View { AppBackground() }
    var panelFill: Color { AppPalette.card }
    var elevatedFill: Color { AppPalette.card }
    var surfaceBorder: Color { AppPalette.border }
    var assistantBubbleFill: Color { AppPalette.card }
    var userBubbleFill: Color {
        AppPalette.accent.opacity(colorScheme == .dark ? 0.20 : 0.12)
    }
}
