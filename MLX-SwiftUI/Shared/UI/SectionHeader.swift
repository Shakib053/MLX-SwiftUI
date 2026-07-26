import SwiftUI

struct SectionHeader: View {
    let title: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        HStack {
            Text(title)
                .font(.title3.bold())
            Spacer()
            if let actionTitle, let action {
                Button(actionTitle, action: action)
            }
        }
    }
}
