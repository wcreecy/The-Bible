import AppIntents
import Foundation

enum WidgetBackgroundOption: String, AppEnum {
    case useSettings
    case black
    case midnight
    case forest
    case burgundy
    case indigo
    case sunset
    case blackToGray
    case blueToPurple

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        "Widget Background"
    }

    static var caseDisplayRepresentations: [WidgetBackgroundOption: DisplayRepresentation] {
        [
            .useSettings: "Match App Setting",
            .black: "Black",
            .midnight: "Midnight",
            .forest: "Forest",
            .burgundy: "Burgundy",
            .indigo: "Indigo",
            .sunset: "Sunset",
            .blackToGray: "Graphite",
            .blueToPurple: "Aurora"
        ]
    }

    func resolvedRawValue(settingsKey: String) -> String {
        guard self == .useSettings else { return rawValue }

        let savedValue = UserDefaults(suiteName: "group.bible.app")?
            .string(forKey: settingsKey)
        return savedValue ?? WidgetBackgroundOption.black.rawValue
    }
}

struct WidgetAppearanceConfigurationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Widget Appearance"
    static var description = IntentDescription(
        "Choose a background for this widget, or use the choice from the app’s Settings."
    )

    @Parameter(title: "Background", default: .useSettings)
    var background: WidgetBackgroundOption
}
