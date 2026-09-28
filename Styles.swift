import SwiftUI

enum AppDesignMetrics {
    static let cardCornerRadius: CGFloat = 16
    static let cardPadding: CGFloat = 16
    static let compactControlCornerRadius: CGFloat = 12
}

private struct ImageOverlaySurfaceModifier: ViewModifier {
    let cornerRadius: CGFloat

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    private var scrimOpacity: Double {
        if reduceTransparency { return 0.94 }
        if colorSchemeContrast == .increased { return 0.88 }
        return 0.76
    }

    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(.regularMaterial)
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(Color.black.opacity(scrimOpacity))
                }
            )
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.white.opacity(colorSchemeContrast == .increased ? 0.45 : 0.18))
            }
            .environment(\.colorScheme, .dark)
    }
}

extension View {
    func imageOverlaySurface(cornerRadius: CGFloat = AppDesignMetrics.cardCornerRadius) -> some View {
        modifier(ImageOverlaySurfaceModifier(cornerRadius: cornerRadius))
    }
}

/// A modern pill-shaped button style used across the app for secondary actions.
/// Native tinted Liquid Glass capsule that follows system appearance settings.
public struct ModernPillButtonStyle: ButtonStyle {
    public var tint: Color = .accentColor
    @Environment(\.isEnabled) private var isEnabled

    public init(tint: Color = .accentColor) { self.tint = tint }

    public func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed

        return configuration.label
            .font(.footnote.weight(.semibold))
            .foregroundStyle(isEnabled ? .white : .secondary)
            .padding(.vertical, 9)
            .padding(.horizontal, 14)
            .glassEffect(
                .regular
                    .tint((isEnabled ? tint : .gray).opacity(pressed ? 0.72 : 0.9))
                    .interactive(isEnabled),
                in: .capsule
            )
            .contentShape(Capsule(style: .continuous))
            .scaleEffect(pressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.22, dampingFraction: 0.85), value: configuration.isPressed)
    }
}

/// A prominent filled button style used in games and primary calls to action.
/// Prominent tinted Liquid Glass with a strong affordance.
public struct GameProminentButtonStyle: ButtonStyle {
    public var tint: Color = .accentColor
    @Environment(\.isEnabled) private var isEnabled

    public init(tint: Color = .accentColor) { self.tint = tint }

    public func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed

        return configuration.label
            .font(.headline.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.vertical, 12)
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity)
            .glassEffect(
                .regular
                    .tint((isEnabled ? tint : .gray).opacity(pressed ? 0.8 : 1.0))
                    .interactive(isEnabled),
                in: .rect(cornerRadius: AppDesignMetrics.cardCornerRadius)
            )
            .contentShape(RoundedRectangle(cornerRadius: AppDesignMetrics.cardCornerRadius, style: .continuous))
            .scaleEffect(pressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.8), value: configuration.isPressed)
    }
}

/// A key-like button style used for on-screen keyboards (e.g., Hangman).
/// Tonal background with clear affordance and state colors.
public struct GameKeyButtonStyle: ButtonStyle {
    public var tint: Color
    @Environment(\.isEnabled) private var isEnabled

    public init(tint: Color) { self.tint = tint }

    public func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        configuration.label
            .font(.headline)
            .foregroundStyle(isEnabled ? tint : .secondary)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .glassEffect(
                .regular
                    .tint((isEnabled ? tint : .gray).opacity(pressed ? 0.24 : 0.16))
                    .interactive(isEnabled),
                in: .rect(cornerRadius: AppDesignMetrics.compactControlCornerRadius)
            )
            .contentShape(RoundedRectangle(cornerRadius: AppDesignMetrics.compactControlCornerRadius, style: .continuous))
            .scaleEffect(pressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.22, dampingFraction: 0.85), value: configuration.isPressed)
    }
}

/// A compact, borderless toolbar style (no background fill).
/// Use this when you want the button to appear as just text (or an icon) in toolbars.
public struct ToolbarPillButtonStyle: ButtonStyle {
    public var tint: Color = .accentColor
    @Environment(\.isEnabled) private var isEnabled

    public init(tint: Color = .accentColor) { self.tint = tint }

    public func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(isEnabled ? tint : .secondary)
            .padding(.vertical, 6)
            .padding(.horizontal, 6)
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .opacity(pressed ? 0.7 : 1.0)
            .scaleEffect(pressed ? 0.98 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
