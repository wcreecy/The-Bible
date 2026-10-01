import Foundation
import Combine
import Observation

@MainActor
@Observable
final class HomeBibleStatsViewModel {
    struct Snapshot {
        let todaySeconds: Int
        let yesterdaySeconds: Int
        let thisWeekSeconds: Int
        let lastWeekSeconds: Int
        let totalSeconds: Int
        let lastReadBookChapter: String
        let lastReadRelativeTime: String
        let otSeconds: Int
        let ntSeconds: Int
        let visitedCount: Int
        let totalChapters: Int
        let completionPercent: Int
        let topBooks: [(book: String, seconds: Int)]
        let maxTopSeconds: Int
        let topBooksScopeLabel: String
        let lastSessionSeconds: Int

        static let empty = Snapshot(
            todaySeconds: 0,
            yesterdaySeconds: 0,
            thisWeekSeconds: 0,
            lastWeekSeconds: 0,
            totalSeconds: 0,
            lastReadBookChapter: "—",
            lastReadRelativeTime: "—",
            otSeconds: 0,
            ntSeconds: 0,
            visitedCount: 0,
            totalChapters: 0,
            completionPercent: 0,
            topBooks: [],
            maxTopSeconds: 1,
            topBooksScopeLabel: "All Time",
            lastSessionSeconds: 0
        )
    }

    private(set) var snapshot = Snapshot.empty

    var todaySeconds: Int { snapshot.todaySeconds }
    var thisWeekSeconds: Int { snapshot.thisWeekSeconds }
    var lastWeekSeconds: Int { snapshot.lastWeekSeconds }
    var totalSeconds: Int { snapshot.totalSeconds }
    var lastReadBookChapter: String { snapshot.lastReadBookChapter }
    var lastReadRelativeTime: String { snapshot.lastReadRelativeTime }
    var otSeconds: Int { snapshot.otSeconds }
    var ntSeconds: Int { snapshot.ntSeconds }
    var visitedCount: Int { snapshot.visitedCount }
    var totalChapters: Int { snapshot.totalChapters }
    var completionPercent: Int { snapshot.completionPercent }
    var topBooks: [(book: String, seconds: Int)] { snapshot.topBooks }
    var maxTopSeconds: Int { snapshot.maxTopSeconds }
    var topBooksScopeLabel: String { snapshot.topBooksScopeLabel }
    var lastSessionSeconds: Int { snapshot.lastSessionSeconds }

    private var externalUpdateCancellable: AnyCancellable?

    init() {
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
        let snapshot = store.homeStatisticsSnapshot()
        let dailyMap = snapshot.dailyTotals

        func key(for date: Date) -> String {
            BibleStatsStore.isoDateString(date, calendar: cal)
        }

        let todaySeconds = max(0, dailyMap[key(for: startOfToday), default: 0])

        // Yesterday (for delta)
        let yesterdaySeconds = cal.date(byAdding: .day, value: -1, to: startOfToday)
            .map { max(0, dailyMap[key(for: $0), default: 0]) } ?? 0

        // This week (rolling last 7 local days including today)
        var weekTotal = 0
        for i in 0..<7 {
            if let d = cal.date(byAdding: .day, value: -i, to: startOfToday) {
                weekTotal += max(0, dailyMap[key(for: d), default: 0])
            }
        }

        // Last week rolling window (the 7 days immediately before the current rolling week)
        var prevWeekTotal = 0
        for i in 7..<14 {
            if let d = cal.date(byAdding: .day, value: -i, to: startOfToday) {
                prevWeekTotal += max(0, dailyMap[key(for: d), default: 0])
            }
        }

        // All-time: align with Today/Week source — sum the synced daily totals map
        let totalSeconds = dailyMap.values.reduce(0) { $0 + max(0, $1) }

        // OT/NT split and top books from synced per-book totals
        let perBookAllTime = snapshot.perBookTotals
        let split = store.splitOTNT(totals: perBookAllTime)
        let sortedTop = perBookAllTime.sorted { lhs, rhs in
            if lhs.value == rhs.value { return lhs.key < rhs.key }
            return lhs.value > rhs.value
        }
        let topBooks = Array(sortedTop.prefix(5)).map { (book: $0.key, seconds: $0.value) }

        // Visited and completion (progress still from BibleStatsStore)
        let visited = snapshot.visitedChapters
        let completion = completionMetrics(visitedChapters: visited)

        // Last read
        let lastReadBookChapter = snapshot.lastRead.map { "\($0.bookName) \($0.chapterNumber)" } ?? "—"
        let lastReadRelativeTime = snapshot.lastRead.map { relativeTimeString(from: $0.date, to: now) } ?? "—"

        // Session analytics use the same validity rule as the Stats screen.
        let allSessions = ReadingSessionsStore.shared.allSessions().filter(ReadingSessionsStore.isValid)
        let lastSessionSeconds = allSessions.max(by: { $0.end < $1.end })
            .map(ReadingSessionsStore.duration(of:)) ?? 0

        self.snapshot = Snapshot(
            todaySeconds: todaySeconds,
            yesterdaySeconds: yesterdaySeconds,
            thisWeekSeconds: weekTotal,
            lastWeekSeconds: prevWeekTotal,
            totalSeconds: totalSeconds,
            lastReadBookChapter: lastReadBookChapter,
            lastReadRelativeTime: lastReadRelativeTime,
            otSeconds: split.ot,
            ntSeconds: split.nt,
            visitedCount: visited.count,
            totalChapters: completion.total,
            completionPercent: completion.percent,
            topBooks: topBooks,
            maxTopSeconds: max(1, topBooks.map(\.seconds).max() ?? 1),
            topBooksScopeLabel: "All Time",
            lastSessionSeconds: lastSessionSeconds
        )
    }

    private func completionMetrics(visitedChapters: Set<String>) -> (total: Int, percent: Int) {
        let books = BibleData.books
        let total = max(1, books.reduce(0) { $0 + $1.chapters.count })
        let percent = Int(round((Double(visitedChapters.count) / Double(total)) * 100.0))
        return (total, max(0, min(100, percent)))
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
        let delta = todaySeconds - snapshot.yesterdaySeconds
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
