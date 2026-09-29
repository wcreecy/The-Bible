import SwiftUI

struct SubtlePillButtonStyle: ButtonStyle {
    var emphasized: Bool = false
    var sizeScale: CGFloat = 1.0
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13 * sizeScale, weight: .semibold))
            .foregroundStyle(emphasized ? Color.white : Color.accentColor)
            .padding(.horizontal, 12 * sizeScale)
            .frame(minHeight: 36 * sizeScale)
            .glassEffect(
                .regular
                    .tint(Color.accentColor.opacity(emphasized ? 0.9 : 0.18))
                    .interactive(isEnabled),
                in: .capsule
            )
            .contentShape(Capsule(style: .continuous))
            .opacity(isEnabled ? 1 : 0.72)
            .scaleEffect(configuration.isPressed && isEnabled ? 0.97 : 1)
            .animation(.spring(response: 0.22, dampingFraction: 0.9), value: configuration.isPressed)
    }
}
