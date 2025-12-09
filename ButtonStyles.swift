import SwiftUI

struct WhitePillButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.black)
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.white)
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(Color.black.opacity(configuration.isPressed ? 0.35 : 0.2), lineWidth: configuration.isPressed ? 2 : 1)
            )
            .shadow(color: .black.opacity(configuration.isPressed ? 0.04 : 0.08), radius: configuration.isPressed ? 1 : 3, x: 0, y: configuration.isPressed ? 0 : 2)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.22, dampingFraction: 0.9), value: configuration.isPressed)
    }
}

struct SubtlePillButtonStyle: ButtonStyle {
    var emphasized: Bool = false
    var sizeScale: CGFloat = 1.0
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13 * sizeScale, weight: .semibold))
            .foregroundStyle(emphasized ? Color.primary : Color.secondary)
            .padding(.vertical, 6 * sizeScale)
            .padding(.horizontal, 10 * sizeScale)
            .background(
                Capsule(style: .continuous)
                    .fill(Color(.secondarySystemBackground))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(Color.black.opacity(0.08), lineWidth: 1)
            )
            .shadow(color: .black.opacity(configuration.isPressed ? 0.02 : 0.04), radius: configuration.isPressed ? 0.5 : 1.5, x: 0, y: configuration.isPressed ? 0 : 1)
            .scaleEffect(configuration.isPressed ? 0.99 : 1.0)
            .animation(.spring(response: 0.22, dampingFraction: 0.9), value: configuration.isPressed)
    }
}
