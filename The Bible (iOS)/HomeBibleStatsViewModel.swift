import Foundation
import Combine
import SwiftUI

@MainActor
final class HomeBibleStatsViewModel: ObservableObject {
    @Published var todaySeconds: Int = 0
    @Published var thisWeekSeconds: Int = 0
    @Published var lastWeekSeconds: Int = 0
    @Published var totalSeconds: Int = 0

    @Published var lastReadBookChapter: String = "—"
    @Published var lastReadRelativeTime: String = "—"

    @Published var otSeconds: Int = 0
    @Published var ntSeconds: Int = 0

    @Published var visitedCount: Int = 0
    @Published var totalChapters: Int = 0
    @Published var completionPercent: Int = 0

    @Published var topBooks: [(book: String, seconds: Int)] = []
    @Published var maxTopSeconds: Int = 1

    // New: label to indicate timeframe for Top Books (matches Stats tab behavior)
    @Published var topBooksScopeLabel: String = "All Time"

    private var cancellable: AnyCancellable?
    private var externalUpdateCancellable: AnyCancellable?

    // Cache yesterday’s seconds computed with the same local-day sessions logic as StatsView
    private var yesterdaySecondsLocal: Int = 0

    init() {
        refresh()
        cancellable = ReadingTimeTracker.shared.$lastTotalsVersion
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.refresh()
            }

        // NEW: refresh on incoming iCloud merges
        externalUpdateCancellable = NotificationCenter.default.publisher(for: .bibleStatsExternallyUpdated)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                // Stats caches are reset by the coordinator; re-read and refresh UI
                self?.refresh()
            }
    }

    func refresh(now: Date = Date()) {
        let store = BibleStatsStore.shared

        // Use local calendar semantics (to match StatsView exactly)
        let cal = Calendar.current

        // Today: sessions whose end falls on today's local date
        do {
            let sessions7 = ReadingSessionsStore.shared.sessions(inLastDays: 7, now: now, calendar: cal)
            let todayKey = BibleStatsStore.isoDateString(now, calendar: cal)
            todaySeconds = sessions7.reduce(0) { acc, s in
                let key = BibleStatsStore.isoDateString(s.end, calendar: cal)
                let dur = Int(max(0, s.end.timeIntervalSince(s.start)))
                return acc + (key == todayKey ? dur : 0)
            }
        }

        // Compute yesterday (local) using the same windowed approach as StatsView
        do {
            let startOfToday = cal.startOfDay(for: now)
            if let startOfYesterday = cal.date(byAdding: .day, value: -1, to: startOfToday),
               let endOfYesterday = cal.date(byAdding: .second, value: -1, to: startOfToday) {
                yesterdaySecondsLocal = totalSecondsForDay(from: startOfYesterday, to: endOfYesterday, calendar: cal, now: now)
            } else {
                yesterdaySecondsLocal = 0
            }
        }

        // This Week: last 7 days total (local)
        do {
            let sessions7 = ReadingSessionsStore.shared.sessions(inLastDays: 7, now: now, calendar: cal)
            thisWeekSeconds = sessions7.reduce(0) { $0 + Int(max(0, $1.end.timeIntervalSince($1.start))) }
        }

        // Last Week: window ending 7 days ago (local)
        do {
            let startOfToday = cal.startOfDay(for: now)
            guard
                let lastWeekEnd = cal.date(byAdding: .day, value: -7, to: startOfToday),
                let lastWeekStart = cal.date(byAdding: .day, value: -13, to: startOfToday)
            else {
                lastWeekSeconds = 0
                return
            }
            let sessions14 = ReadingSessionsStore.shared.sessions(inLastDays: 14, now: now, calendar: cal)
            lastWeekSeconds = sessions14.reduce(0) { acc, s in
                if s.end >= lastWeekStart && s.end < lastWeekEnd {
                    return acc + Int(max(0, s.end.timeIntervalSince(s.start)))
                } else {
                    return acc
                }
            }
        }

        // All Time total (sessions-only, 5-year retention) — keep using sessions
        do {
            let allSessions = ReadingSessionsStore.shared.sessions(inLastDays: 1825, now: now, calendar: cal)
            totalSeconds = allSessions.reduce(0) { $0 + Int(max(0, $1.end.timeIntervalSince($1.start))) }
        }

        // OT/NT split from sessions-only for the same 5-year window
        let sessionDerivedAllTime: [String: Int] = groupSessionsByBook(
            ReadingSessionsStore.shared.sessions(inLastDays: 1825, now: now, calendar: cal)
        )
        let split = store.splitOTNT(totals: sessionDerivedAllTime)
        otSeconds = split.ot
        ntSeconds = split.nt

        // Visited and completion (progress still from BibleStatsStore)
        let visited = store.loadVisitedChapters()
        visitedCount = visited.count
        computeCompletionMetrics(visitedChapters: visited)

        // Last read
        if let last = store.loadLastRead() {
            lastReadBookChapter = "\(last.bookName) \(last.chapterNumber)"
            lastReadRelativeTime = relativeTimeString(from: last.date, to: now)
        } else {
            lastReadBookChapter = "—"
            lastReadRelativeTime = "—"
        }

        // Top books — sessions-only within the 5-year window
        let all = sessionDerivedAllTime.sorted { lhs, rhs in
            if lhs.value == rhs.value { return lhs.key < rhs.key }
            return lhs.value > rhs.value
        }
        topBooks = all.prefix(5).map { ($0.key, $0.value) }
        maxTopSeconds = max(1, topBooks.map { $0.seconds }.max() ?? 1)
        topBooksScopeLabel = "All Time"
    }

    private func computeCompletionMetrics(visitedChapters: Set<String>) {
        let books = BibleData.books
        let total = books.reduce(0) { $0 + $1.chapters.count }
        totalChapters = max(1, total)
        let pct = Int(round((Double(visitedCount) / Double(totalChapters)) * 100.0))
        completionPercent = max(0, min(100, pct))
    }

    func formatted(_ seconds: Int) -> String {
        BibleStatsStore.shared.format(seconds)
    }

    var weekDeltaOnlyValue: String {
        let delta = thisWeekSeconds - lastWeekSeconds
        if delta == 0 { return "—" }
        let sign = delta > 0 ? "+" : "−"
        return "\(sign)\(formatted(abs(delta)))"
    }

    // Today vs Yesterday delta using the same sessions-only, local-day windowing as StatsView
    var todayDeltaOnlyValue: String {
        let delta = todaySeconds - yesterdaySecondsLocal
        if delta == 0 { return "—" }
        let sign = delta > 0 ? "+" : "−"
        return "\(sign)\(formatted(abs(delta)))"
    }

    private func relativeTimeString(from date: Date, to now: Date = Date()) -> String {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .short
        return f.localizedString(for: date, relativeTo: now)
    }

    // Group sessions by book and sum durations (sessions-only)
    private func groupSessionsByBook(_ sessions: [ReadingSessionsStore.Session]) -> [String: Int] {
        var map: [String: Int] = [:]
        for s in sessions {
            let dur = Int(max(0, s.end.timeIntervalSince(s.start)))
            guard dur > 0 else { continue }
            map[s.book, default: 0] += dur
        }
        return map
    }

    // Sum all sessions whose end falls within [start, end] inclusive window (local day), matching StatsView
    private func totalSecondsForDay(from start: Date, to end: Date, calendar: Calendar, now: Date) -> Int {
        // Fetch enough sessions to cover the two-day span (yesterday + today) to be safe
        let sessions = ReadingSessionsStore.shared.sessions(inLastDays: 2, now: end, calendar: calendar)
        return sessions.reduce(0) { acc, s in
            if s.end >= start && s.end <= end {
                return acc + Int(max(0, s.end.timeIntervalSince(s.start)))
            } else {
                return acc
            }
        }
    }
}
