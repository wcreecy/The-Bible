//
//  AppIntent.swift
//  The Bible Widgets
//
//  Created by William Creecy on 11/7/25.
//

import WidgetKit
import AppIntents

enum WidgetColorOption: String, AppEnum, CaseIterable, Identifiable, Codable {
    case white
    case black
    case blue
    case green
    case red
    case orange
    case yellow
    case gray
    
    var id: String { rawValue }
    
    var displayName: LocalizedStringResource {
        switch self {
        case .white: return "White"
        case .black: return "Black"
        case .blue: return "Blue"
        case .green: return "Green"
        case .red: return "Red"
        case .orange: return "Orange"
        case .yellow: return "Yellow"
        case .gray: return "Gray"
        }
    }
}

extension WidgetColorOption: TypeDisplayRepresentable, CaseDisplayRepresentable {
    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        .init(name: "Color Option")
    }
    static var caseDisplayRepresentations: [WidgetColorOption : DisplayRepresentation] {
        return [
            .white: DisplayRepresentation(title: "White"),
            .black: DisplayRepresentation(title: "Black"),
            .blue: DisplayRepresentation(title: "Blue"),
            .green: DisplayRepresentation(title: "Green"),
            .red: DisplayRepresentation(title: "Red"),
            .orange: DisplayRepresentation(title: "Orange"),
            .yellow: DisplayRepresentation(title: "Yellow"),
            .gray: DisplayRepresentation(title: "Gray")
        ]
    }
    // var caseDisplayRepresentation: DisplayRepresentation? {
    //     .init(title: self.displayName)
    // }
}

struct ConfigurationAppIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "Configuration" }
    static var description: IntentDescription { "This is an example widget." }

    // An example configurable parameter.
    @Parameter(title: "Favorite Emoji", default: "😃")
    var favoriteEmoji: String

    @Parameter(title: "Background Color", default: .white)
    var backgroundColor: WidgetColorOption

    @Parameter(title: "Font Color", default: .black)
    var fontColor: WidgetColorOption
}
