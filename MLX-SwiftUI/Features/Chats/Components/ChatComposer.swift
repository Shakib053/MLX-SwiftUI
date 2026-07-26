import SwiftUI

struct ChatComposer: View {
    @Binding var text: String
    let activeModel: LocalModel
    let backendMode: ChatBackendMode?
    let isSending: Bool
    let isFocused: FocusState<Bool>.Binding
    let style: ChatVisualStyle
    let showModelPicker: () -> Void
    let send: () -> Void

    private var trimmedText: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var textBinding: Binding<String> {
        Binding(
            get: { text },
            set: { newValue in
                guard !isSending else { return }
                text = newValue
            }
        )
    }

    var body: some View {
        VStack(spacing: 9) {
            HStack {
                Button(action: showModelPicker) {
                    Label(activeModel.name, systemImage: "cpu")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)

                Spacer()

                Label(
                    backendMode == .hosted ? "Online via Hugging Face" : "Private by default",
                    systemImage: backendMode == .hosted ? "cloud.fill" : "lock.fill"
                )
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
            }

            HStack(alignment: .bottom, spacing: 9) {
                Button {
                    print(
                        "Attach file tapped. ChatRequest currently accepts text only; " +
                        "connect a system fileImporter when multimodal context is supported."
                    )
                } label: {
                    Image(systemName: "paperclip")
                        .font(.system(size: 18, weight: .semibold))
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Attach file")

                TextField("Message MLX Chat", text: textBinding, axis: .vertical)
                    .focused(isFocused)
                    .lineLimit(1...5)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .background(style.panelFill, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .foregroundStyle(.primary)
                    .overlay {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(style.surfaceBorder, lineWidth: 1)
                    }
                    .disabled(isSending)

                Button(action: send) {
                    Image(systemName: isSending ? "hourglass" : "arrow.up")
                        .font(.system(size: 18, weight: .bold))
                        .frame(width: 44, height: 44)
                        .background(.indigo)
                        .foregroundStyle(.white)
                        .clipShape(Circle())
                }
                .disabled(trimmedText.isEmpty || isSending)
                .opacity(trimmedText.isEmpty || isSending ? 0.45 : 1)
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(.ultraThinMaterial)
    }
}
