// HomeCardID.swift
import Foundation

enum HomeCardID: String, CaseIterable, Identifiable, Codable, Hashable {
    case verseOfDay, dailyFocus, timer, resumeReading, games, streaks, bibleStats

    var id: String { rawValue }

    var title: String {
        switch self {
        case .verseOfDay: return "Verse of the Day"
        case .dailyFocus: return "Daily Focus"
        case .timer: return "Prayer Timer / Stopwatch"
        case .resumeReading: return "Continue Reading"
        case .games: return "Games"
        case .streaks: return "Daily Bible Streak"
        case .bibleStats: return "Bible Stats"
        }
    }

    var systemImage: String {
        switch self {
        case .verseOfDay: return "sun.max"
        case .dailyFocus: return "target"
        case .timer: return "timer"
        case .resumeReading: return "bookmark.fill"
        case .games: return "gamecontroller"
        case .streaks: return "flame.fill"
        case .bibleStats: return "chart.bar.fill"
        }
    }
}
