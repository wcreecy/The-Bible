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

    // Label to indicate timeframe for Top Books (kept for compatibility)
    @Published var topBooksScopeLabel: String = "All Time"

    // Last session length (seconds) — computed from ReadingSessionsStore
    @Published var lastSessionSeconds: Int = 0

    private var externalUpdateCancellable: AnyCancellable?

    // Cache yesterday’s seconds for delta
    private var yesterdaySecondsLocal: Int = 0

    init() {
        refresh()
        // Refresh on incoming iCloud merges or local writes
        externalUpdateCancellable = NotificationCenter.default.publisher(for: .bibleStatsExternallyUpdated)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.refresh()
            }
    }

    func refresh(now: Date = Date()) {
        // Use BibleStatsStore’s synced daily totals (local-day yyyy-MM-dd keys) for Home metrics
        var cal = Calendar.autoupdatingCurrent
        cal.timeZone = TimeZone.autoupdatingCurrent
        let startOfToday = cal.startOfDay(for: now)

        let store = BibleStatsStore.shared
        let dailyMap: [String: Int] = store.loadDailyTotals()

        func key(for date: Date) -> String {
            BibleStatsStore.isoDateString(date, calendar: cal)
        }

        // Today
        todaySeconds = max(0, dailyMap[key(for: startOfToday), default: 0])

        // Yesterday (for delta)
        if let y = cal.date(byAdding: .day, value: -1, to: startOfToday) {
            yesterdaySecondsLocal = max(0, dailyMap[key(for: y), default: 0])
        } else {
            yesterdaySecondsLocal = 0
        }

        // This week (rolling last 7 local days including today)
        var weekTotal = 0
        for i in 0..<7 {
            if let d = cal.date(byAdding: .day, value: -i, to: startOfToday) {
                weekTotal += max(0, dailyMap[key(for: d), default: 0])
            }
        }
        thisWeekSeconds = weekTotal

        // Last week rolling window (the 7 days immediately before the current rolling week)
        var prevWeekTotal = 0
        for i in 7..<14 {
            if let d = cal.date(byAdding: .day, value: -i, to: startOfToday) {
                prevWeekTotal += max(0, dailyMap[key(for: d), default: 0])
            }
        }
        lastWeekSeconds = prevWeekTotal

        // All-time: align with Today/Week source — sum the synced daily totals map
        totalSeconds = dailyMap.values.reduce(0) { $0 + max(0, $1) }

        // OT/NT split and top books from synced per-book totals
        do {
            let perBookAllTime = store.loadTotals()
            let split = store.splitOTNT(totals: perBookAllTime)
            otSeconds = split.ot
            ntSeconds = split.nt

            let sortedTop = perBookAllTime.sorted { lhs, rhs in
                if lhs.value == rhs.value { return lhs.key < rhs.key }
                return lhs.value > rhs.value
            }
            topBooks = Array(sortedTop.prefix(5)).map { ($0.key, $0.value) }
            maxTopSeconds = max(1, topBooks.map { $0.seconds }.max() ?? 1)
            topBooksScopeLabel = "All Time"
        }

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

        // Last session length (seconds) — this is still sessions-based and can be device-local
        let allSessions = ReadingSessionsStore.shared.sessions(inLastDays: 1825, now: now, calendar: cal)
        if let last = allSessions.max(by: { $0.end < $1.end }) {
            lastSessionSeconds = Int(max(0, last.end.timeIntervalSince(last.start)))
        } else {
            lastSessionSeconds = 0
        }
    }

    private func computeCompletionMetrics(visitedChapters: Set<String>) {
        let books = BibleData.books
        let total = books.reduce(0) { $0 + $1.chapters.count }
        totalChapters = max(1, total)
        let pct = Int(round((Double(visitedChapters.count) / Double(totalChapters)) * 100.0))
        completionPercent = max(0, min(100, pct))
    }

    // Compact formatter for Home Bible Stats card:
    // - H:MM:SS if hours > 0
    // - MM:SS if minutes > 0 and hours == 0
    // - :SS if only seconds
    func formatted(_ seconds: Int) -> String {
        let s = max(0, seconds)
        let h = s / 3600
        let m = (s % 3600) / 60
        let sec = s % 60

        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, sec)
        } else if m > 0 {
            return String(format: "%02d:%02d", m, sec)
        } else {
            return String(format: ":%02d", sec)
        }
    }

    var weekDeltaOnlyValue: String {
        let delta = thisWeekSeconds - lastWeekSeconds
        if delta == 0 { return "—" }
        let sign = delta > 0 ? "+" : "−"
        return "\(sign)\(formatted(abs(delta)))"
    }

    // Today vs Yesterday delta (totals-based)
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
}
