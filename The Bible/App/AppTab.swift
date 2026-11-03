// AppTab.swift
import Foundation
import SwiftUI

enum AppTab: Int, CaseIterable {
    case home = 0
    case bible
    case notes
    case games
    case more

    var name: String {
        switch self {
        case .home: return "home"
        case .bible: return "bible"
        case .notes: return "notes"
        case .games: return "games"
        case .more: return "more"
        }
    }

    static func from(name: String) -> AppTab? {
        switch name.lowercased() {
        case "home": return .home
        case "bible", "search": return .bible
        case "notes": return .notes
        case "favorites": return .more
        case "games": return .games
        case "more", "stats", "settings": return .more
        default: return nil
        }
    }
}

enum LaunchTabPreference: String, CaseIterable, Identifiable {
    case home
    case bible
    case notes
    case games

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .home: "Home"
        case .bible: "Bible"
        case .notes: "Notes"
        case .games: "Games"
        }
    }

    var appTab: AppTab {
        switch self {
        case .home: .home
        case .bible: .bible
        case .notes: .notes
        case .games: .games
        }
    }

    static let defaultsKey = "launchTabPreference"

    static func currentDeviceSelection(defaults: UserDefaults = .standard) -> AppTab {
        let rawValue = defaults.string(forKey: defaultsKey) ?? home.rawValue
        return LaunchTabPreference(rawValue: rawValue)?.appTab ?? .home
    }
}
