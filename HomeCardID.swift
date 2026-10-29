// HomeCardID.swift
import Foundation

enum HomeCardID: String, CaseIterable, Identifiable, Codable, Hashable {
    case verseOfDay, resumeReading, study, search, today, savedVerses, streaks, timer, dailyFocus, bibleStats, setup

    var id: String { rawValue }

    var title: String {
        switch self {
        case .verseOfDay: return "Verse of the Day"
        case .dailyFocus: return "Daily Focus"
        case .timer: return "Prayer & Study Timer"
        case .today: return "Today"
        case .savedVerses: return "Saved Verses"
        case .resumeReading: return "Continue Reading"
        case .study: return "Study"
        case .search: return "Search Scripture"
        case .streaks: return "Reading Streak"
        case .bibleStats: return "Your Stats"
        case .setup: return "Welcome"
        }
    }

    var systemImage: String {
        switch self {
        case .verseOfDay: return "sun.max"
        case .dailyFocus: return "target"
        case .timer: return "timer"
        case .today: return "checklist"
        case .savedVerses: return "heart.text.clipboard"
        case .resumeReading: return "bookmark.fill"
        case .study: return "text.book.closed"
        case .search: return "magnifyingglass"
        case .streaks: return "flame.fill"
        case .bibleStats: return "chart.bar.fill"
        case .setup: return "list.bullet.clipboard"
        }
    }
}
