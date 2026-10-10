// HomeCardID.swift
import Foundation

enum HomeCardID: String, CaseIterable, Identifiable, Codable, Hashable {
    case verseOfDay, resumeReading, search, today, streaks, timer, dailyFocus, bibleStats

    var id: String { rawValue }

    var title: String {
        switch self {
        case .verseOfDay: return "Verse of the Day"
        case .dailyFocus: return "Daily Focus"
        case .timer: return "Prayer Timer"
        case .today: return "Today"
        case .resumeReading: return "Continue Reading"
        case .search: return "Search Scripture"
        case .streaks: return "Reading Streak"
        case .bibleStats: return "App Activity"
        }
    }

    var systemImage: String {
        switch self {
        case .verseOfDay: return "sun.max"
        case .dailyFocus: return "target"
        case .timer: return "timer"
        case .today: return "checklist"
        case .resumeReading: return "bookmark.fill"
        case .search: return "magnifyingglass"
        case .streaks: return "flame.fill"
        case .bibleStats: return "chart.bar.fill"
        }
    }
}
