// AppTab.swift
import Foundation

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
