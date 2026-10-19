import SwiftUI
import UIKit

enum AppPalette {
    static let background = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(red: 0.055, green: 0.055, blue: 0.075, alpha: 1) : .systemBackground
    })
    static let card = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(red: 0.105, green: 0.105, blue: 0.135, alpha: 1) : .secondarySystemBackground
    })
    static let border = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(red: 0.17, green: 0.17, blue: 0.21, alpha: 1) : UIColor.systemIndigo.withAlphaComponent(0.12)
    })
    static let accentFill = Color(red: 0.29, green: 0.24, blue: 0.88)
    static let accent = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(red: 0.66, green: 0.63, blue: 1, alpha: 1) : .systemIndigo
    })
}
