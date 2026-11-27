import SwiftUI
import UIKit

enum AppPalette {
    static let background = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(red: 0.055, green: 0.075, blue: 0.085, alpha: 1) : UIColor(red: 0.95, green: 0.97, blue: 0.96, alpha: 1)
    })
    static let card = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(red: 0.10, green: 0.13, blue: 0.14, alpha: 1) : .white
    })
    static let border = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(red: 0.19, green: 0.25, blue: 0.25, alpha: 1) : UIColor(red: 0.85, green: 0.90, blue: 0.88, alpha: 1)
    })
    static let hero = LinearGradient(
        colors: [Color(red: 0.04, green: 0.14, blue: 0.16), Color(red: 0.04, green: 0.31, blue: 0.25)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    static let accentFill = Color(red: 0.035, green: 0.34, blue: 0.28)
    static let accent = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(red: 0.47, green: 0.86, blue: 0.73, alpha: 1) : UIColor(red: 0.035, green: 0.34, blue: 0.28, alpha: 1)
    })
}
