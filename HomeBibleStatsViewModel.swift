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

    private var cancellable: AnyCancellable?
    private var externalUpdateCancellable: AnyCancellable?

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
        let totals = store.loadTotals()
        totalSeconds = totals.values.reduce(0, +)

        // Match Stats tab: use ReadingSessionsStore (GMT day boundaries) for Today/This Week/Last Week
        var gmtCal = Calendar.current
        gmtCal.timeZone = .gmt

        // Today: sessions whose end falls on today's GMT date
        do {
            let sessions7 = ReadingSessionsStore.shared.sessions(inLastDays: 7, now: now, calendar: gmtCal)
            let todayKey = BibleStatsStore.isoDateString(now, calendar: gmtCal)
            todaySeconds = sessions7.reduce(0) { acc, s in
                let key = BibleStatsStore.isoDateString(s.end, calendar: gmtCal)
                let dur = Int(max(0, s.end.timeIntervalSince(s.start)))
                return acc + (key == todayKey ? dur : 0)
            }
        }

        // This Week: last 7 days total (GMT)
        do {
            let sessions7 = ReadingSessionsStore.shared.sessions(inLastDays: 7, now: now, calendar: gmtCal)
            thisWeekSeconds = sessions7.reduce(0) { $0 + Int(max(0, $1.end.timeIntervalSince($1.start))) }
        }

        // Last Week: the 7-day window ending 7 days ago, based on session end times (GMT)
        do {
            let startOfToday = gmtCal.startOfDay(for: now)
            guard
                let lastWeekEnd = gmtCal.date(byAdding: .day, value: -7, to: startOfToday),
                let lastWeekStart = gmtCal.date(byAdding: .day, value: -13, to: startOfToday)
            else {
                lastWeekSeconds = 0
                return
            }
            // Fetch enough sessions to cover last 14 days
            let sessions14 = ReadingSessionsStore.shared.sessions(inLastDays: 14, now: now, calendar: gmtCal)
            lastWeekSeconds = sessions14.reduce(0) { acc, s in
                if s.end >= lastWeekStart && s.end < lastWeekEnd {
                    return acc + Int(max(0, s.end.timeIntervalSince(s.start)))
                } else {
                    return acc
                }
            }
        }

        let split = store.splitOTNT(totals: totals)
        otSeconds = split.ot
        ntSeconds = split.nt

        // Visited and completion
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

        // Top books (compute 5, UI will show 3/5)
        let all = totals.sorted { lhs, rhs in
            if lhs.value == rhs.value { return lhs.key < rhs.key }
            return lhs.value > rhs.value
        }
        topBooks = all.prefix(5).map { ($0.key, $0.value) }
        maxTopSeconds = max(1, topBooks.map { $0.seconds }.max() ?? 1)
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

    // New: Today vs Yesterday delta (e.g., "+3:15" or "−05:20", or "—" when equal)
    var todayDeltaOnlyValue: String {
        // Yesterday = total of last 2 days minus today; keep legacy method for delta only
        let store = BibleStatsStore.shared
        let last2 = store.totalForLast(days: 2)
        let yesterday = max(0, last2 - todaySeconds)
        let delta = todaySeconds - yesterday
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
