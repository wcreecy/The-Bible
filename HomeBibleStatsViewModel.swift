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
        let cal = Calendar.autoupdatingCurrent

        // Sessions-based daily buckets to match Stats tab charts
        let todaySeries = StatsSeriesBuilder.dailySeries(lastNDays: 1, now: now, calendar: cal)
        todaySeconds = todaySeries.last?.seconds ?? 0

        let last2 = StatsSeriesBuilder.dailySeries(lastNDays: 2, now: now, calendar: cal)
        // last2 = [yesterday, today] in ascending order
        yesterdaySecondsLocal = last2.first?.seconds ?? 0

        let weekSeries = StatsSeriesBuilder.dailySeries(lastNDays: 7, now: now, calendar: cal)
        thisWeekSeconds = weekSeries.reduce(0) { $0 + $1.seconds }

        let last14 = StatsSeriesBuilder.dailySeries(lastNDays: 14, now: now, calendar: cal)
        // last14 is ascending; first 7 entries are the previous rolling week
        lastWeekSeconds = last14.prefix(7).reduce(0) { $0 + $1.seconds }

        // All-time (sessions within retention window ~5 years)
        let allSessions = ReadingSessionsStore.shared.sessions(inLastDays: 1825, now: now, calendar: cal)
        totalSeconds = allSessions.reduce(0) { $0 + Int(max(0, $1.end.timeIntervalSince($1.start))) }

        // Optional: compute OT/NT split and top books from sessions (kept for future use)
        do {
            let perBookAllTime = StatsSeriesBuilder.groupSessionsByBook(allSessions)
            let split = BibleStatsStore.shared.splitOTNT(totals: perBookAllTime)
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
        let store = BibleStatsStore.shared
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

        // Last session length (seconds)
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

    func formatted(_ seconds: Int) -> String {
        BibleStatsStore.shared.format(seconds)
    }

    var weekDeltaOnlyValue: String {
        let delta = thisWeekSeconds - lastWeekSeconds
        if delta == 0 { return "—" }
        let sign = delta > 0 ? "+" : "−"
        return "\(sign)\(formatted(abs(delta)))"
    }

    // Today vs Yesterday delta (sessions-based)
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
