// HomeCardID.swift
import Foundation

enum HomeCardID: String, CaseIterable, Identifiable, Codable, Hashable {
    case verseOfDay, resumeReading, streaks, timer, dailyFocus, bibleStats

    var id: String { rawValue }

    var title: String {
        switch self {
        case .verseOfDay: return "Verse of the Day"
        case .dailyFocus: return "Daily Focus"
        case .timer: return "Prayer Timer"
        case .resumeReading: return "Continue Reading"
        case .streaks: return "Daily Bible Streak"
        case .bibleStats: return "App Activity"
        }
    }

    var systemImage: String {
        switch self {
        case .verseOfDay: return "sun.max"
        case .dailyFocus: return "target"
        case .timer: return "timer"
        case .resumeReading: return "bookmark.fill"
        case .streaks: return "flame.fill"
        case .bibleStats: return "chart.bar.fill"
        }
    }
}
