import SwiftUI

struct ChatVisualStyle {
    let colorScheme: ColorScheme

    var background: some View {
        LinearGradient(
            colors: backgroundColors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    var panelFill: Color {
        colorScheme == .dark ? .white.opacity(0.08) : .white.opacity(0.68)
    }

    var elevatedFill: Color {
        colorScheme == .dark ? .white.opacity(0.14) : .white.opacity(0.82)
    }

    var surfaceBorder: Color {
        colorScheme == .dark ? .white.opacity(0.10) : .indigo.opacity(0.12)
    }

    var assistantBubbleFill: Color {
        colorScheme == .dark ? .white.opacity(0.10) : .white.opacity(0.74)
    }

    var userBubbleFill: Color {
        colorScheme == .dark ? .indigo.opacity(0.38) : .indigo.opacity(0.14)
    }

    private var backgroundColors: [Color] {
        if colorScheme == .dark {
            return [
                Color(red: 0.06, green: 0.07, blue: 0.11),
                Color(red: 0.10, green: 0.12, blue: 0.18),
                Color(red: 0.18, green: 0.10, blue: 0.16)
            ]
        }

        return [
            Color(red: 0.96, green: 0.97, blue: 1.00),
            Color(red: 0.92, green: 0.94, blue: 1.00),
            Color(red: 1.00, green: 0.94, blue: 0.97)
        ]
    }
}
