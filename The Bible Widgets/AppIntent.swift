import AppIntents
import Foundation

enum WidgetBackgroundOption: String, AppEnum {
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

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        "Widget Background"
    }

    static var caseDisplayRepresentations: [WidgetBackgroundOption: DisplayRepresentation] {
        [
            .black: "Black",
            .midnight: "Midnight",
            .forest: "Forest",
            .burgundy: "Burgundy",
            .indigo: "Indigo",
            .sunset: "Sunset",
            .blackToGray: "Graphite",
            .blueToPurple: "Aurora",
            .riverstone: "Riverstone",
            .oliveGold: "Olive & Gold",
            .amethyst: "Amethyst",
            .parchment: "Parchment"
        ]
    }


}

struct WidgetAppearanceConfigurationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Widget Appearance"
    static var description = IntentDescription(
        "Choose a background for this widget."
    )

    @Parameter(title: "Background", default: .black)
    var background: WidgetBackgroundOption
}
