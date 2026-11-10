import SwiftUI

/// Gray for word study's secondary text. The system's secondary gray measures about 3.3:1 on
/// the tiles in light mode, under the 4.5:1 that caption-sized text needs; this is about 5.5:1
/// in light and dark mode, on plain and selected tiles.
struct WordStudySecondaryStyle: ShapeStyle {
    func resolve(in environment: EnvironmentValues) -> Color.Resolved {
        var color = Color.primary.resolve(in: environment)
        color.opacity = environment.colorSchemeContrast == .increased ? 0.8 : 0.62
        return color
    }
}

/// Strong's numbers: the accent, darkened in light mode and lightened in dark mode. The plain
/// accent is under 4:1 behind the small monospaced numbers; this is at least 4.7:1, even on a
/// selected tile or inside the number's tinted capsule.
struct WordStudyNumberStyle: ShapeStyle {
    func resolve(in environment: EnvironmentValues) -> Color.Resolved {
        let toward: Color = environment.colorScheme == .dark ? .white : .black
        let amount = environment.colorSchemeContrast == .increased ? 0.45 : 0.3
        return Color.accentColor.mix(with: toward, by: amount, in: .device).resolve(in: environment)
    }
}

extension ShapeStyle where Self == WordStudySecondaryStyle {
    static var wordStudySecondary: WordStudySecondaryStyle { WordStudySecondaryStyle() }
}

extension ShapeStyle where Self == WordStudyNumberStyle {
    static var wordStudyNumber: WordStudyNumberStyle { WordStudyNumberStyle() }
}
