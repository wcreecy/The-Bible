import SwiftUI

/// A modern pill-shaped button style used across the app for secondary actions.
/// Filled capsule with subtle gradient, stroke and shadow.
public struct ModernPillButtonStyle: ButtonStyle {
    public var tint: Color = .accentColor
    @Environment(\.isEnabled) private var isEnabled

    public init(tint: Color = .accentColor) { self.tint = tint }

    public func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed

        // Always use LinearGradient to avoid ternary type mismatch
        let fillGradient: LinearGradient = {
            if isEnabled {
                return LinearGradient(
                    colors: [
                        tint.opacity(pressed ? 0.92 : 1.0),
                        tint.opacity(pressed ? 0.82 : 0.92)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            } else {
                let disabled = Color(.secondarySystemFill)
                return LinearGradient(
                    colors: [disabled, disabled],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }()

        return configuration.label
            .font(.footnote.weight(.semibold))
            .foregroundStyle(isEnabled ? .white : .secondary)
            .padding(.vertical, 9)
            .padding(.horizontal, 14)
            .background(
                Capsule(style: .continuous)
                    .fill(fillGradient)
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(
                        (isEnabled ? tint : .gray).opacity(pressed ? 0.55 : 0.35),
                        lineWidth: pressed ? 2 : 1
                    )
            )
            .shadow(color: .black.opacity(pressed ? 0.05 : 0.10), radius: pressed ? 1 : 3, x: 0, y: pressed ? 0 : 2)
            .contentShape(Capsule(style: .continuous))
            .scaleEffect(pressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.22, dampingFraction: 0.85), value: configuration.isPressed)
    }
}

/// A prominent filled button style used in games and primary calls to action.
/// Bold rounded rectangle with gradient fill and strong affordance.
public struct GameProminentButtonStyle: ButtonStyle {
    public var tint: Color = .accentColor
    @Environment(\.isEnabled) private var isEnabled

    public init(tint: Color = .accentColor) { self.tint = tint }

    public func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed

        let fillGradient: LinearGradient = {
            if isEnabled {
                return LinearGradient(
                    colors: [
                        tint.opacity(pressed ? 0.95 : 1.0),
                        tint.opacity(pressed ? 0.85 : 0.92)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            } else {
                let disabled = Color(.tertiarySystemFill)
                return LinearGradient(
                    colors: [disabled, disabled],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }()

        return configuration.label
            .font(.headline.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.vertical, 12)
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(fillGradient)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(tint.opacity(pressed ? 0.6 : 0.35), lineWidth: pressed ? 2 : 1)
            )
            .shadow(color: .black.opacity(pressed ? 0.06 : 0.14), radius: pressed ? 2 : 6, x: 0, y: pressed ? 1 : 3)
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .scaleEffect(pressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.8), value: configuration.isPressed)
    }
}

/// A prominent rounded rectangle style for primary actions outside the games.
/// Matches the prominent aesthetic used elsewhere in the app.
public struct ModernProminentButtonStyle: ButtonStyle {
    public var tint: Color = .accentColor
    @Environment(\.isEnabled) private var isEnabled

    public init(tint: Color = .accentColor) { self.tint = tint }

    public func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed

        let fillGradient: LinearGradient = {
            if isEnabled {
                return LinearGradient(
                    colors: [
                        tint.opacity(pressed ? 0.96 : 1.0),
                        tint.opacity(pressed ? 0.86 : 0.93)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            } else {
                let disabled = Color(.tertiarySystemFill)
                return LinearGradient(
                    colors: [disabled, disabled],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }()

        return configuration.label
            .font(.headline.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.vertical, 12)
            .padding(.horizontal, 22)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(fillGradient)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(tint.opacity(pressed ? 0.6 : 0.35), lineWidth: pressed ? 2 : 1)
            )
            .shadow(color: .black.opacity(pressed ? 0.05 : 0.12), radius: pressed ? 2 : 5, x: 0, y: pressed ? 0 : 2)
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .scaleEffect(pressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
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
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        (isEnabled ? tint : .gray)
                            .opacity(pressed ? 0.22 : 0.15)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(tint.opacity(pressed ? 0.55 : 0.35), lineWidth: pressed ? 2 : 1)
            )
            .shadow(color: .black.opacity(0.05), radius: pressed ? 1 : 2, x: 0, y: pressed ? 0 : 1)
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
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
