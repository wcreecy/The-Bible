import SwiftUI
import WidgetKit

/// The backgrounds a person can choose for the Home Screen widgets. The raw values match each
/// widget's Background setting (`VerseWidgetBackgroundOption`, `LastReadWidgetBackgroundOption`,
/// and `PinnedVerseWidgetBackgroundOption`), which is saved with the widget, so they must not change.
enum WidgetBackgroundStyle: String {
    case black
    case midnight
    case forest
    case burgundy
    case indigo
    case sunset
    case blackToGray
    case blueToPurple
    case riverstone
    case oliveGold
    case amethyst
    case parchment

    /// The main text color. In tinted and clear Home Screen modes the system removes the
    /// background, so text stays white there; Parchment's dark brown is only for its light fill.
    func primaryTextColor(in renderingMode: WidgetRenderingMode) -> Color {
        guard renderingMode == .fullColor, self == .parchment else { return .white }
        return Color(red: 0.20, green: 0.15, blue: 0.08)
    }
}

/// Draws a `WidgetBackgroundStyle`.
struct WidgetBackgroundView: View {
    let style: WidgetBackgroundStyle

    var body: some View {
        switch style {
        case .black:
            Color.black
        case .midnight:
            gradient(Color(red: 0.03, green: 0.08, blue: 0.18), Color(red: 0.08, green: 0.22, blue: 0.38))
        case .forest:
            gradient(Color(red: 0.03, green: 0.16, blue: 0.12), Color(red: 0.10, green: 0.34, blue: 0.23))
        case .burgundy:
            gradient(Color(red: 0.22, green: 0.03, blue: 0.08), Color(red: 0.48, green: 0.08, blue: 0.16))
        case .indigo:
            gradient(Color(red: 0.10, green: 0.07, blue: 0.28), Color(red: 0.28, green: 0.20, blue: 0.58))
        case .sunset:
            gradient(Color(red: 0.33, green: 0.07, blue: 0.18), Color(red: 0.72, green: 0.28, blue: 0.16))
        case .blackToGray:
            gradient(.black, .gray)
        case .blueToPurple:
            gradient(.blue, .purple)
        case .riverstone:
            gradient(Color(red: 0.02, green: 0.23, blue: 0.25), Color(red: 0.12, green: 0.31, blue: 0.37))
        case .oliveGold:
            gradient(Color(red: 0.20, green: 0.27, blue: 0.16), Color(red: 0.54, green: 0.42, blue: 0.17))
        case .amethyst:
            gradient(Color(red: 0.21, green: 0.07, blue: 0.31), Color(red: 0.44, green: 0.27, blue: 0.65))
        case .parchment:
            Color(red: 0.91, green: 0.85, blue: 0.70)
        }
    }

    private func gradient(_ start: Color, _ end: Color) -> LinearGradient {
        LinearGradient(colors: [start, end], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}
