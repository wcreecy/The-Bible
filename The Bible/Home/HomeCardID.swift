// HomeCardID.swift
import Foundation

enum HomeCardID: String, CaseIterable, Identifiable, Codable, Hashable {
    case verseOfDay, resumeReading, readingPlan, study, today, savedVerses, streaks, timer, dailyFocus, setup

    var id: String { rawValue }

    var title: String {
        switch self {
        case .verseOfDay: return "Verse of the Day"
        case .dailyFocus: return "Today's Intention"
        case .timer: return "Prayer & Study Timer"
        case .today: return "Today"
        case .savedVerses: return "Saved Verses"
        case .resumeReading: return "Continue Reading"
        case .readingPlan: return "Reading Plan"
        case .study: return "Study"
        case .streaks: return "Your Progress"
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
        case .readingPlan: return "calendar.badge.checkmark"
        case .study: return "text.book.closed"
        case .streaks: return "flame.fill"
        case .setup: return "list.bullet.clipboard"
        }
    }
}
