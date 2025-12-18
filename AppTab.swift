// AppTab.swift
import Foundation

enum AppTab: Int, CaseIterable {
    case home = 0
    case bible
    case journal
    case games
    case stats
    case favorites
    case search
    case settings

    var name: String {
        switch self {
        case .home: return "home"
        case .bible: return "bible"
        case .journal: return "journal"
        case .games: return "games"
        case .stats: return "stats"
        case .favorites: return "favorites"
        case .search: return "search"
        case .settings: return "settings"
        }
    }

    static func from(name: String) -> AppTab? {
        switch name.lowercased() {
        case "home": return .home
        case "bible": return .bible
        case "journal": return .journal
        case "games": return .games
        case "stats": return .stats
        case "favorites": return .favorites
        case "search": return .search
        case "settings": return .settings
        default: return nil
        }
    }
}
