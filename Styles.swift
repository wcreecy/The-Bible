import SwiftUI

enum AppDesignMetrics {
    static let cardCornerRadius: CGFloat = 16
    static let cardPadding: CGFloat = 16
    static let compactControlCornerRadius: CGFloat = 12
    static let selectionRowMinHeight: CGFloat = 40
}

private struct HeroCardSurfaceModifier: ViewModifier {
    let cornerRadius: CGFloat

    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    func body(content: Content) -> some View {
        content
            .glassEffect(
                .regular,
                in: .rect(cornerRadius: cornerRadius)
            )
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        .primary.opacity(colorSchemeContrast == .increased ? 0.32 : 0.14),
                        lineWidth: 1
                    )
            }
            .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 5)
    }
}

struct HeroCardListRowBackground: View {
    var body: some View {
        Color.clear
            .heroCardSurface()
    }
}

private struct ImageOverlaySurfaceModifier: ViewModifier {
    let cornerRadius: CGFloat

    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    func body(content: Content) -> some View {
        content
            .glassEffect(
                .regular,
                in: .rect(cornerRadius: cornerRadius)
            )
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(.primary.opacity(colorSchemeContrast == .increased ? 0.32 : 0.14))
            }
    }
}

extension View {
    func heroCardSurface(cornerRadius: CGFloat = AppDesignMetrics.cardCornerRadius) -> some View {
        modifier(HeroCardSurfaceModifier(cornerRadius: cornerRadius))
    }

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
            .foregroundStyle(isEnabled ? .white : tint.opacity(0.78))
            .padding(.horizontal, 16)
            .frame(minHeight: 44)
            .glassEffect(
                .regular
                    .tint(tint.opacity(pressed ? 0.72 : (isEnabled ? 0.9 : 0.24)))
                    .interactive(isEnabled),
                in: .capsule
            )
            .contentShape(Capsule(style: .continuous))
            .opacity(isEnabled ? 1 : 0.82)
            .scaleEffect(pressed && isEnabled ? 0.98 : 1.0)
            .animation(.spring(response: 0.22, dampingFraction: 0.85), value: configuration.isPressed)
    }
}

/// A compact circular Liquid Glass style for icon-only and short numeric actions.
public struct ModernCircleButtonStyle: ButtonStyle {
    public var tint: Color = .accentColor
    public var isProminent: Bool = false
    @Environment(\.isEnabled) private var isEnabled

    public init(tint: Color = .accentColor, isProminent: Bool = false) {
        self.tint = tint
        self.isProminent = isProminent
    }

    public func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed

        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(isProminent ? Color.white : tint)
            .frame(width: 44, height: 44)
            .glassEffect(
                .regular
                    .tint(tint.opacity(isProminent ? 0.9 : 0.2))
                    .interactive(isEnabled),
                in: .circle
            )
            .contentShape(Circle())
            .opacity(isEnabled ? 1 : 0.72)
            .scaleEffect(pressed && isEnabled ? 0.96 : 1)
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
