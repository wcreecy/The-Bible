import SwiftUI

struct GameStartScreenStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .frame(maxWidth: 620)
            .frame(maxWidth: .infinity)
            .padding(.horizontal)
            .padding(.vertical, 24)
    }
}

struct GameStartDescriptionStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.title3)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: 520)
    }
}

struct GameStartOptionsStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
            }
    }
}

extension View {
    func gameStartScreenStyle() -> some View {
        modifier(GameStartScreenStyle())
    }

    func gameStartDescriptionStyle() -> some View {
        modifier(GameStartDescriptionStyle())
    }

    func gameStartOptionsStyle() -> some View {
        modifier(GameStartOptionsStyle())
    }
}
